/* =====================================================================
   Superstore Analysis  |  SQL Server (T-SQL)
   File 03 - Views used by Power BI (stage 4)
   Power BI connects to dbo.vw_Superstore, so all derived columns
   (year, month, ship days, margin, discount band...) live in one place.
   ===================================================================== */
USE SuperstoreDB;
GO

CREATE OR ALTER VIEW dbo.vw_Superstore
AS
SELECT
    s.Row_ID,
    s.Order_ID,
    s.Order_Date,
    s.Ship_Date,
    s.Ship_Mode,
    s.Customer_ID,
    s.Customer_Name,
    s.Segment,
    s.Country,
    s.City,
    s.State,
    s.Postal_Code,
    s.Region,
    s.Product_ID,
    s.Category,
    s.Sub_Category,
    s.Product_Name,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit,
    /* derived columns */
    YEAR(s.Order_Date)                                          AS Order_Year,
    MONTH(s.Order_Date)                                         AS Order_Month,
    DATENAME(MONTH, s.Order_Date)                               AS Order_Month_Name,
    DATEFROMPARTS(YEAR(s.Order_Date), MONTH(s.Order_Date), 1)   AS Order_Month_Start,
    'Q' + CAST(DATEPART(QUARTER, s.Order_Date) AS VARCHAR(1))   AS Order_Quarter,
    DATEDIFF(DAY, s.Order_Date, s.Ship_Date)                    AS Ship_Days,
    CASE WHEN s.Sales = 0 THEN NULL ELSE s.Profit / s.Sales END AS Profit_Margin,
    CASE WHEN s.Profit < 0 THEN 1 ELSE 0 END                    AS Is_Loss,
    CASE WHEN s.Discount = 0    THEN 'No discount'
         WHEN s.Discount <= 0.1 THEN '1-10%'
         WHEN s.Discount <= 0.2 THEN '11-20%'
         WHEN s.Discount <= 0.4 THEN '21-40%'
         WHEN s.Discount <= 0.6 THEN '41-60%'
         ELSE '61%+' END                                        AS Discount_Band,
    CASE WHEN s.Discount = 0    THEN 1
         WHEN s.Discount <= 0.1 THEN 2
         WHEN s.Discount <= 0.2 THEN 3
         WHEN s.Discount <= 0.4 THEN 4
         WHEN s.Discount <= 0.6 THEN 5
         ELSE 6 END                                             AS Discount_Band_Order
FROM dbo.Superstore AS s;
GO

/* quick test: expect 9994 rows */
SELECT COUNT(*) AS rows_in_view FROM dbo.vw_Superstore;
