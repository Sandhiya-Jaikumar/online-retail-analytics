-- RUN ORDER 9: run after file 04. Compares the first 9 days of December across years to sanity-check the forecast.

-- 09_forecast_checks.sql
-- Business question: Is December 2011 running ahead of December 2010?
-- Result (Nov 5, 2026): Dec 1-9 sales were £407,471 in 2010 and £445,252 in 2011 (+9.3%).

SELECT
  EXTRACT(YEAR FROM invoice_date)          AS year,
  ROUND(SUM(order_amount_gbp), 0)          AS sales_dec_1_to_9_gbp
FROM `retail-portfolio-513601.analytics.fct_orders`
WHERE EXTRACT(MONTH FROM invoice_date) = 12
  AND EXTRACT(DAY FROM invoice_date) <= 9
  AND EXTRACT(YEAR FROM invoice_date) IN (2010, 2011)
GROUP BY year
ORDER BY year;