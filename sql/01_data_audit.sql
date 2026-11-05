-- RUN ORDER 1: run after loading the two CSVs into raw.retail_2009_2010 and raw.retail_2010_2011
-- (all columns STRING, 1 header row skipped). Read-only checks; safe to rerun anytime.

--Audit 1: date range and row count per source file.
-- Business reason: confirms which period each file covers and finds dates that can't be read.

WITH combined AS (
  SELECT 'retail_2009_2010' AS source_file, invoice, invoice_date
  FROM `retail-portfolio-513601.raw.retail_2009_2010`
  UNION ALL
  SELECT 'retail_2010_2011' AS source_file, invoice, invoice_date
  FROM `retail-portfolio-513601.raw.retail_2010_2011`
),

parsed AS (
  SELECT
    source_file,
    -- Text like '12/1/10 8:26' -> a real date-time (month/day/2-digit year hour:minute)
    SAFE.PARSE_DATETIME('%m/%d/%y %H:%M', invoice_date) AS invoice_ts
  FROM combined
)

SELECT
  source_file,
  COUNT(*)                        AS row_count,
  MIN(invoice_ts)                 AS first_transaction,
  MAX(invoice_ts)                 AS last_transaction,
  COUNTIF(invoice_ts IS NULL)     AS dates_that_could_not_be_read
FROM parsed
GROUP BY source_file
ORDER BY source_file;



-- Audit 2: count every known data quality problem across both files.
-- Business reason: shows how much of the data is usable for customer and revenue analysis.

WITH combined AS (
  SELECT * FROM `retail-portfolio-513601.raw.retail_2009_2010`
  UNION ALL
  SELECT * FROM `retail-portfolio-513601.raw.retail_2010_2011`
)

SELECT
  COUNT(*)                                                         AS total_rows,
  COUNTIF(customer_id IS NULL OR TRIM(customer_id) = '')           AS missing_customer_id,
  COUNTIF(STARTS_WITH(UPPER(invoice), 'C'))                        AS cancellation_rows,
  COUNTIF(SAFE_CAST(quantity AS INT64) <= 0)                       AS zero_or_negative_quantity,
  COUNTIF(SAFE_CAST(price AS NUMERIC) <= 0)                        AS zero_or_negative_price,
  COUNTIF(description IS NULL OR TRIM(description) = '')           AS missing_description,
  COUNTIF(SAFE_CAST(quantity AS INT64) IS NULL)                    AS quantity_not_a_number,
  COUNTIF(SAFE_CAST(price AS NUMERIC) IS NULL)                     AS price_not_a_number,
  -- Real products have codes starting with 5 digits (e.g. 85123A); others are fees, postage, etc.
  COUNTIF(NOT REGEXP_CONTAINS(stock_code, r'^\d{5}'))              AS non_product_stock_codes
FROM combined;


-- Audit 3: exact duplicate rows, and invoices that appear in BOTH files.
-- Business reason: duplicates would double-count revenue.

WITH combined AS (
  SELECT * FROM `retail-portfolio-513601.raw.retail_2009_2010`
  UNION ALL
  SELECT * FROM `retail-portfolio-513601.raw.retail_2010_2011`
),

invoices_in_both AS (
  SELECT a.invoice
  FROM (SELECT DISTINCT invoice FROM `retail-portfolio-513601.raw.retail_2009_2010`) AS a
  INNER JOIN (SELECT DISTINCT invoice FROM `retail-portfolio-513601.raw.retail_2010_2011`) AS b
    ON a.invoice = b.invoice
)

SELECT
  COUNT(*)                                               AS total_rows,
  COUNT(DISTINCT TO_JSON_STRING(combined))               AS distinct_rows,
  COUNT(*) - COUNT(DISTINCT TO_JSON_STRING(combined))    AS exact_duplicate_rows,
  (SELECT COUNT(*) FROM invoices_in_both)                AS invoices_found_in_both_files
FROM combined;



-- Audit 4: list stock codes that aren't regular products (fees, postage, adjustments).
-- Business reason: these aren't product sales and may need to be excluded from revenue.

WITH combined AS (
  SELECT * FROM `retail-portfolio-513601.raw.retail_2009_2010`
  UNION ALL
  SELECT * FROM `retail-portfolio-513601.raw.retail_2010_2011`
)

SELECT
  stock_code,
  ANY_VALUE(description)   AS example_description,
  COUNT(*)                 AS row_count
FROM combined
WHERE NOT REGEXP_CONTAINS(stock_code, r'^\d{5}')
GROUP BY stock_code
ORDER BY row_count DESC
LIMIT 30;