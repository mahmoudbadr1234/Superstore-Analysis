/* =====================================================================
   Superstore Analysis  |  SQL Server (T-SQL)
   File 02 - Business analysis queries
   Run each query on its own: select it, then press F5.
   Table: dbo.Superstore (9,994 order lines, 2014-2017)
   ===================================================================== */
USE SuperstoreDB;
GO

/* ---------------------------------------------------------------------
   Q0. Sanity check
   --------------------------------------------------------------------- */
SELECT COUNT(*)                    AS order_lines,
       COUNT(DISTINCT Order_ID)    AS orders,
       COUNT(DISTINCT Customer_ID) AS customers,
       COUNT(DISTINCT Product_ID)  AS products,
       MIN(Order_Date)             AS first_order,
       MAX(Order_Date)             AS last_order
FROM dbo.Superstore;

/* =====================================================================
   SECTION 1 - HEADLINE KPIs & TIME TRENDS
   ===================================================================== */

/* Q1. Headline KPIs */
SELECT ROUND(SUM(Sales), 2)                                 AS total_sales,
       ROUND(SUM(Profit), 2)                                AS total_profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)           AS profit_margin_pct,
       COUNT(DISTINCT Order_ID)                             AS orders,
       COUNT(DISTINCT Customer_ID)                          AS customers,
       ROUND(SUM(Sales) / COUNT(DISTINCT Order_ID), 2)      AS avg_order_value,
       SUM(Quantity)                                        AS units_sold
FROM dbo.Superstore;

/* Q2. Yearly performance with year-over-year growth (LAG) */
WITH yearly AS (
    SELECT YEAR(Order_Date) AS yr,
           SUM(Sales)  AS sales,
           SUM(Profit) AS profit,
           COUNT(DISTINCT Order_ID) AS orders
    FROM dbo.Superstore
    GROUP BY YEAR(Order_Date)
)
SELECT yr,
       ROUND(sales, 0)                                   AS sales,
       ROUND(profit, 0)                                  AS profit,
       orders,
       ROUND(profit * 100.0 / sales, 1)                  AS margin_pct,
       ROUND((sales  - LAG(sales)  OVER (ORDER BY yr)) * 100.0 / NULLIF(LAG(sales)  OVER (ORDER BY yr), 0), 1) AS sales_yoy_pct,
       ROUND((profit - LAG(profit) OVER (ORDER BY yr)) * 100.0 / NULLIF(LAG(profit) OVER (ORDER BY yr), 0), 1) AS profit_yoy_pct
FROM yearly
ORDER BY yr;

/* Q3. Monthly trend: month-over-month growth, 3-month moving average, running total */
WITH monthly AS (
    SELECT DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS month_start,
           SUM(Sales)  AS sales,
           SUM(Profit) AS profit
    FROM dbo.Superstore
    GROUP BY DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1)
)
SELECT month_start,
       ROUND(sales, 0)  AS sales,
       ROUND(profit, 0) AS profit,
       ROUND((sales - LAG(sales) OVER (ORDER BY month_start)) * 100.0 / NULLIF(LAG(sales) OVER (ORDER BY month_start), 0), 1) AS sales_mom_pct,
       ROUND(AVG(sales) OVER (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS sales_3m_moving_avg,
       ROUND(SUM(sales) OVER (ORDER BY month_start ROWS UNBOUNDED PRECEDING), 0)                  AS cumulative_sales
FROM monthly
ORDER BY month_start;

/* Q4. Seasonality: which calendar months sell the most? */
SELECT MONTH(Order_Date)            AS month_no,
       DATENAME(MONTH, MIN(Order_Date)) AS month_name,
       ROUND(SUM(Sales), 0)         AS total_sales,
       ROUND(SUM(Profit), 0)        AS total_profit,
       RANK() OVER (ORDER BY SUM(Sales) DESC) AS sales_rank
FROM dbo.Superstore
GROUP BY MONTH(Order_Date)
ORDER BY month_no;

/* =====================================================================
   SECTION 2 - PRODUCTS
   ===================================================================== */

/* Q5. Category performance */
SELECT Category,
       ROUND(SUM(Sales), 0)                        AS sales,
       ROUND(SUM(Profit), 0)                       AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)  AS margin_pct,
       ROUND(SUM(Sales) * 100.0 / SUM(SUM(Sales)) OVER (), 1) AS share_of_sales_pct
FROM dbo.Superstore
GROUP BY Category
ORDER BY profit DESC;

/* Q6. Sub-category profitability, ranked inside each category */
SELECT Category,
       Sub_Category,
       ROUND(SUM(Sales), 0)                        AS sales,
       ROUND(SUM(Profit), 0)                       AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)  AS margin_pct,
       RANK() OVER (PARTITION BY Category ORDER BY SUM(Profit) DESC) AS rank_in_category
