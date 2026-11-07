-- Revenue must be identical in every layer, and equal the verified total.
-- The test passes when this query returns zero rows.

WITH totals AS (
  SELECT
    (SELECT SUM(line_amount_gbp)  FROM {{ ref('stg_retail_lines') }} WHERE is_valid_sale) AS staging_gbp,
    (SELECT SUM(order_amount_gbp) FROM {{ ref('fct_orders') }})                           AS orders_gbp,
    (SELECT SUM(gross_sales_gbp)  FROM {{ ref('monthly_sales') }})                        AS monthly_gbp
)

SELECT *
FROM totals
WHERE staging_gbp != orders_gbp
   OR orders_gbp  != monthly_gbp
   OR ROUND(staging_gbp, 2) != 19195880.05