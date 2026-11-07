# **Data Quality Log: Online Retail II**

Nov 3, 2026 

## **About this log**

This log records every data problem I found in the raw data, what I decided to do about it, and why. It's the evidence behind every number in the project.

|  |  |
| ----- | ----- |
| **Project** | Customer Retention & Revenue Analytics |
| **Data source** | UCI Online Retail II: real transactions from a UK online giftware retailer, Dec 2009 – Dec 2011 |
| **Raw size** | 1,067,371 rows in 2 files |
| **Cleaning rules live in** | `sql/02_stg_retail_lines.sql` |

**How to read it:** each row shows a problem, what I decided, and why. **(assumption)** marks a decision based on judgment rather than proof.

## **Result in one minute**

After cleaning, 1,003,313 lines (97.1% of clean rows) count as valid sales, worth £19.64M in gross sales.

| Measure | Result |
| ----- | ----- |
| Raw rows loaded | 1,067,371 (matches UCI’s official count) |
| Rows removed (overlap \+ duplicates) | 34,335 |
| Clean rows | 1,033,036 |
| Valid sale lines | **1001485 (96.9% of clean rows)** |
| Gross sales | £19,195,880.05 |
| Product cancellations | −£327,733.28 (1.7% of gross sales) |
| Net sales | £18,868,146.77 |
| Orders | 39,289 |
| Customers (with an ID) | 5,848, of whom 72.3% ordered more than once |
| Valid sales with no customer ID | 226,717 lines **\[22.6%\]** |

## **Problems found and decisions**

I found 12 problems. Each one was measured before I decided how to handle it.

| \# | Problem | What I found | Decision | Why |
| ----- | ----- | ----- | ----- | ----- |
| 1 | Files overlap | Both files contain Dec 1–9, 2010: 22,523 rows (1,088 invoices) appear twice | Keep that period from the 2010\_2011 file only | Otherwise those sales are counted twice |
| 2 | Exact duplicate lines | 11,812 lines repeated exactly (same invoice, product, time, quantity, price, customer) | Remove **(assumption)** | Looks like a system double-entry, not a real second purchase |
| 3 | Missing customer ID | 22.6% of valid sale lines have no customer | Keep in revenue; leave out of customer analysis | The sale is real, but an unknown customer can't be tracked over time |
| 4 | Cancellations | 19,104 lines (invoice starts with "C"), worth −£1.46M | Flag and report separately | Shows gross sales, cancellations and net sales clearly |
| 5 | Zero/negative quantity (not cancellations) | 3,393 lines | Exclude from sales | Stock adjustments or damages, not purchases |
| 6 | Zero/negative price | 6,019 lines | Exclude from sales | Free items, adjustments and bad-debt entries aren't sales |
| 7 | Missing description | 4,382 raw rows | Label "UNKNOWN"; don't exclude for this alone | The sale is still valid if code, price and quantity are fine |
| 8 | Non-product codes | 5,849 lines: postage, fees, manual entries, discounts, samples, bank charges, Amazon fees, commission, test items, bad debt, gift vouchers | Exclude using a reviewed list | Product revenue should count only products |
| 9 | My first rule was wrong | "Real products start with 5 digits" wrongly flagged real products (DCGS…, PADS, SP1002) | Replaced the pattern with a reviewed list | Avoids throwing away real sales |
| 10 | Codes found in final review | ADJUST2 (adjustment), GIFT and C3 (no description) | Exclude; C3 treated as a carriage charge like C2 **(assumption)** | Not product sales |
| 11 | Inconsistent capitalization | "m" and "M" both mean "Manual" | Make codes uppercase before comparing | Same code is treated the same way |
| 12 | Dates stored as text | Format like "12/1/10 8:26" | Converted to real dates; 0 failed | Needed for monthly and cohort analysis |
| 13 | Orders with more than one timestamp | 82 invoices; 79 within 1 minute, the largest gap 9 minutes | Use the earliest time as the order time | One order typed in over a few minutes |
| 14 | Orders placed and cancelled the same day | 1,969 sale lines (£557,524), including two giant orders: 80,995 paper craft units (£168,469.60) and 74,215 storage jars (£77,183.60) | Remove both the sale and its cancellation (assumption: entry errors) | Otherwise two customers look like top spenders who kept nothing |
| 15 | Fee reversals counted as cancellations | Reversals of manual entries, bank charges and Amazon fees made cancellations look like −£1.46M | Count product cancellations only | Fees were never counted as sales, so their reversals shouldn’t reduce sales |
| 16 | Limitation of rule 14 | 181 more sale lines matched than cancellation lines | Accept; up to about £44k (0.2% of sales) may be over-excluded | Small, and documented honestly |

## **How I proved the cleaning worked**

Every check passed: the totals reconcile exactly, and nothing failed to convert.

