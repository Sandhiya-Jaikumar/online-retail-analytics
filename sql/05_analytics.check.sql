-- RUN ORDER 5: run after file 04. Verifies the analytics tables. Read-only; safe to rerun anytime.

-- Check A: Do all three layers give the same gross sales? (expected: £19,643,314.66 in every column)
SELECT
  (SELECT ROUND(SUM(line_amount_gbp), 2)
   FROM `retail-portfolio-513601.staging.stg_retail_lines`
   WHERE is_valid_sale)                                                    AS staging_total_gbp,
  (SELECT ROUND(SUM(order_amount_gbp), 2)
   FROM `retail-portfolio-513601.analytics.fct_orders`)                    AS orders_total_gbp,
  (SELECT ROUND(SUM(gross_sales_gbp), 2)
   FROM `retail-portfolio-513601.analytics.monthly_sales`)                 AS monthly_total_gbp;

-- Check B: Does every invoice have exactly one customer and one timestamp? (expected: 0 and 0)
SELECT
  COUNTIF(customer_count > 1)    AS invoices_with_multiple_customers,
  COUNTIF(timestamp_count > 1)   AS invoices_with_multiple_timestamps
FROM (
  SELECT
    invoice,
    COUNT(DISTINCT customer_id)  AS customer_count,
    COUNT(DISTINCT invoice_ts)   AS timestamp_count
  FROM `retail-portfolio-513601.staging.stg_retail_lines`
  WHERE is_valid_sale
  GROUP BY invoice
);

-- Check C: Headline numbers for the project
SELECT
  (SELECT COUNT(*) FROM `retail-portfolio-513601.analytics.fct_orders`)                AS total_orders,
  (SELECT COUNTIF(customer_id IS NULL)
   FROM `retail-portfolio-513601.analytics.fct_orders`)                               AS orders_without_customer,
  (SELECT COUNT(*) FROM `retail-portfolio-513601.analytics.dim_customers`)            AS total_customers,
  (SELECT ROUND(100 * COUNTIF(is_repeat_customer) / COUNT(*), 1)
   FROM `retail-portfolio-513601.analytics.dim_customers`)                            AS repeat_customer_pct,
  (SELECT ROUND(AVG(avg_order_value_gbp), 2)
   FROM `retail-portfolio-513601.analytics.dim_customers`)                            AS avg_customer_aov_gbp;

-- Check D: Monthly trend at a glance (25 rows, Dec 2009 - Dec 2011)
SELECT
  month,
  orders,
  active_customers,
  new_customers,
  ROUND(gross_sales_gbp, 0)        AS gross_sales_gbp,
  ROUND(cancelled_amount_gbp, 0)   AS cancelled_amount_gbp,
  is_partial_month
FROM `retail-portfolio-513601.analytics.monthly_sales`
ORDER BY month;


-- Check E: For the 82 invoices with more than one timestamp, how far apart are the times?
-- (expected: gaps of about 1 minute, meaning one order typed in across a minute boundary)
SELECT
  COUNT(*)                         AS invoices_checked,
  COUNTIF(gap_minutes <= 1)        AS gap_of_1_minute_or_less,
  MAX(gap_minutes)                 AS largest_gap_minutes
FROM (
  SELECT
    invoice,
    DATETIME_DIFF(MAX(invoice_ts), MIN(invoice_ts), MINUTE)   AS gap_minutes
  FROM `retail-portfolio-513601.staging.stg_retail_lines`
  WHERE is_valid_sale
  GROUP BY invoice
  HAVING COUNT(DISTINCT invoice_ts) > 1
);

-- Check F: The 10 largest cancellations. Are a few huge orders driving the spikes?
SELECT
  invoice,
  invoice_date,
  stock_code,
  description,
  quantity,
  unit_price,
  ROUND(line_amount_gbp, 2)   AS amount_gbp,
  customer_id
FROM `retail-portfolio-513601.staging.stg_retail_lines`
WHERE is_cancellation
ORDER BY line_amount_gbp ASC
LIMIT 10;

-- Check G: How much revenue comes from orders without a customer ID, and are those orders bigger?
SELECT
  ROUND(100 * SUM(IF(customer_id IS NULL, order_amount_gbp, 0))
            / SUM(order_amount_gbp), 1)                          AS pct_sales_without_customer,
  ROUND(AVG(IF(customer_id IS NULL, order_lines, NULL)), 1)      AS avg_lines_per_order_no_customer,
  ROUND(AVG(IF(customer_id IS NOT NULL, order_lines, NULL)), 1)  AS avg_lines_per_order_with_customer
FROM `retail-portfolio-513601.analytics.fct_orders`;


-- Check H: Same-day reversals and the corrected sales figures
-- (reversed sales and matched cancellations should be roughly equal and opposite)
SELECT
  COUNTIF(is_same_day_reversal AND NOT is_cancellation)                     AS reversed_sale_lines,
  ROUND(SUM(IF(is_same_day_reversal AND NOT is_cancellation,
               line_amount_gbp, 0)), 2)                                     AS reversed_sales_gbp,
  COUNTIF(is_same_day_reversal AND is_cancellation)                         AS matched_cancellation_lines,
  ROUND(SUM(IF(is_same_day_reversal AND is_cancellation,
               line_amount_gbp, 0)), 2)                                     AS matched_cancellations_gbp,
  ROUND(SUM(IF(is_cancellation AND NOT is_non_product AND NOT is_same_day_reversal,
               line_amount_gbp, 0)), 2)                                     AS product_cancellations_gbp,
  ROUND(SUM(IF(is_valid_sale, line_amount_gbp, 0)), 2)                      AS gross_sales_gbp
FROM `retail-portfolio-513601.staging.stg_retail_lines`;

-- Check I: The two giant-order customers after the fix
SELECT
  customer_id,
  total_orders,
  ROUND(total_sales_gbp, 2)   AS total_sales_gbp
FROM `retail-portfolio-513601.analytics.dim_customers`
WHERE customer_id IN ('16446', '12346');