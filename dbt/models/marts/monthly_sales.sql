-- One row per month: orders, customers, gross/net sales and cancellations.
-- Ported from sql/04_analytics_tables.sql

WITH orders_by_month AS (
  SELECT
    DATE_TRUNC(invoice_date, MONTH)                         AS month,
    COUNT(*)                                                AS orders,
    COUNT(DISTINCT customer_id)                             AS active_customers,
    SUM(order_amount_gbp)                                   AS gross_sales_gbp,
    SUM(IF(customer_id IS NOT NULL, order_amount_gbp, 0))   AS known_customer_sales_gbp
  FROM {{ ref('fct_orders') }}
  GROUP BY month
),

new_customers_by_month AS (
  SELECT
    cohort_month AS month,
    COUNT(*)     AS new_customers
  FROM {{ ref('dim_customers') }}
  GROUP BY month
),

-- Product cancellations only: fee reversals and same-day reversals are excluded
cancellations_by_month AS (
  SELECT
    DATE_TRUNC(invoice_date, MONTH) AS month,
    SUM(line_amount_gbp)            AS cancelled_amount_gbp
  FROM {{ ref('stg_retail_lines') }}
  WHERE is_cancellation
    AND NOT is_non_product
    AND NOT is_same_day_reversal
  GROUP BY month
)

SELECT
  o.month,
  o.orders,
  o.active_customers,
  COALESCE(n.new_customers, 0)                                  AS new_customers,
  o.gross_sales_gbp,
  COALESCE(c.cancelled_amount_gbp, 0)                           AS cancelled_amount_gbp,
  o.gross_sales_gbp + COALESCE(c.cancelled_amount_gbp, 0)       AS net_sales_gbp,
  SAFE_DIVIDE(o.gross_sales_gbp, o.orders)                      AS avg_order_value_gbp,
  SAFE_DIVIDE(o.known_customer_sales_gbp, o.gross_sales_gbp)    AS known_customer_sales_share,
  o.month = DATE '2011-12-01'                                   AS is_partial_month
FROM orders_by_month AS o
LEFT JOIN new_customers_by_month AS n USING (month)
LEFT JOIN cancellations_by_month AS c USING (month)