FROM dbo.Superstore
GROUP BY Category, Sub_Category
ORDER BY Category, rank_in_category;

/* Q7. Top 10 products by profit (grouped by Product_ID: some IDs have several names) */
SELECT TOP 10
       Product_ID,
       MIN(Product_Name)     AS product_name,
       ROUND(SUM(Sales), 0)  AS sales,
       ROUND(SUM(Profit), 0) AS profit,
       SUM(Quantity)         AS units
FROM dbo.Superstore
GROUP BY Product_ID
ORDER BY SUM(Profit) DESC;

/* Q8. Bottom 10 products by profit (biggest money losers) */
SELECT TOP 10
       Product_ID,
       MIN(Product_Name)     AS product_name,
       ROUND(SUM(Sales), 0)  AS sales,
       ROUND(SUM(Profit), 0) AS profit,
       ROUND(AVG(CAST(Discount AS FLOAT)) * 100, 0) AS avg_discount_pct
FROM dbo.Superstore
GROUP BY Product_ID
ORDER BY SUM(Profit) ASC;

/* Q9. High-revenue products that still lose money (sales > 5,000 but profit < 0) */
SELECT Product_ID,
       MIN(Product_Name)     AS product_name,
       ROUND(SUM(Sales), 0)  AS sales,
       ROUND(SUM(Profit), 0) AS profit
FROM dbo.Superstore
GROUP BY Product_ID
HAVING SUM(Sales) > 5000 AND SUM(Profit) < 0
ORDER BY SUM(Profit);

/* =====================================================================
   SECTION 3 - GEOGRAPHY
   ===================================================================== */

/* Q10. Region performance */
SELECT Region,
       ROUND(SUM(Sales), 0)                        AS sales,
       ROUND(SUM(Profit), 0)                       AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)  AS margin_pct,
       ROUND(SUM(Sales) * 100.0 / SUM(SUM(Sales)) OVER (), 1) AS share_of_sales_pct
FROM dbo.Superstore
GROUP BY Region
ORDER BY profit DESC;

/* Q11. Region x Category profit matrix (conditional aggregation / manual pivot) */
SELECT Region,
       ROUND(SUM(CASE WHEN Category = 'Furniture'       THEN Profit END), 0) AS furniture_profit,
       ROUND(SUM(CASE WHEN Category = 'Office Supplies' THEN Profit END), 0) AS office_supplies_profit,
       ROUND(SUM(CASE WHEN Category = 'Technology'      THEN Profit END), 0) AS technology_profit,
       ROUND(SUM(Profit), 0)                                                 AS total_profit
FROM dbo.Superstore
GROUP BY Region
ORDER BY total_profit DESC;

/* Q12. State ranking by profit, with each state's contribution to total profit */
SELECT State,
       ROUND(SUM(Sales), 0)  AS sales,
       ROUND(SUM(Profit), 0) AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(SUM(Profit)) OVER (), 1) AS share_of_total_profit_pct,
       RANK() OVER (ORDER BY SUM(Profit) DESC)                  AS profit_rank
FROM dbo.Superstore
GROUP BY State
ORDER BY profit_rank;

/* Q13. Loss-making states */
SELECT State,
       ROUND(SUM(Sales), 0)                       AS sales,
       ROUND(SUM(Profit), 0)                      AS profit,
       ROUND(AVG(CAST(Discount AS FLOAT)) * 100, 0) AS avg_discount_pct
FROM dbo.Superstore
GROUP BY State
HAVING SUM(Profit) < 0
ORDER BY profit;

/* Q14. Top 5 cities by sales inside each region (ROW_NUMBER + PARTITION BY) */
WITH city_sales AS (
    SELECT Region, City,
           SUM(Sales)  AS sales,
           SUM(Profit) AS profit,
           ROW_NUMBER() OVER (PARTITION BY Region ORDER BY SUM(Sales) DESC) AS rn
    FROM dbo.Superstore
    GROUP BY Region, City
)
SELECT Region, City, ROUND(sales, 0) AS sales, ROUND(profit, 0) AS profit, rn AS rank_in_region
FROM city_sales
WHERE rn <= 5
ORDER BY Region, rn;

/* =====================================================================
   SECTION 4 - DISCOUNTS (the biggest profit driver in this dataset)
   ===================================================================== */

