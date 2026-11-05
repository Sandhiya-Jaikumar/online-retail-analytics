---- RUN ORDER 3: run after file 02. Verifies the cleaning (overlap removed, summary counts,
-- any unreviewed stock codes). Read-only; safe to rerun anytime.


--Checks 1, 2 and 3 from step 4
-- Rows from the 2009_2010 file dated Dec 1-9, 2010 (the overlap period)

SELECT
  COUNTIF(SAFE.PARSE_DATETIME('%m/%d/%y %H:%M', invoice_date)
          >= DATETIME '2010-12-01 00:00:00')   AS overlap_rows_removed
FROM `retail-portfolio-513601.raw.retail_2009_2010`;



-- Summary of the cleaned view: what was removed, flagged and kept
SELECT
  COUNT(*)                                               AS lines_after_cleaning,
  1067371 - COUNT(*)                                     AS lines_removed_total,
  COUNTIF(is_valid_sale)                                 AS valid_sale_lines,
  COUNTIF(is_cancellation)                               AS cancellation_lines,
  COUNTIF(is_non_product)                                AS non_product_lines,
  COUNTIF(is_invalid_quantity)                           AS invalid_quantity_lines,
  COUNTIF(is_invalid_price)                              AS invalid_price_lines,
  COUNTIF(is_valid_sale AND is_missing_customer)         AS valid_sales_without_customer,
  MIN(invoice_date)                                      AS first_date,
  MAX(invoice_date)                                      AS last_date,
  ROUND(SUM(IF(is_valid_sale, line_amount_gbp, 0)), 2)   AS gross_sales_gbp,
  ROUND(SUM(IF(is_cancellation, line_amount_gbp, 0)), 2) AS cancelled_amount_gbp
FROM `retail-portfolio-513601.staging.stg_retail_lines`;



-- Codes that aren't 5-digit products, aren't DCGS products, and aren't on the exclusion list
SELECT
  stock_code,
  ANY_VALUE(description)   AS example_description,
  COUNT(*)                 AS line_count
FROM `retail-portfolio-513601.staging.stg_retail_lines`
WHERE NOT is_non_product
  AND NOT REGEXP_CONTAINS(stock_code, r'^\d{5}')
  AND NOT STARTS_WITH(stock_code, 'DCGS')
GROUP BY stock_code
ORDER BY line_count DESC;