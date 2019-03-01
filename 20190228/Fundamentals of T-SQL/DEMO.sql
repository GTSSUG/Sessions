/************************* Check SQL Server version ***********************/

SELECT @@VERSION;

/*** Check data allocated in memory by database **/

SELECT DB_NAME(database_id) as DB,
file_id,
page_id,
page_type,
row_count
FROM sys.dm_os_buffer_descriptors
ORDER BY DB_NAME(database_id);



/********************** Releasing info from memory **********************/
-- This action is just for informative purposes and must not be executed on prod systems
-- unless necessary

USE [AdventureWorks2017];
GO

-- Doing a simple select:
SELECT AddressID
    , AddressLine1
    , AddressLine2
    , City
FROM Person.Address
WHERE City LIKE 'M%';


-- Check allocated memory
SELECT DB_NAME(database_id) as DB,
page_type,
SUM(row_count) as RowN
FROM sys.dm_os_buffer_descriptors
WHERE DB_NAME(database_id) = 'AdventureWorks2017'
GROUP BY database_id, page_type
ORDER BY RowN desc;

-- Clear data from memory
DBCC DROPCLEANBUFFERS;


-- If we check allocated memory again, number of rows should be lower, 
-- info can vary from systems

SELECT DB_NAME(database_id) as DB,
page_type,
SUM(row_count) as RowN
FROM sys.dm_os_buffer_descriptors
WHERE DB_NAME(database_id) = 'AdventureWorks2017'
GROUP BY database_id, page_type
ORDER BY RowN desc;


/*****************************    Checking execution plans Cache  *****************************/

-- we enable statistics Time details
SET STATISTICS TIME ON;

-- we run a simple query
-- Run it 2 or more times so plan can be stored on cache
SELECT ProductID
    , SUM(lineTotal) AS TotalbyProduct
FROM Sales.SalesOrderDetail
WHERE ProductID = 733
GROUP BY ProductID;

-- Clearing execution plan cache
DBCC FREEPROCCACHE;

-- Executing query again will have parsing and compiling time
SELECT ProductID
    , SUM(lineTotal) AS TotalbyProduct
FROM Sales.SalesOrderDetail
WHERE ProductID = 733
GROUP BY ProductID;


SET STATISTICS TIME OFF;



/********************** Working with data *********************************/


-- SARGABLE

USE AdventureWorks2017;
GO

/*
-- IF exists index delete it

DROP INDEX [IX_Address_City] ON [Person].[Address];

*/
-- Create a simple index for this example
CREATE NONCLUSTERED INDEX [IX_Address_City] ON [Person].[Address] ([City]) 
INCLUDE (
    [AddressLine1]
    , [AddressLine2]
    );

-- NON SARGABLE
SELECT AddressID
    , AddressLine1
    , AddressLine2
    , City
FROM Person.Address
WHERE left(City, 1) = 'M';

--SARGABLE
SELECT AddressID
    , AddressLine1
    , AddressLine2
    , City
FROM Person.Address
WHERE City LIKE 'M%';


/******************************  Grouping **************************************/

USE AdventureWorks2017;
GO

-- Difference between count(*) and count(<field>)
SELECT 
	COUNT(*) as SalesPersons,
	COUNT(TerritoryID) as PersonsWithTerritory
FROM [Sales].[SalesPerson];


-- Ranking functions

-- Base query
SELECT EndDate,
		count(WorkOrderID) as NumOrdersByDay,
		 SUM(OrderQty) as ItemsOrderedByDay
FROM [Production].[WorkOrder]
GROUP BY EndDate
ORDER BY EndDate;


-- With OVER to see details (total)
SELECT 
	WorkOrderID,
	EndDate,
	OrderQty,
	COUNT(WorkOrderID) OVER(PARTITION BY EndDate ORDER BY EndDate) as NumOrdersByDay,
	SUM(OrderQty) OVER(PARTITION BY EndDate ORDER BY EndDate) as ItemsOrderedByDay
FROM [Production].[WorkOrder] 
ORDER BY EndDate;

-- With OVER to see details (running cummulative)
SELECT 
	WorkOrderID,
	EndDate,
	OrderQty,
	COUNT(WorkOrderID) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as NumOrdersByDay,
	SUM(OrderQty) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as ItemsOrderedByDay
FROM [Production].[WorkOrder] 
ORDER BY EndDate;


