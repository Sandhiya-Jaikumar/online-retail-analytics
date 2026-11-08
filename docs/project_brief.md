# Project Brief: Customer Retention & Revenue Analytics

## Business context

A UK-based online giftware retailer that sells mainly to wholesale (business) customers. Data: 1,067,371 transaction lines, Dec 1, 2009 – Dec 9, 2011 (UCI Online Retail II). All amounts are in British pounds (GBP, £).

## Stakeholder

Head of Sales, who must decide where to focus the sales and marketing budget next quarter.

## Executive questions

1. **Are we keeping the customers we win?** How many first-time customers come back, and is that getting better or worse?  
2. **Which customers drive our revenue, and which valuable ones are slipping away?** Which segments hold the most revenue, and which high-value customers have stopped buying?  
3. **Where should we focus next quarter, and what is it worth?** One recommendation with an estimated £ impact and a way to test it.

Every analysis in this project must answer one of these questions.

## Metric definitions

| Metric | Plain definition | How it's calculated |
| :---- | :---- | :---- |
| Valid sale line | A product sold to a customer that wasn't cancelled, isn't a fee/adjustment, and has a positive quantity and price and wasn’t fully cancelled the same day. | `is_valid_sale = TRUE` in `stg_retail_lines` |
| Gross sales | Money from valid sale lines | `SUM(line_amount_gbp)` of valid sale lines |
| Cancelled amount | Value of cancelled **product** lines (negative), excluding fee reversals and same-day reversals. | `SUM(line_amount_gbp)` where `is_cancellation AND NOT is_non_product AND NOT is_same_day_reversal` |
| Net sales | Gross sales minus cancellations | Gross sales \+ cancelled amount |
| Order | An invoice with at least one valid sale line | `COUNT(DISTINCT invoice)` of valid sale lines |
| Customer | A customer ID with at least one order | Lines with no customer ID are excluded from customer metrics |
| Average order value (AOV) | Gross sales per order | Gross sales ÷ orders |
| Active customer (in a month) | A customer who placed at least one order that month | `COUNT(DISTINCT customer_id)` per month |
| Cohort month | The month of a customer's first order | `DATE_TRUNC(first_order_date, MONTH)` |
| Retention rate, month N | Share of a cohort that ordered again N months after their first month | Active cohort customers in month N ÷ cohort size |
| Repeat purchase rate | Share of customers with 2 or more orders | Customers with 2+ orders ÷ all customers |
| Recency | Days since a customer's last order, as of Dec 9, 2011 | `DATE_DIFF('2011-12-09', last_order_date, DAY)` |
| Frequency | Number of orders a customer has placed | `COUNT(DISTINCT invoice)` per customer |
| Monetary | Total gross sales from a customer | `SUM(line_amount_gbp)` per customer |

## Rules and assumptions

**Dates and periods**

* **Analysis date (“today”):** Dec 9, 2011, the last date in the data.  
* **Partial months:** Dec 2011 has only 9 days, so it’s excluded from monthly trend comparisons.  
* **Overlapping files:** both yearly files contain Dec 1–9, 2010\. That period is taken from the 2010\_2011 file only, so those sales aren’t counted twice.

**What counts as a sale**

* **Exact duplicate lines** are treated as system double-entries and removed (assumption).  
* **Same-day reversals:** when a sale and a cancellation have the same customer, product, quantity and day, both are removed (assumption: entry errors). This may over-exclude up to about £44k (0.2% of sales).  
* **Non-product codes:** postage, fees, manual adjustments, bank charges, Amazon fees, test items and gift vouchers are excluded using a reviewed list of stock codes, not a pattern rule (a pattern wrongly caught real products).  
* **Cancellations:** only product cancellations count; fee reversals are excluded because fees were never counted as sales. Some cancellations may reverse orders placed before Dec 2009, outside the data (assumption).

**Customers and segments**

* **Missing customer IDs:** 22.6% of valid sale lines. Included in revenue, excluded from customer analysis.  
* **Dec 2009 cohort:** the data starts that month, so its “new” customers include long-time buyers. It’s excluded from retention comparisons.  
* **High-value customers:** the top 40% of customers by total spend.

**Findings:**

1. **Are we keeping the customers we win?** How many first-time customers come back, and is that getting better or worse?

> ***Yes, we keep the customers we win, but we’re winning far fewer of them.** New customers are loyal: 72% buy again, about 1 in 5 buys in any given month, and many return a year later for holiday restocking. Customers who joined in 2011 return as often as those from 2010\. The real problem is acquisition: the business won roughly half as many new customers in 2011, and its oldest customers are spending about 21% less per month. Revenue is being held up by customers won before 2011 (82% of 2011 known-customer sales).*

2. **Which customers drive our revenue, and which valuable ones are slipping away?** Which segments hold the most revenue, and which high-value customers have stopped buying?  
> *Champions (24% of customers) drive 69% of known-customer sales and grew 14% last year. Revenue is highly concentrated: the top 1% of customers bring in 31%, and the top 20% bring in 77%. The valuable customers slipping away are the At Risk segment: 710 customers who used to order about 5–6 times but haven’t bought in about a year. The high-value ones among them spent £935k the year before and only £184k in the last 12 months, a loss of about £751k a year.*  
3. **3\. Where should we focus next quarter, and what is it worth?** One recommendation with an estimated £ impact and a way to test it.   
     
> ***Win back the 324 high-value At Risk customers.** They spent £935k in the previous 12 months but only £184k in the last 12 months. Winning back 10–30% of their former spend is worth an estimated **£94k–£281k a year**. Because the win-back rate is unknown, test it first: split the 324 customers randomly into two groups of 162, contact one group, and after 90 days compare reorder rate and sales per customer against the other group. Scale up only if the contacted group clearly outperforms. Next priorities are rebuilding new-customer acquisition (worth about £1,487 per new customer in year one) and re-engaging the 605 drifting Loyal customers before they become At Risk. Full reasoning, options and risks are in the one-page executive memo.*

