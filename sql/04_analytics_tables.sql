-- RUN ORDER 4: run after file 02 (needs staging.stg_retail_lines).
-- Creates/replaces the analytics tables; rerun whenever file 02 changes, then run file 05.

-- 04_analytics_tables.sql
-- Business purpose: analysis-ready tables used by every retention, RFM and dashboard query.

CREATE SCHEMA IF NOT EXISTS `retail-portfolio-513601.analytics`
OPTIONS (location = 'US');

-- ---------------------------------------------------------------
-- 1. fct_orders: one row per order (invoice) with at least one valid sale line
-- ---------------------------------------------------------------
CREATE OR REPLACE TABLE `retail-portfolio-513601.analytics.fct_orders` AS

WITH valid_lines AS (
  SELECT
    invoice,
    customer_id,
    invoice_ts,
    country,
    stock_code,
    quantity,
    line_amount_gbp
  FROM `retail-portfolio-513601.staging.stg_retail_lines`
  WHERE is_valid_sale
)

SELECT
  invoice,
  ANY_VALUE(customer_id)          AS customer_id,      -- one customer per invoice (verified in file 05)
  MIN(invoice_ts)                 AS invoice_ts,
  DATE(MIN(invoice_ts))           AS invoice_date,
  ANY_VALUE(country)              AS country,
  COUNT(*)                        AS order_lines,
  COUNT(DISTINCT stock_code)      AS distinct_products,
  SUM(quantity)                   AS units,
  SUM(line_amount_gbp)            AS order_amount_gbp
FROM valid_lines
GROUP BY invoice;

-- ---------------------------------------------------------------
-- 2. dim_customers: one row per customer (customers with an ID only)
-- ---------------------------------------------------------------
CREATE OR REPLACE TABLE `retail-portfolio-513601.analytics.dim_customers` AS

WITH customer_orders AS (
  SELECT
    customer_id,
    invoice,
    invoice_ts,
    invoice_date,
    country,
    order_amount_gbp
  FROM `retail-portfolio-513601.analytics.fct_orders`
  WHERE customer_id IS NOT NULL
)

SELECT
  customer_id,
  -- Country of the customer's first order
  ARRAY_AGG(country ORDER BY invoice_ts LIMIT 1)[OFFSET(0)]       AS country,
  MIN(invoice_date)                                               AS first_order_date,
  MAX(invoice_date)                                               AS last_order_date,
  DATE_TRUNC(MIN(invoice_date), MONTH)                            AS cohort_month,
  COUNT(DISTINCT invoice)                                         AS total_orders,
  SUM(order_amount_gbp)                                           AS total_sales_gbp,
  SAFE_DIVIDE(SUM(order_amount_gbp), COUNT(DISTINCT invoice))     AS avg_order_value_gbp,
  -- "Today" = Dec 9, 2011, the last date in the data (see project brief)
  DATE_DIFF(DATE '2011-12-09', MAX(invoice_date), DAY)            AS days_since_last_order,
  COUNT(DISTINCT invoice) >= 2                                    AS is_repeat_customer
FROM customer_orders
GROUP BY customer_id;

-- ---------------------------------------------------------------
-- 3. monthly_sales: one row per month
-- ---------------------------------------------------------------
CREATE OR REPLACE TABLE `retail-portfolio-513601.analytics.monthly_sales` AS

WITH orders_by_month AS (
  SELECT
    DATE_TRUNC(invoice_date, MONTH)                         AS month,
    COUNT(*)                                                AS orders,
    COUNT(DISTINCT customer_id)                             AS active_customers,  -- blanks not counted
    SUM(order_amount_gbp)                                   AS gross_sales_gbp,
    SUM(IF(customer_id IS NOT NULL, order_amount_gbp, 0))   AS known_customer_sales_gbp
  FROM `retail-portfolio-513601.analytics.fct_orders`
  GROUP BY month
),

new_customers_by_month AS (
  SELECT
    cohort_month   AS month,
    COUNT(*)       AS new_customers
  FROM `retail-portfolio-513601.analytics.dim_customers`
  GROUP BY month
),

cancellations_by_month AS (
  SELECT
    DATE_TRUNC(invoice_date, MONTH)   AS month,
    SUM(line_amount_gbp)              AS cancelled_amount_gbp
  FROM `retail-portfolio-513601.staging.stg_retail_lines`
    WHERE is_cancellation
    AND NOT is_non_product          -- fee/adjustment reversals were never counted as sales
    AND NOT is_same_day_reversal    -- orders cancelled the same day are removed from both sides
  GROUP BY month
)

SELECT
  o.month,
  o.orders,
  o.active_customers,
  COALESCE(n.new_customers, 0)                                AS new_customers,
  o.gross_sales_gbp,
  COALESCE(c.cancelled_amount_gbp, 0)                         AS cancelled_amount_gbp,
  o.gross_sales_gbp + COALESCE(c.cancelled_amount_gbp, 0)     AS net_sales_gbp,
  SAFE_DIVIDE(o.gross_sales_gbp, o.orders)                    AS avg_order_value_gbp,
  SAFE_DIVIDE(o.known_customer_sales_gbp, o.gross_sales_gbp)  AS known_customer_sales_share,
  o.month = DATE '2011-12-01'                                 AS is_partial_month   -- only 9 days of data
FROM orders_by_month AS o
LEFT JOIN new_customers_by_month AS n ON o.month = n.month
LEFT JOIN cancellations_by_month AS c ON o.month = c.month;