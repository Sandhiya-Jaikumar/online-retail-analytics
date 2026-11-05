# Recommendation: Win back high-value At Risk customers next quarter

**To:** Head of Sales · **From:** Sandhiya Jaikumar, Data Analyst · **Data as of:** Dec 9, 2011 (UCI Online Retail II, all amounts in GBP)

## Bottom line
The customers we win are loyal, but we are winning far fewer of them, and 324 high-value customers who used to spend £935k a year have gone quiet. A targeted win-back campaign is our fastest, lowest-cost way to grow: winning back 10–30% of their former spend is worth **£94k–£281k a year**. We should run it as a controlled test first.

## What we found
- **Retention is stable; acquisition is not.** 73% of new customers buy again, and customers who joined in 2011 return as often as 2010 joiners (26.9% vs 26.5% at month 3). But new customers fell 49–66% in 2011 versus the same months of 2010.
- **Revenue is highly concentrated.** Champions (24% of customers) bring in 69% of known-customer sales and grew 14% last year. The top 1% of customers bring in 31%.
- **Valuable customers are slipping away.** 324 high-value At Risk customers went from £935k to £184k in yearly sales (−£751k).
- **About 13% of revenue is invisible.** Those sales have no customer ID, so the buyers can't be tracked or won back.

## Options considered

| Option | Estimated value | Cost and speed | Verdict |
|---|---|---|---|
| A. Win back 324 high-value At Risk customers | £94k–£281k a year | Low cost, known contacts, results in one quarter | **Recommended** |
| B. Rebuild new-customer acquisition | ~£1,487 per new customer in year one (upper estimate) | Higher marketing cost, slower | Next priority |
| C. Protect Champions | Safeguards £5.9M a year | Ongoing account management | Continue |
| D. Capture a customer ID on every order | Makes ~13% of revenue trackable | Low cost | Quick win |

## Estimated impact of Option A (yearly sales; win-back rates are assumptions)

| Low: 10% of former spend | Base: 20% | High: 30% |
|---|---|---|
| £93,538 | £187,077 | £280,615 |

## How we'll know it worked
Randomly split the 324 customers into two groups of 162. Contact one group and leave the other as a control. After 90 days, compare reorder rate and sales per customer between the groups, and scale up only if the contacted group clearly outperforms.

## Risks and assumptions
Win-back rates are assumptions until the test measures them. Figures are sales, not profit (product costs aren't in the data). Some At Risk customers may have closed or switched suppliers permanently. Customer analysis excludes the ~13% of sales with no customer ID.

## Next steps
1. Sales pulls the list of 324 high-value At Risk customers (from the `customer_rfm` table).
2. Launch the test in the first two weeks of the quarter.
3. Review results at 90 days; scale to all At Risk customers if successful.
4. Start requiring a customer ID at checkout.
