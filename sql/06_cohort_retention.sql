-- RUN ORDER 6: run after file 04. Creates analytics.cohort_retention, then answers Exec Question 1.

-- 06_cohort_retention.sql
-- Business question: Are we keeping the customers we win?

-- =================================================================
-- PART A: Build the cohort retention table
-- =================================================================
CREATE OR REPLACE TABLE `retail-portfolio-513601.analytics.cohort_retention` AS

WITH customer_months AS (
  -- Each month in which each customer placed at least one order
  SELECT DISTINCT
    customer_id,
    DATE_TRUNC(invoice_date, MONTH)   AS activity_month
  FROM `retail-portfolio-513601.analytics.fct_orders`
  WHERE customer_id IS NOT NULL
),

cohort_sizes AS (
  -- How many customers started in each month
  SELECT
    cohort_month,
    COUNT(*)   AS cohort_size
  FROM `retail-portfolio-513601.analytics.dim_customers`
  GROUP BY cohort_month
),

grid AS (
  -- Every cohort x every month after it (up to Dec 2011), so months with zero buyers still appear
  SELECT
    s.cohort_month,
    s.cohort_size,
    n                                            AS months_since_first,
    DATE_ADD(s.cohort_month, INTERVAL n MONTH)   AS activity_month
  FROM cohort_sizes AS s
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 24)) AS n
  WHERE DATE_ADD(s.cohort_month, INTERVAL n MONTH) <= DATE '2011-12-01'
),

activity AS (
  -- How many customers from each cohort bought in each month
  SELECT
    d.cohort_month,
    m.activity_month,
    COUNT(DISTINCT m.customer_id)   AS active_customers
  FROM customer_months AS m
  JOIN `retail-portfolio-513601.analytics.dim_customers` AS d
    ON m.customer_id = d.customer_id
  GROUP BY d.cohort_month, m.activity_month
)

SELECT
  g.cohort_month,
  g.months_since_first,
  g.activity_month,
  g.cohort_size,
  COALESCE(a.active_customers, 0)                               AS active_customers,
  SAFE_DIVIDE(COALESCE(a.active_customers, 0), g.cohort_size)   AS retention_rate,
  g.cohort_month = DATE '2009-12-01'                            AS is_pre_existing_customers,  -- data starts here
  g.activity_month = DATE '2011-12-01'                          AS is_partial_month            -- only 9 days
FROM grid AS g
LEFT JOIN activity AS a
  ON  g.cohort_month   = a.cohort_month
  AND g.activity_month = a.activity_month;


-- =================================================================
-- PART B: Answer the business question (run each query separately)
-- =================================================================

-- Q7a: Average retention curve, months 1-12 (new customers only, full months only)
SELECT
  months_since_first,
  ROUND(100 * SUM(active_customers) / SUM(cohort_size), 1)   AS retention_pct,
  COUNT(*)                                                   AS cohorts_included
FROM `retail-portfolio-513601.analytics.cohort_retention`
WHERE NOT is_pre_existing_customers
  AND NOT is_partial_month
  AND months_since_first BETWEEN 1 AND 12
GROUP BY months_since_first
ORDER BY months_since_first;


-- Q7b: Is retention getting better or worse?
-- Compares the same season (customers who joined Jan-May) in 2010 vs 2011, for a fair comparison.
SELECT
  EXTRACT(YEAR FROM cohort_month)                            AS cohort_year,
  months_since_first,
  ROUND(100 * SUM(active_customers) / SUM(cohort_size), 1)   AS retention_pct,
  SUM(cohort_size)                                           AS customers_in_cohorts
FROM `retail-portfolio-513601.analytics.cohort_retention`
WHERE NOT is_pre_existing_customers
  AND NOT is_partial_month
  AND EXTRACT(MONTH FROM cohort_month) BETWEEN 1 AND 5
  AND months_since_first IN (1, 3, 6)
GROUP BY cohort_year, months_since_first
ORDER BY months_since_first, cohort_year;


-- Q7c: How many new customers never come back?
-- Only customers who joined Jan 2010 - Aug 2011, so each had at least 3 months to return.
SELECT
  COUNT(*)                                                   AS new_customers,
  COUNTIF(total_orders = 1)                                  AS one_time_buyers,
  ROUND(100 * COUNTIF(total_orders = 1) / COUNT(*), 1)       AS one_time_buyer_pct
FROM `retail-portfolio-513601.analytics.dim_customers`
WHERE cohort_month >  DATE '2009-12-01'
  AND cohort_month <= DATE '2011-08-01';


-- Q7d: Where does revenue come from: long-time customers or newer ones?
WITH sales_by_group AS (
  SELECT
    EXTRACT(YEAR FROM o.invoice_date)                        AS sales_year,
    CASE
      WHEN d.cohort_month = DATE '2009-12-01'        THEN '1. Existing (first seen Dec 2009)'
      WHEN EXTRACT(YEAR FROM d.cohort_month) = 2010  THEN '2. Joined in 2010'
      ELSE                                                '3. Joined in 2011'
    END                                                      AS customer_group,
    SUM(o.order_amount_gbp)                                  AS sales_gbp
  FROM `retail-portfolio-513601.analytics.fct_orders` AS o
  JOIN `retail-portfolio-513601.analytics.dim_customers` AS d
    ON o.customer_id = d.customer_id
  WHERE o.invoice_date < DATE '2011-12-01'     -- exclude the partial month
  GROUP BY sales_year, customer_group
)

SELECT
  sales_year,
  customer_group,
  ROUND(sales_gbp, 0)                                                        AS sales_gbp,
  ROUND(100 * sales_gbp / SUM(sales_gbp) OVER (PARTITION BY sales_year), 1)  AS pct_of_year_sales
FROM sales_by_group
ORDER BY sales_year, customer_group;


-- What you’ll get:

-- Query	What it tells you
-- Q7a	Of customers who buy once, what % come back 1, 2, 3… 12 months later
-- Q7b	Whether customers who joined in early 2011 return as often as those who joined in early 2010
-- Q7c	What % of new customers never place a second order
-- Q7d	How much of each year’s sales came from long-time customers vs. newer ones


-- Q7e: Robustness check for Q7b.
-- Same comparison using Jun-Aug cohorts, which are less affected by the data starting in Dec 2009.
SELECT
  EXTRACT(YEAR FROM cohort_month)                            AS cohort_year,
  months_since_first,
  ROUND(100 * SUM(active_customers) / SUM(cohort_size), 1)   AS retention_pct,
  SUM(cohort_size)                                           AS customers_in_cohorts
FROM `retail-portfolio-513601.analytics.cohort_retention`
WHERE NOT is_pre_existing_customers
  AND NOT is_partial_month
  AND EXTRACT(MONTH FROM cohort_month) BETWEEN 6 AND 8
  AND months_since_first IN (1, 3)
GROUP BY cohort_year, months_since_first
ORDER BY months_since_first, cohort_year;