| Check | Result |
| ----- | ----- |
| Row count after loading | 1,067,371, matches the source exactly |
| Removed rows vs. duplicates found | Audit found 34,335 duplicates; cleaning removed exactly 34,335 (22,523 overlap \+ 11,812 duplicates). This also proves every overlap row was an exact copy |
| Dates and numbers converted | 0 dates, quantities or prices failed to convert |
| Unreviewed codes left | Only PADS and SP1002 remain, both real products |
| Effect of the final rule update | 5 more lines flagged, but valid sales fell by only 3, because 2 were already excluded by another rule |
| Sales match across all three layers | Staging, orders and monthly tables all equal £19,195,880.05 |
| Giant-order customers after fix | Customer 16446 went from £168k to £2.90; customer 12346 from £77k to £169.36 |

## **When each step was done**

| Date | Step | What I did | File |
| ----- | ----- | ----- | ----- |
| Nov 5,2026 | V2-2 | Backtested three forecasting methods, forecast next-quarter sales, and checked the forecast against early December data | `notebooks/02_revenue_forecast.ipynb, sql/09_forecast_checks.sql` |
| Nov 5,2026 | V2-1 | Validated RFM segments with k-means clustering in Python; found an early-warning group inside “Loyal”  | `notebooks/01_kmeans_segmentation.ipynb` |
| Nov 4, 2026 | 10 | Wrote the one-page executive memo answering Exec Question 3: win back 324 high-value At Risk customers, £94k–£281k a year, tested with a 50/50 split  | `docs/executive_memo.pdf, docs/executive_memo.md` |
| Nov 4, 2026 | 9 | Exported 4 tables; built and published the Tableau Public dashboard | `sql/08_exports_for_tableau.sql, exports` |
| Nov 3, 2026 | 8 | Built RFM scores and customer segments; answered Exec Question 2  | `sql/07_rfm_segments.sql (includes opportunity sizing, Q8d - Q8e)` |
| Nov 3, 2026 | 7 | Built the cohort retention table; answered Exec Question 1; tested the finding against a cleaner season | `sql/06_cohort_retention.sql` |
| Nov 3, 2026 | 6 | Built analytics table (orders, customers, monthly sales); found and fixed same-day reversals and fee reversals | `sql/04_analytics_tables.sql, sql/05_analytics_checks.sql` |
| Nov 3, 2026 | 5 | Wrote the project brief: stakeholder (Head of Sales), 3 executive questions, 14 metric definitions, rules and assumptions | `docs/project_brief.md` |
| Nov 3, 2026 | 4 | Built the cleaned view and verified it | `sql/02_stg_retail_lines.sql`, `sql/03_cleaning_checks.sql` |
| Nov 2, 2026 | 3 | Audited the raw data and measured every problem | `sql/01_data_audit.sql` |
| Nov 2, 2026 | 1–2 | Downloaded the data; loaded both files into BigQuery as text (`raw` dataset) | Done in the BigQuery interface |

## 

## 

## **Key project decisions (Step 5\)**

| Decision | Why |
| ----- | ----- |
| Stakeholder \= Head of Sales; every analysis must answer one of 3 questions | Keeps the project focused on business decisions, not random charts |
| “Today” \= Dec 9, 2011 (last date in the data) | Recency and “days since last order” need a fixed reference date |
| Dec 2011 excluded from monthly trends | It has only 9 days, so it would look like a false sales drop |
| Customer metrics use only rows with a customer ID | Unknown customers can’t be tracked over time |
| Net sales \= gross sales \+ cancelled amount (cancellations are negative) | Shows the true money kept after reversals  |

## **Early business findings:**

| Finding | Evidence |
| ----- | ----- |
| Strong seasonality | Sales peak every Oct–Nov (about £1.4M in Nov 2010 and Nov 2011): holiday restocking |
| New customers are falling | New customers in Mar, Sep, Oct and Nov dropped from 441, 239, 375, 326 (2010) to 179, 188, 221, 191 (2011), while November sales stayed flat. The business increasingly relies on existing customers |
| About 13% of revenue has no customer ID | Those orders average 77.6 lines vs 21.2, so they’re large, untracked orders |
| Dec 2009 “new” customers are misleading | The data starts that month, so its 951 customers include long-time buyers (left-censoring) |
| New customers are loyal | 72.8% buy again; about 20% buy in any month after joining; a bump at month 12 shows a yearly buying cycle |
| Retention is stable | Jun–Aug cohorts: month-3 retention 26.5% (2010) vs 26.9% (2011) |
| Acquisition fell sharply | New customers down 66% (Jan–May) and 49% (Jun–Aug) in 2011 vs 2010 |
| Revenue depends on older customers | 82% of 2011 known-customer sales came from customers won before 2011; the oldest group’s sales fell about 21% per month |
| Champions drive the business | 23.6% of customers, 69.4% of known-customer sales, \+14% year over year |
| Valuable customers are slipping away | 710 At Risk customers; the high-value ones dropped from £935k to £184k in yearly sales (−£751k) |
| Revenue is highly concentrated | Top 1% \= 31.1% of sales; top 20% \= 76.7% |
| Win-back opportunity | 324 high-value At Risk customers spent £935,383 in the previous 12 months but only £184,077 in the last 12 months. Winning back 10–30% of their former spend \= £94k–£281k a year |
| Value of a new customer | Customers who joined in 2010 spent £1,487 each in their first 12 months on average (upper estimate) |
| Two methods agree on the segments | 5 of 6 RFM segments map mainly to one k-means cluster; Champions 75% → Core accounts, At Risk 85% → Lapsing regulars |
| Early-warning group inside “Loyal” | 605 Loyal customers cluster with lapsing regulars: median 5 orders, 98 days since last order, £1.2M lifetime sales |
| Last year’s same month is the best guide | Seasonal naive: 6.1% monthly error vs 11.1% (with recent growth) and 20.8% (naive) on Jun–Nov 2011 |
| Next quarter ≈ £1.87M | Range £1.76M–£1.99M; about half the autumn level |
| Risk is under-planning | All three methods under-forecast the backtest; seasonal naive by 5.5% |
| December 2011 is running ahead | Dec 1–9: £445,252 (2011) vs £407,471 (2010), \+9.3%; implies about £843k for the month if the pattern holds, above the forecast’s high end |

