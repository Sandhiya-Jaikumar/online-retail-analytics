-- One row per known customer, built from fct_orders.
-- Orders with no customer ID are excluded (they stay in revenue, not in customer analysis).
-- Ported from sql/04_analytics_tables.sql

WITH customer_orders AS (
  SELECT *
  FROM {{ ref('fct_orders') }}
  WHERE customer_id IS NOT NULL
)

SELECT
  customer_id,
  ARRAY_AGG(country ORDER BY invoice_ts LIMIT 1)[OFFSET(0)]    AS country,
  MIN(invoice_date)                                           AS first_order_date,
  MAX(invoice_date)                                           AS last_order_date,
  DATE_TRUNC(MIN(invoice_date), MONTH)                        AS cohort_month,
  COUNT(DISTINCT invoice)                                     AS total_orders,
  SUM(order_amount_gbp)                                       AS total_sales_gbp,
  SAFE_DIVIDE(SUM(order_amount_gbp), COUNT(DISTINCT invoice)) AS avg_order_value_gbp,
  DATE_DIFF(DATE '2011-12-09', MAX(invoice_date), DAY)        AS days_since_last_order,
  COUNT(DISTINCT invoice) >= 2                                AS is_repeat_customer
FROM customer_orders
GROUP BY customer_id