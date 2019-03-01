--- CHECKING LOCKS SESSION 2

SELECT 
	DB_NAME(resource_database_id) as DBNAME,
	resource_type,
	request_mode,
	request_status,
	request_session_id,
	request_owner_type
FROM sys.dm_tran_locks;


-- TEMPORARY TABLES SESSION 2

-- this SELECT WILL NOT WORK

SELECT DISTINCT ModifiedDate FROM #customer1;

-- this SELECT will work
SELECT DISTINCT ModifiedDate FROM ##customer2;


-- DEADLOCKS SESSION 2
USE AdventureWorks2017;
GO

BEGIN TRAN

UPDATE [Sales].[SalesTerritory]
SET SalesYTD = 0
WHERE TerritoryID =2; 

WAITFOR DELAY '00:00:15';

UPDATE [Sales].[CreditCard]
SET ExpYear = 2026
WHERE ExpYear = 2008;

-- ROLLBACK TRAN;








