-- RUN ORDER 8: run after files 06 and 07. Each query's result is saved as a CSV for Tableau Public.
-- In BigQuery: run one query, then Save results -> CSV (local file). Save to the exports folder.

-- Export 1 -> monthly_sales.csv
SELECT *
FROM `retail-portfolio-513601.analytics.monthly_sales`
ORDER BY month;

-- Export 2 -> cohort_retention.csv
SELECT *
FROM `retail-portfolio-513601.analytics.cohort_retention`
ORDER BY cohort_month, months_since_first;

-- Export 3 -> customer_rfm.csv
SELECT *
FROM `retail-portfolio-513601.analytics.customer_rfm`
ORDER BY monetary_gbp DESC;

-- Export 4 -> segment_sales_trend.csv (same logic as Q8b)
WITH segment_sales AS (
  SELECT
    r.segment,
    r.is_high_value,
    SUM(IF(o.invoice_date BETWEEN DATE '2009-12-01' AND DATE '2010-11-30',
           o.order_amount_gbp, 0))   AS sales_prior_12m_gbp,
    SUM(IF(o.invoice_date BETWEEN DATE '2010-12-01' AND DATE '2011-11-30',
           o.order_amount_gbp, 0))   AS sales_last_12m_gbp
  FROM `retail-portfolio-513601.analytics.customer_rfm` AS r
  JOIN `retail-portfolio-513601.analytics.fct_orders` AS o
    ON r.customer_id = o.customer_id
  GROUP BY r.segment, r.is_high_value
)

SELECT
  segment,
  is_high_value,
  ROUND(sales_prior_12m_gbp, 2)                      AS sales_prior_12m_gbp,
  ROUND(sales_last_12m_gbp, 2)                       AS sales_last_12m_gbp,
  ROUND(sales_last_12m_gbp - sales_prior_12m_gbp, 2) AS change_gbp
FROM segment_sales
ORDER BY segment, is_high_value DESC;