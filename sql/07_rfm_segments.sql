-- RUN ORDER 7: run after file 04. Creates analytics.customer_rfm, then answers Exec Question 2.

-- 07_rfm_segments.sql
-- Business question: Which customers drive our revenue, and which valuable ones are slipping away?

-- =================================================================
-- PART A: Build the RFM table (one row per customer)
-- =================================================================
CREATE OR REPLACE TABLE `retail-portfolio-513601.analytics.customer_rfm` AS

WITH ranked AS (
  -- PERCENT_RANK gives tied customers the same rank (e.g. everyone with exactly 1 order)
  SELECT
    customer_id,
    country,
    first_order_date,
    last_order_date,
    cohort_month,
    days_since_last_order                                         AS recency_days,
    total_orders                                                  AS frequency,
    total_sales_gbp                                               AS monetary_gbp,
    PERCENT_RANK() OVER (ORDER BY days_since_last_order DESC)     AS r_pct,  -- most recent = highest
    PERCENT_RANK() OVER (ORDER BY total_orders)                   AS f_pct,
    PERCENT_RANK() OVER (ORDER BY total_sales_gbp)                AS m_pct
  FROM `retail-portfolio-513601.analytics.dim_customers`
),

scored AS (
  -- Turn each percentile into a 1-5 score (5 = top 20%)
  SELECT
    customer_id,
    country,
    first_order_date,
    last_order_date,
    cohort_month,
    recency_days,
    frequency,
    monetary_gbp,
    CASE WHEN r_pct >= 0.8 THEN 5 WHEN r_pct >= 0.6 THEN 4 WHEN r_pct >= 0.4 THEN 3
         WHEN r_pct >= 0.2 THEN 2 ELSE 1 END                      AS r_score,
    CASE WHEN f_pct >= 0.8 THEN 5 WHEN f_pct >= 0.6 THEN 4 WHEN f_pct >= 0.4 THEN 3
         WHEN f_pct >= 0.2 THEN 2 ELSE 1 END                      AS f_score,
    CASE WHEN m_pct >= 0.8 THEN 5 WHEN m_pct >= 0.6 THEN 4 WHEN m_pct >= 0.4 THEN 3
         WHEN m_pct >= 0.2 THEN 2 ELSE 1 END                      AS m_score
  FROM ranked
)

SELECT
  customer_id,
  country,
  first_order_date,
  last_order_date,
  cohort_month,
  recency_days,
  frequency,
  monetary_gbp,
  r_score,
  f_score,
  m_score,
  FORMAT('%d%d%d', r_score, f_score, m_score)                     AS rfm_code,
  CASE
    WHEN r_score >= 4 AND f_score >= 4 THEN '1. Champions'
    WHEN r_score >= 3 AND f_score >= 3 THEN '2. Loyal'
    WHEN r_score >= 4 AND f_score <= 2 THEN '3. New / Promising'
    WHEN r_score <= 2 AND f_score >= 3 THEN '4. At Risk'
    WHEN r_score = 3  AND f_score <= 2 THEN '5. Needs Attention'
    ELSE                                    '6. Hibernating'
  END                                                             AS segment,
  m_score >= 4                                                    AS is_high_value  -- top 40% by spend
FROM scored;


-- =================================================================
-- PART B: Answer the business question (run each query separately)
-- =================================================================

-- Q8a: Segment summary - who holds the revenue?
SELECT
  segment,
  COUNT(*)                                                         AS customers,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS pct_customers,
  ROUND(SUM(monetary_gbp), 0)                                      AS total_sales_gbp,
  ROUND(100 * SUM(monetary_gbp) / SUM(SUM(monetary_gbp)) OVER (), 1) AS pct_sales,
  ROUND(AVG(recency_days), 0)                                      AS avg_days_since_last_order,
  ROUND(AVG(frequency), 1)                                         AS avg_orders,
  ROUND(AVG(monetary_gbp), 0)                                      AS avg_sales_per_customer_gbp
FROM `retail-portfolio-513601.analytics.customer_rfm`
GROUP BY segment
ORDER BY segment;


-- Q8b: How much did each segment buy in the previous 12 months vs the last 12 months?
-- Shows which segments are shrinking and how much revenue is at risk.
WITH segment_sales AS (
  SELECT
    r.segment,
    r.is_high_value,
    SUM(IF(o.invoice_date BETWEEN DATE '2009-12-01' AND DATE '2010-11-30',
           o.order_amount_gbp, 0))                                 AS sales_prior_12m_gbp,
    SUM(IF(o.invoice_date BETWEEN DATE '2010-12-01' AND DATE '2011-11-30',
           o.order_amount_gbp, 0))                                 AS sales_last_12m_gbp
  FROM `retail-portfolio-513601.analytics.customer_rfm` AS r
  JOIN `retail-portfolio-513601.analytics.fct_orders` AS o
    ON r.customer_id = o.customer_id
  GROUP BY r.segment, r.is_high_value
)