/* Q15. Profit by discount band */
WITH banded AS (
    SELECT Sales, Profit,
           CASE WHEN Discount = 0    THEN 1
                WHEN Discount <= 0.1 THEN 2
                WHEN Discount <= 0.2 THEN 3
                WHEN Discount <= 0.4 THEN 4
                WHEN Discount <= 0.6 THEN 5
                ELSE 6 END AS band_no,
           CASE WHEN Discount = 0    THEN 'No discount'
                WHEN Discount <= 0.1 THEN '1-10%'
                WHEN Discount <= 0.2 THEN '11-20%'
                WHEN Discount <= 0.4 THEN '21-40%'
                WHEN Discount <= 0.6 THEN '41-60%'
                ELSE '61%+' END AS discount_band
    FROM dbo.Superstore
)
SELECT discount_band,
       COUNT(*)                                        AS order_lines,
       ROUND(SUM(Sales), 0)                            AS sales,
       ROUND(SUM(Profit), 0)                           AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)      AS margin_pct,
       ROUND(AVG(CASE WHEN Profit < 0 THEN 1.0 ELSE 0.0 END) * 100, 1) AS loss_making_lines_pct
FROM banded
GROUP BY band_no, discount_band
ORDER BY band_no;

/* Q16. What-if: cap every discount at 20%
   Assumptions: unit cost and quantities stay the same (no volume change).
   list price = Sales / (1 - Discount);  cost = Sales - Profit.
   WARNING: this is an UPPER BOUND. Deep discounts probably drive some volume,
   so real gains would be lower. Use it to size the problem, not as a forecast. */
WITH sim AS (
    SELECT CAST(Sales AS FLOAT)    AS sales,
           CAST(Profit AS FLOAT)   AS profit,
           CAST(Discount AS FLOAT) AS discount,
           CAST(Sales AS FLOAT) - CAST(Profit AS FLOAT) AS cost
    FROM dbo.Superstore
)
SELECT ROUND(SUM(profit), 0) AS actual_profit,
       ROUND(SUM(sales / (1 - discount) * (1 - CASE WHEN discount > 0.2 THEN 0.2 ELSE discount END) - cost), 0) AS profit_if_discount_capped_at_20pct,
       ROUND(SUM(sales / (1 - discount) * (1 - CASE WHEN discount > 0.2 THEN 0.2 ELSE discount END) - cost) - SUM(profit), 0) AS potential_gain
FROM sim;

/* Q17. Average discount vs margin per sub-category */
SELECT Sub_Category,
       ROUND(AVG(CAST(Discount AS FLOAT)) * 100, 1) AS avg_discount_pct,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)   AS margin_pct,
       ROUND(SUM(Profit), 0)                        AS profit
FROM dbo.Superstore
GROUP BY Sub_Category
ORDER BY avg_discount_pct DESC;

/* =====================================================================
   SECTION 5 - CUSTOMERS
   ===================================================================== */

/* Q18. Top 10 customers by profit */
SELECT TOP 10
       Customer_ID,
       MIN(Customer_Name)       AS customer_name,
       COUNT(DISTINCT Order_ID) AS orders,
       ROUND(SUM(Sales), 0)     AS sales,
       ROUND(SUM(Profit), 0)    AS profit
FROM dbo.Superstore
GROUP BY Customer_ID
ORDER BY SUM(Profit) DESC;

/* Q19. Pareto: how much of the sales come from the top 20% of customers? (NTILE) */
WITH cust AS (
    SELECT Customer_ID, SUM(Sales) AS sales
    FROM dbo.Superstore
    GROUP BY Customer_ID
),
tiled AS (
    SELECT sales, NTILE(5) OVER (ORDER BY sales DESC) AS quintile
    FROM cust
)
SELECT quintile,
       COUNT(*)                                        AS customers,
       ROUND(SUM(sales), 0)                            AS sales,
       ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (), 1) AS share_of_sales_pct
FROM tiled
GROUP BY quintile
ORDER BY quintile;

/* Q20. New vs returning customers per year
   Note: the data starts in 2014, so every 2014 customer shows up as 'new'. */
WITH cust_year AS (
    SELECT DISTINCT Customer_ID, YEAR(Order_Date) AS yr
    FROM dbo.Superstore
),
first_year AS (
    SELECT Customer_ID, MIN(yr) AS first_yr
    FROM cust_year
    GROUP BY Customer_ID
)
SELECT cy.yr,
       COUNT(*) AS active_customers,
       SUM(CASE WHEN cy.yr = f.first_yr THEN 1 ELSE 0 END) AS new_customers,
       SUM(CASE WHEN cy.yr > f.first_yr THEN 1 ELSE 0 END) AS returning_customers
FROM cust_year cy
JOIN first_year f ON f.Customer_ID = cy.Customer_ID
GROUP BY cy.yr
ORDER BY cy.yr;
GO

