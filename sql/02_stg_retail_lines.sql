-- RUN ORDER 2: run after the raw tables exist. Creates/replaces the staging.stg_retail_lines view;
-- rerun whenever a cleaning rule changes, then rerun files 03, 04 and 05.

-- 02_stg_retail_lines.sql
-- Cleaned, typed and flagged retail lines.
-- Business purpose: one trusted source for every revenue and customer analysis.

CREATE SCHEMA IF NOT EXISTS `retail-portfolio-513601.staging`
OPTIONS (location = 'US');

CREATE OR REPLACE VIEW `retail-portfolio-513601.staging.stg_retail_lines` AS

WITH combined AS (
  -- Stack both raw files and remember which file each row came from
  SELECT 'retail_2009_2010' AS source_file, invoice, stock_code, description, quantity,
         invoice_date, price, customer_id, country
  FROM `retail-portfolio-513601.raw.retail_2009_2010`
  UNION ALL
  SELECT 'retail_2010_2011' AS source_file, invoice, stock_code, description, quantity,
         invoice_date, price, customer_id, country
  FROM `retail-portfolio-513601.raw.retail_2010_2011`
),

typed AS (
  -- Convert text to proper types and tidy spacing and capitalization
  SELECT
    source_file,
    UPPER(TRIM(invoice))                                    AS invoice,
    UPPER(TRIM(stock_code))                                 AS stock_code,
    NULLIF(TRIM(description), '')                           AS description,
    SAFE_CAST(quantity AS INT64)                            AS quantity,
    SAFE.PARSE_DATETIME('%m/%d/%y %H:%M', invoice_date)     AS invoice_ts,
    SAFE_CAST(price AS NUMERIC)                             AS unit_price,
    NULLIF(TRIM(customer_id), '')                           AS customer_id,
    TRIM(country)                                           AS country
  FROM combined
),

no_overlap AS (
  -- The files overlap Dec 1-9, 2010. Take that period only from the 2010_2011 file.
  SELECT
    source_file, invoice, stock_code, description, quantity,
    invoice_ts, unit_price, customer_id, country
  FROM typed
  WHERE NOT (source_file = 'retail_2009_2010'
             AND invoice_ts >= DATETIME '2010-12-01 00:00:00')
),

deduplicated AS (
  -- Remove exact duplicate lines (assumed system double-entries)
  SELECT DISTINCT
    invoice, stock_code, description, quantity,
    invoice_ts, unit_price, customer_id, country
  FROM no_overlap
),

-- NEW (Step 6): find sales that were fully cancelled the same day
sale_keys AS (
  -- Each sale: customer, product, quantity and day
  SELECT DISTINCT
    customer_id,
    stock_code,
    quantity,
    DATE(invoice_ts)   AS line_date
  FROM deduplicated
  WHERE NOT STARTS_WITH(invoice, 'C')
    AND customer_id IS NOT NULL
    AND quantity > 0
),

cancel_keys AS (
  -- Each cancellation, with its quantity flipped to positive so it can match a sale
  SELECT DISTINCT
    customer_id,
    stock_code,
    -quantity          AS quantity,
    DATE(invoice_ts)   AS line_date
  FROM deduplicated
  WHERE STARTS_WITH(invoice, 'C')
    AND customer_id IS NOT NULL
),

with_reversals AS (
  -- A line is a same-day reversal if the same customer bought AND cancelled
  -- the same product and quantity on the same day (treated as an entry error)
  SELECT
    d.invoice,
    d.stock_code,
    d.description,
    d.quantity,
    d.invoice_ts,
    d.unit_price,
    d.customer_id,
    d.country,
    (c.customer_id IS NOT NULL OR s.customer_id IS NOT NULL)   AS is_same_day_reversal
  FROM deduplicated AS d
  LEFT JOIN cancel_keys AS c          -- sale lines that have a matching cancellation
    ON  NOT STARTS_WITH(d.invoice, 'C')
    AND d.customer_id = c.customer_id
    AND d.stock_code  = c.stock_code
    AND d.quantity    = c.quantity
    AND DATE(d.invoice_ts) = c.line_date
  LEFT JOIN sale_keys AS s            -- cancellation lines that have a matching sale
    ON  STARTS_WITH(d.invoice, 'C')
    AND d.customer_id = s.customer_id
    AND d.stock_code  = s.stock_code
    AND -d.quantity   = s.quantity
    AND DATE(d.invoice_ts) = s.line_date
),

flagged AS (
  SELECT
    invoice,
    stock_code,
    COALESCE(description, 'UNKNOWN')                        AS description,
    quantity,
    invoice_ts,
    DATE(invoice_ts)                                        AS invoice_date,
    unit_price,
    customer_id,
    country,
    quantity * unit_price                                   AS line_amount_gbp,
    STARTS_WITH(invoice, 'C')                               AS is_cancellation,
    -- Reviewed list of codes that are not product sales (DCGS..., PADS, SP1002 ARE products, so kept)
    (stock_code IN ('POST', 'DOT', 'M', 'C2', 'C3', 'D', 'S', 'BANK CHARGES',
                    'AMAZONFEE', 'CRUK', 'B', 'DCGSSGIRL', 'DCGSSBOY')
     OR STARTS_WITH(stock_code, 'ADJUST')
     OR STARTS_WITH(stock_code, 'GIFT')
     OR STARTS_WITH(stock_code, 'TEST'))                    AS is_non_product,
    customer_id IS NULL                                     AS is_missing_customer,
    (quantity <= 0 AND NOT STARTS_WITH(invoice, 'C'))       AS is_invalid_quantity,
    unit_price <= 0                                         AS is_invalid_price,
    is_same_day_reversal                                    -- NEW (Step 6)
  FROM with_reversals
)

SELECT
  invoice,
  stock_code,
  description,
  quantity,
  invoice_ts,
  invoice_date,
  unit_price,
  customer_id,
  country,
  line_amount_gbp,
  is_cancellation,
  is_non_product,
  is_missing_customer,
  is_invalid_quantity,
  is_invalid_price,
  is_same_day_reversal,
  -- A valid sale passes every rule (a missing customer still counts toward revenue)
  NOT (is_cancellation OR is_non_product OR is_invalid_quantity
       OR is_invalid_price OR is_same_day_reversal)          AS is_valid_sale
FROM flagged;