-- Grouping sets, CUBE option to perform all possible combinations
SELECT 
	DATEPART(YEAR,EndDate) as OrderYear,
	DATEPART(MONTH,EndDate) as OrderMonth,
	COUNT(WorkOrderID) as NumOrders,
	SUM(OrderQty) as ItemsOrdered
FROM [Production].[WorkOrder] 
GROUP BY CUBE(DATEPART(YEAR,EndDate),DATEPART(MONTH,EndDate))
ORDER BY DATEPART(YEAR,EndDate),DATEPART(MONTH,EndDate);


/*********************************  Modifying data **********************************/

-- Using Merge

USE AdventureWorks2017;
GO

-- Creating a test Table using SELECT INTO
-- DROP it if exists: 
-- DROP TABLE [Sales].[Currencytest];

SELECT *
INTO [Sales].[Currencytest]
FROM [Sales].[Currency]
WHERE name like '%Dollar%';

-- Check Table info:
SELECT * FROM [Sales].[Currencytest];

-- UPDATE Modified date field to change data from original source
-- we will see the OUTPUT clause also
UPDATE [Sales].[Currencytest]
SET ModifiedDate = 'Feb 28 2019' 
OUTPUT	inserted.CurrencyCode, 
		deleted.ModifiedDate as OldDate, 
		inserted.ModifiedDate as NewDate;


-- We will insert data from original table using MERGE

MERGE INTO [Sales].[Currencytest] ct -- our test table
USING [Sales].[Currency] c --source table
ON ct.CurrencyCode = c.CurrencyCode  
WHEN MATCHED   
    THEN UPDATE SET
 ct.name = c.name,
 ct.ModifiedDate = 'Oct 31, 2019' --the update date is Halloween
WHEN NOT MATCHED 
    THEN INSERT 
 VALUES(c.CurrencyCode,c.Name, 'Dec 25 2019') --insert date is Christmas :)
WHEN NOT MATCHED BY SOURCE 
    THEN DELETE; --if you have data in the destination you want to delete it



-- Check Table info again, Updated data will have Oct 31 and inserted data Dec 25

SELECT * FROM [Sales].[Currencytest];

-- deleting all data
TRUNCATE TABLE [Sales].[Currencytest];

-- Dropping table
DROP TABLE [Sales].[Currencytest];


/*************************** ADVANCED T-SQL ********************************/


--- FUNCTIONS
USE AdventureWorks2017;
GO

-- DROP IF EXISTS:
/*
DROP FUNCTION [Test_Scalar_WorkOrder];

DROP FUNCTION [TestInlineTF];

DROP FUNCTION [TestTVF];

*/

-- Scalar function
CREATE FUNCTION [Test_Scalar_WorkOrder]
(
    @WorkOrderID int
)
RETURNS varchar(17)
AS
BEGIN
	-- Put work order id on business format
    RETURN 'WO-'+ CAST(@WorkOrderID as varchar(14))
END;

-- testing it
SELECT dbo.Test_Scalar_WorkOrder(345345);


-- INLINE TABLE FUNCTION

CREATE FUNCTION [dbo].[TestInlineTF]
(
    @pdate datetime 
)
RETURNS TABLE AS RETURN
(
	SELECT 
		WorkOrderID,
		EndDate,
		OrderQty,
		COUNT(WorkOrderID) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as NumOrdersByDay,
		SUM(OrderQty) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as ItemsOrderedByDay
	FROM [Production].[WorkOrder]
	WHERE EndDate = @pdate
);

-- Simple test
SELECT * FROM dbo.TestInlineTF('Jun 13 2011');


-- Multi-Statement Table valued function
CREATE FUNCTION [dbo].[TestTVF]
(
    @pDate datetime
    
)
RETURNS @returntable TABLE 
(
	[WorkOrderID] [int] NOT NULL,
	[EndDate] [datetime] NULL,
	[OrderQty] [int] NOT NULL,
	[NumOrdersByDay] [int] NULL,
	[ItemsOrderedByDay] [int] NULL
)
AS
BEGIN
	Declare @iDate datetime
	--validating input parameter first
	IF(@pDate>GETDATE())
	BEGIN
		SET @iDate = GETDATE()
	END
	ELSE
	BEGIN
		SET @iDate = @pDate
	END

    INSERT INTO @returntable
    SELECT 
		WorkOrderID,
		EndDate,
		OrderQty,
		COUNT(WorkOrderID) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as NumOrdersByDay,
		SUM(OrderQty) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as ItemsOrderedByDay
	FROM [Production].[WorkOrder]
	WHERE EndDate = @iDate

	RETURN 