## 

## **Analysis decisions:**

| Decision | Why |
| ----- | ----- |
| Dec 2009 cohort excluded from retention comparisons | Data starts that month, so those customers aren’t truly new (left-censoring) |
| Dec 2011 excluded from retention numbers | Only 9 days of data |
| Built a full cohort × month grid with zeros | Without zeros, months where nobody returned disappear and retention looks better than it is |
| Compared the same season across years | Holiday seasonality would distort a Jan vs. Nov comparison |
| Retested on Jun–Aug cohorts | Early 2010 was distorted by the data start date. The retest showed retention was stable, which reversed my first conclusion |
| Used `PERCENT_RANK` instead of `NTILE` for scores | Customers with identical values (e.g. exactly 1 order) get the same score instead of being split at random |
| Segments based on Recency \+ Frequency; “high value” \= top 40% by spend | R and F describe behavior; M separates which customers matter most financially |
| Judged At Risk by what they *used to* spend, not by the % drop | The drop is partly built into the definition; the £ they used to spend is the real opportunity |
| Win-back value shown as 10% / 20% / 30% scenarios | The real win-back rate is unknown, so I show a range and recommend a test to measure it, instead of presenting one guess as fact |
| Every chart title states the finding, not the topic | An executive gets the answer in seconds without interpreting the chart |
| Heatmap grouped by quarter, with retention \= returning customers ÷ cohort size | 23 monthly rows didn’t fit, and retention rates can’t be added or averaged across cohorts of different sizes |
| No dashboard-wide filters | The four data sources have different levels of detail (month, cohort, customer, segment), so a shared filter would give inconsistent numbers |
| At Risk chart shows only Champions, Loyal and At Risk | Keeps the At Risk drop visible next to healthy segments |
| Color keys written in the titles instead of legends | Cleaner layout, with fewer boxes to read |
| Log-transformed and standardized recency, frequency and spend before clustering | Spend had a skew of 26.6 from a few very large accounts; without the fix they would define the clusters |
| Chose k \= 4 | The elbow bends at 4, silhouette has a local peak at 4 (0.364), and 4 groups are actionable; k \= 2 scored higher but only split active from lapsed |
| Profiled clusters with medians | Averages would be pulled up by the largest accounts |
| Used simple seasonal methods, not complex models | Only 24 full months (two holiday seasons); complex models would overfit |
| Backtested on Jun–Nov 2011 before forecasting | Proves accuracy on months the method hadn’t seen |
| Kept the simpler method over the growth-adjusted one | The growth adjustment carried a spring dip into autumn and doubled the error |
| Range \= ±6.1% (backtest error) | An honest, explainable range for executives |
| Checked the forecast against Dec 1–9 actuals | A quick reality check with real data, stated as an early signal, not proof |

## **V2-3 dbt**

**dbt staging model check (Nov 7, 2026\)**

* **What:** Rebuilt the staging view in dbt using `source()` for the two raw tables.  
* **Check:** Compared the dbt view with the original view.  
* **Result:** Identical: 1,033,036 rows, 1,001,485 valid sale lines, £19,195,880.05 gross sales.  
* **Why it matters:** Proves the migration changed nothing. Same logic, now version-controlled and testable.  
* **fct\_orders in dbt:** 39,289 orders, 2,922 with no customer ID, £19,195,880.05. Matches the original table exactly.  
* **dim\_customers in dbt:** 5,848 customers, 72.3% repeat, 36,367 orders, £16,621,148.13 known-customer sales. Matches the original table exactly.  
* **monthly\_sales in dbt:** 25 months, 39,289 orders, 5,848 new customers, gross £19,195,880.05, cancellations −£327,733.28, net £18,868,146.77. Matches the original table exactly.

**dbt tests (10, all passing):**

* unique \+ not\_null on every primary key (order, customer, month), which proves each table’s grain.  
* Every customer ID on an order exists in dim\_customers (relationships test).  
* A custom test fails if revenue differs between staging, fct\_orders and monthly\_sales, or doesn’t equal £19,195,880.05.  
* **Why it matters:** checks I did by hand now run automatically on every build.  
* 

> 

> 

> 