SELECT
  segment,
  is_high_value,
  ROUND(sales_prior_12m_gbp, 0)                                    AS sales_prior_12m_gbp,
  ROUND(sales_last_12m_gbp, 0)                                     AS sales_last_12m_gbp,
  ROUND(sales_last_12m_gbp - sales_prior_12m_gbp, 0)               AS change_gbp,
  ROUND(100 * (SAFE_DIVIDE(sales_last_12m_gbp, sales_prior_12m_gbp) - 1), 1) AS change_pct
FROM segment_sales
ORDER BY segment, is_high_value DESC;


-- Q8c: How concentrated is revenue? What share comes from the top 1%, 10% and 20% of customers?
WITH ranked AS (
  SELECT
    monetary_gbp,
    PERCENT_RANK() OVER (ORDER BY monetary_gbp DESC)   AS spend_rank
  FROM `retail-portfolio-513601.analytics.customer_rfm`
)

SELECT
  ROUND(100 * SUM(IF(spend_rank < 0.01, monetary_gbp, 0)) / SUM(monetary_gbp), 1)  AS pct_sales_top_1pct,
  ROUND(100 * SUM(IF(spend_rank < 0.10, monetary_gbp, 0)) / SUM(monetary_gbp), 1)  AS pct_sales_top_10pct,
  ROUND(100 * SUM(IF(spend_rank < 0.20, monetary_gbp, 0)) / SUM(monetary_gbp), 1)  AS pct_sales_top_20pct
FROM ranked;



-- Query	What it tells you
-- Q8a	How many customers and how much revenue each segment holds
-- Q8b	Which segments’ spending is shrinking, and how much revenue is at risk
-- Q8c	How dependent the business is on its top customers



-- Q8d: Size of the win-back opportunity (Exec Question 3, option 1)
-- High-value At Risk customers: how many, what they used to spend, and scenarios for winning some back.
-- The below 2 queries will only gives numbers for Exec Qn 3
WITH at_risk_customers AS (
  SELECT
    r.customer_id,
    SUM(IF(o.invoice_date BETWEEN DATE '2009-12-01' AND DATE '2010-11-30',
           o.order_amount_gbp, 0))   AS sales_prior_12m_gbp,
    SUM(IF(o.invoice_date BETWEEN DATE '2010-12-01' AND DATE '2011-11-30',
           o.order_amount_gbp, 0))   AS sales_last_12m_gbp
  FROM `retail-portfolio-513601.analytics.customer_rfm` AS r
  JOIN `retail-portfolio-513601.analytics.fct_orders` AS o
    ON r.customer_id = o.customer_id
  WHERE r.segment = '4. At Risk'
    AND r.is_high_value
  GROUP BY r.customer_id
)

SELECT
  COUNT(*)                                     AS at_risk_high_value_customers,
  ROUND(SUM(sales_prior_12m_gbp), 0)           AS prior_12m_sales_gbp,
  ROUND(AVG(sales_prior_12m_gbp), 0)           AS avg_prior_12m_sales_per_customer_gbp,
  ROUND(SUM(sales_last_12m_gbp), 0)            AS last_12m_sales_gbp,
  -- Scenarios: if a campaign won back 10%, 20% or 30% of their former yearly spend (assumptions)
  ROUND(0.10 * SUM(sales_prior_12m_gbp), 0)    AS winback_10pct_gbp,
  ROUND(0.20 * SUM(sales_prior_12m_gbp), 0)    AS winback_20pct_gbp,
  ROUND(0.30 * SUM(sales_prior_12m_gbp), 0)    AS winback_30pct_gbp
FROM at_risk_customers;


-- Q8e: What is one new customer worth in their first year? (Exec Question 3, option 2)
-- Customers who joined Jan-Nov 2010, so everyone has a full 12 months of data.
SELECT
  COUNT(DISTINCT d.customer_id)                                          AS new_customers_2010,
  ROUND(SUM(o.order_amount_gbp) / COUNT(DISTINCT d.customer_id), 0)      AS avg_first_12m_sales_gbp
FROM `retail-portfolio-513601.analytics.dim_customers` AS d
JOIN `retail-portfolio-513601.analytics.fct_orders` AS o
  ON  d.customer_id = o.customer_id
  AND o.invoice_date < DATE_ADD(d.first_order_date, INTERVAL 12 MONTH)
WHERE d.cohort_month BETWEEN DATE '2010-01-01' AND DATE '2010-11-01';