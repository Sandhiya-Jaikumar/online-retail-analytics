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
| Cancelled amount | Value of cancelled **product** lines (negative), excluding fee reversals and same-day reversals. | `SUM(line_amount_gbp)` where `is_cancellation` |
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

- **Analysis date ("today"):** Dec 9, 2011, the last date in the data.  
- **Partial months:** Dec 2011 has only 9 days, so it's excluded from monthly trend comparisons.  
- **Missing customer IDs:** 22.6% of valid sale lines. Included in revenue, excluded from customer analysis.  
- **Cancellations:** some may reverse orders placed before Dec 2009, outside the data (assumption).  
- **Exact duplicate lines** are treated as system double-entries and removed (assumption).

**Findings:**

1. **Are we keeping the customers we win?** How many first-time customers come back, and is that getting better or worse?

> **Yes, we keep the customers we win, but we’re winning far fewer of them.** New customers are loyal: 73% buy again, about 1 in 5 buys in any given month, and many return a year later for holiday restocking. Customers who joined in 2011 return as often as those from 2010\. The real problem is acquisition: the business won roughly half as many new customers in 2011, and its oldest customers are spending about 21% less per month. Revenue is being held up by customers won before 2011 (82% of 2011 known-customer sales).


2. **Which customers drive our revenue, and which valuable ones are slipping away?** Which segments hold the most revenue, and which high-value customers have stopped buying?

> **Champions (24% of customers) drive 69% of known-customer sales and grew 14% last year. Revenue is highly concentrated: the top 1% of customers bring in 31%, and the top 20% bring in 77%. The valuable customers slipping away are the At Risk segment: 710 customers who used to order about 5–6 times but haven’t bought in about a year. The high-value ones among them spent £935k the year before and only £184k in the last 12 months, a loss of about £751k a year.

