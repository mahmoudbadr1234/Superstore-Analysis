/* =====================================================================
   Superstore Analysis  |  SQL Server
   File 01 - Create table, load data, fix dates, add key & indexes
   NOTE: this file is for reproducibility. If dbo.Superstore already
   exists and is loaded, DO NOT re-run it (it drops the table).
   ===================================================================== */

IF DB_ID('SuperstoreDB') IS NULL CREATE DATABASE SuperstoreDB;
GO
USE SuperstoreDB;
GO

/* 1) Staging-style table: dates arrive as text (m/d/yyyy) and are converted below */
DROP TABLE IF EXISTS dbo.Superstore;
CREATE TABLE dbo.Superstore (
    Row_ID        INT           NOT NULL,
    Order_ID      NVARCHAR(50),
    Order_Date    NVARCHAR(50),
    Ship_Date     NVARCHAR(50),
    Ship_Mode     NVARCHAR(50),
    Customer_ID   NVARCHAR(50),
    Customer_Name NVARCHAR(100),
    Segment       NVARCHAR(50),
    Country       NVARCHAR(50),
    City          NVARCHAR(100),
    State         NVARCHAR(100),
    Postal_Code   NVARCHAR(20),
    Region        NVARCHAR(50),
    Product_ID    NVARCHAR(50),
    Category      NVARCHAR(50),
    Sub_Category  NVARCHAR(50),
    Product_Name  NVARCHAR(255),
    Sales         DECIMAL(18,4),
    Quantity      INT,
    Discount      DECIMAL(5,2),
    Profit        DECIMAL(18,4)
);
GO

/* 2) Load the UTF-8 CSV (change the path to where the file is on YOUR machine).
      The original Kaggle file is Windows-1252; use the UTF-8 copy with CODEPAGE 65001. */
BULK INSERT dbo.Superstore
FROM 'F:\projects\Superstore-Analysis\superstore\Superstore_utf8.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', FIELDQUOTE = '"');
GO

/* 3) Convert the text dates to real DATE columns */
ALTER TABLE dbo.Superstore ADD Order_Date_D DATE, Ship_Date_D DATE;
GO
UPDATE dbo.Superstore
SET Order_Date_D = TRY_CONVERT(DATE, Order_Date, 101),
    Ship_Date_D  = TRY_CONVERT(DATE, Ship_Date, 101);
GO
-- must be 0
SELECT COUNT(*) AS bad_dates FROM dbo.Superstore WHERE Order_Date_D IS NULL OR Ship_Date_D IS NULL;
GO
ALTER TABLE dbo.Superstore DROP COLUMN Order_Date, Ship_Date;
EXEC sp_rename 'dbo.Superstore.Order_Date_D', 'Order_Date', 'COLUMN';
EXEC sp_rename 'dbo.Superstore.Ship_Date_D',  'Ship_Date',  'COLUMN';
GO

/* 4) Primary key + helpful indexes */
ALTER TABLE dbo.Superstore ADD CONSTRAINT PK_Superstore PRIMARY KEY (Row_ID);
CREATE INDEX IX_Superstore_OrderDate  ON dbo.Superstore (Order_Date);
CREATE INDEX IX_Superstore_Customer   ON dbo.Superstore (Customer_ID);
CREATE INDEX IX_Superstore_Product    ON dbo.Superstore (Product_ID);
GO

/* 5) Final check: expect 9994 rows, 0 NULL profit */
SELECT COUNT(*) AS total_rows,
       SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS null_profit,
       MIN(Order_Date) AS first_order, MAX(Order_Date) AS last_order
FROM dbo.Superstore;
