-- One row per order (invoice), built from valid sale lines only.
-- Ported from sql/04_analytics_tables.sql

WITH valid_lines AS (
  SELECT *
  FROM {{ ref('stg_retail_lines') }}
  WHERE is_valid_sale
)

SELECT
  invoice,
  ANY_VALUE(customer_id)      AS customer_id,
  MIN(invoice_ts)             AS invoice_ts,
  DATE(MIN(invoice_ts))       AS invoice_date,
  ANY_VALUE(country)          AS country,
  COUNT(*)                    AS order_lines,
  COUNT(DISTINCT stock_code)  AS distinct_products,
  SUM(quantity)               AS units,
  SUM(line_amount_gbp)        AS order_amount_gbp
FROM valid_lines
GROUP BY invoice