END;

-- Simple test
SELECT * FROM dbo.TestTVF('06-13-2011');



/****** CTE using WITH **********/

WITH WO
AS
(
SELECT 
	WorkOrderID,
	EndDate,
	OrderQty,
	COUNT(WorkOrderID) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as NumOrdersByDay,
	SUM(OrderQty) OVER(PARTITION BY EndDate ORDER BY WorkOrderID) as ItemsOrderedByDay
FROM [Production].[WorkOrder] 
)
SELECT 
	CONVERT(varchar(10),EndDate,110) as FormattedDate,
	dbo.Test_Scalar_WorkOrder(WorkOrderID) as WorkOrder, --We use scalar function we created earlier
	OrderQty,
	NumOrdersByDay,
	ItemsOrderedByDay
FROM WO;


--- USING CROSS APPLY with a subquery

SELECT
	WR.ActualEndDate,
	WR.CostByDate,
	WO.WorkOrderID,
	WO.OrderQty,
	WO.ItemsOrderedByDay,
	WO.NumOrdersByDay
FROM
(SELECT 
	ActualEndDate,
	SUM(ActualCost) as CostByDate
	FROM [Production].[WorkOrderRouting]
	GROUP BY ActualEndDate ) WR
CROSS APPLY dbo.TestInlineTF(WR.ActualEndDate) WO;


/*************** TRANSACTIONS AND ERROR HANDLING **************************/

USE AdventureWorks2017;
GO

-- SIMPLE TRANSACTION AND ERROR HANDLING
DECLARE @varI int = 0; -- we will test with various values

--SET @VarI =1;

BEGIN TRAN --WE START THE TRANSACTION

BEGIN TRY
	SELECT 1/@varI;

	COMMIT TRAN; -- IF THERE IS NO ERROR

	PRINT 'Transaction has been commited!';
END TRY
BEGIN CATCH
	ROLLBACK TRAN;
	PRINT 'Transaction has been ROLLED BACK!';
END CATCH;


-- CHECKING LOCKS SESSION 1

BEGIN TRANSACTION

-- ROW LOCK
UPDATE [Sales].[Customer]
SET ModifiedDate = GETUTCDATE()
WHERE TerritoryID = 4;

-- ROLLBACK TRANSACTION;



BEGIN TRANSACTION

-- TABLE LOCK
UPDATE [Sales].[Customer]
SET ModifiedDate = GETUTCDATE()

-- ROLLBACK TRANSACTION;


--- Table variables and transactions SESSION 1

-- DROP TABLE #customer1;
-- DROP TABLE ##customer2;

SELECT ModifiedDate 
INTO #customer1
FROM [Sales].[Customer];

SELECT ModifiedDate 
INTO ##customer2
FROM [Sales].[Customer];


-- THESE 2 selects will work

SELECT DISTINCT ModifiedDate FROM #customer1;

SELECT DISTINCT ModifiedDate FROM ##customer2;

-- TABLE VARIABLE
DECLARE @customer3 TABLE
(
	ModifiedDate datetime
);

INSERT INTO @customer3
SELECT ModifiedDate 
FROM [Sales].[Customer];

SELECT DISTINCT ModifiedDate as MDTableVariable FROM @customer3; 



-- WE UPDATE THE INFO AND AUTOMATICALLY ROLLBACK THE UPDATE
-- RUN BELOW CODE including table variable declaration
BEGIN TRANSACTION

UPDATE #customer1
SET ModifiedDate = GETDATE();

UPDATE @customer3
SET ModifiedDate = GETDATE();

ROLLBACK TRANSACTION;

-- IF WE SELECT DATA AFTER ROLLBACK, TABLE VARIABLE REMAINS CHANGED
SELECT DISTINCT ModifiedDate as MDTemporaryTable FROM #customer1;

SELECT DISTINCT ModifiedDate as MDTableVariable FROM @customer3; 


--- DEADLOCKS SESSION 1
-- IN less than 15 seconds you must execute session 2
BEGIN TRAN

UPDATE [Sales].[CreditCard]
SET ExpYear = 2026
WHERE ExpYear = 2008;

WAITFOR DELAY '00:00:15';

UPDATE [Sales].[SalesTerritory]
SET SalesYTD = 0
WHERE TerritoryID =2;



-- ROLLBACK TRAN;