/* Q21. RFM customer segmentation
   Recency = days since last order (relative to the last date in the data)
   Frequency = number of orders, Monetary = total sales.  Scores 1-4 via NTILE. */
DECLARE @ref DATE = (SELECT MAX(Order_Date) FROM dbo.Superstore);

WITH rfm AS (
    SELECT Customer_ID,
           MIN(Customer_Name)                   AS customer_name,
           DATEDIFF(DAY, MAX(Order_Date), @ref) AS recency_days,
           COUNT(DISTINCT Order_ID)             AS frequency,
           SUM(Sales)                           AS monetary,
           SUM(Profit)                          AS profit
    FROM dbo.Superstore
    GROUP BY Customer_ID
),
scored AS (
    SELECT *,
           -- Customer_ID is a tie-breaker so the scores are identical on every run / engine
           NTILE(4) OVER (ORDER BY recency_days DESC, Customer_ID) AS r,   -- 4 = most recent
           NTILE(4) OVER (ORDER BY frequency, Customer_ID)         AS f,   -- 4 = most frequent
           NTILE(4) OVER (ORDER BY monetary, Customer_ID)          AS m    -- 4 = biggest spender
    FROM rfm
),
labeled AS (
    SELECT *,
           CASE WHEN r = 4 AND f >= 3 AND m >= 3 THEN 'Champions'
                WHEN r >= 3 AND f >= 3             THEN 'Loyal'
                WHEN r = 4 AND f <= 2              THEN 'New / Recent'
                WHEN r <= 2 AND f >= 3             THEN 'At Risk'
                WHEN r = 1 AND f <= 2              THEN 'Lost'
                ELSE 'Regular' END AS rfm_segment
    FROM scored
)
SELECT rfm_segment,
       COUNT(*)                 AS customers,
       ROUND(SUM(monetary), 0)  AS sales,
       ROUND(SUM(profit), 0)    AS profit,
       ROUND(AVG(CAST(recency_days AS FLOAT)), 0) AS avg_recency_days,
       ROUND(AVG(CAST(frequency AS FLOAT)), 1)    AS avg_orders
FROM labeled
GROUP BY rfm_segment
ORDER BY sales DESC;
GO

/* =====================================================================
   SECTION 6 - SEGMENTS, ORDERS & SHIPPING
   ===================================================================== */

/* Q22. Customer segment performance */
SELECT Segment,
       COUNT(DISTINCT Customer_ID)                  AS customers,
       ROUND(SUM(Sales), 0)                         AS sales,
       ROUND(SUM(Profit), 0)                        AS profit,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)   AS margin_pct,
       ROUND(SUM(Sales) / COUNT(DISTINCT Order_ID), 0) AS avg_order_value
FROM dbo.Superstore
GROUP BY Segment
ORDER BY sales DESC;

/* Q23. Shipping: delivery time and profitability per ship mode */
SELECT Ship_Mode,
       COUNT(*)                                          AS order_lines,
       ROUND(AVG(CAST(DATEDIFF(DAY, Order_Date, Ship_Date) AS FLOAT)), 2) AS avg_ship_days,
       MIN(DATEDIFF(DAY, Order_Date, Ship_Date))         AS min_days,
       MAX(DATEDIFF(DAY, Order_Date, Ship_Date))         AS max_days,
       ROUND(SUM(Profit) * 100.0 / SUM(Sales), 1)        AS margin_pct
FROM dbo.Superstore
GROUP BY Ship_Mode
ORDER BY avg_ship_days;

/* Q24. Order size: how many lines / units per order, and the biggest orders */
WITH orders AS (
    SELECT Order_ID,
           COUNT(*)      AS lines,
           SUM(Quantity) AS units,
           SUM(Sales)    AS sales,
           SUM(Profit)   AS profit
    FROM dbo.Superstore
    GROUP BY Order_ID
)
SELECT ROUND(AVG(CAST(lines AS FLOAT)), 2) AS avg_lines_per_order,
       ROUND(AVG(CAST(units AS FLOAT)), 2) AS avg_units_per_order,
       ROUND(AVG(sales), 0)                AS avg_order_value,
       SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) AS loss_making_orders,
       COUNT(*)                            AS total_orders
FROM orders;

/* Q25. Top 10 biggest orders by sales */
SELECT TOP 10 Order_ID,
       MIN(Order_Date)       AS order_date,
       MIN(Customer_Name)    AS customer_name,
       ROUND(SUM(Sales), 0)  AS sales,
       ROUND(SUM(Profit), 0) AS profit
FROM dbo.Superstore
GROUP BY Order_ID
ORDER BY SUM(Sales) DESC;
