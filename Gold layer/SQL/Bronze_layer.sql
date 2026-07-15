USE master;
GO

-- 1. DATABASE & SCHEMA SETUP
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DataWareHouse')
    CREATE DATABASE DataWareHouse;
GO
USE DataWareHouse;
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver') EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold') EXEC('CREATE SCHEMA gold');
GO

-- 2. BRONZE LAYER TABLES (Consolidated)
-- [Run your previously generated Bronze Create Table statements here]
-- Note: Ensure all 20 tables (Amsterdam, Athens, etc.) are created.

-- 3. BRONZE VIEW (The Unified Source)
CREATE OR ALTER VIEW bronze.vw_all_airbnb_combined AS
SELECT *, 'amsterdam_weekdays' AS source_file FROM bronze.amsterdam_weekdays UNION ALL
SELECT *, 'amsterdam_weekends' AS source_file FROM bronze.amsterdam_weekends UNION ALL
SELECT *, 'athens_weekdays' AS source_file FROM bronze.athens_weekdays UNION ALL
SELECT *, 'athens_weekends' AS source_file FROM bronze.athens_weekends UNION ALL
SELECT *, 'barcelona_weekdays' AS source_file FROM bronze.barcelona_weekdays UNION ALL
SELECT *, 'barcelona_weekends' AS source_file FROM bronze.barcelona_weekends UNION ALL
SELECT *, 'berlin_weekdays' AS source_file FROM bronze.berlin_weekdays UNION ALL
SELECT *, 'berlin_weekends' AS source_file FROM bronze.berlin_weekends UNION ALL
SELECT *, 'budapest_weekdays' AS source_file FROM bronze.budapest_weekdays UNION ALL
SELECT *, 'budapest_weekends' AS source_file FROM bronze.budapest_weekends UNION ALL
SELECT *, 'lisbon_weekdays' AS source_file FROM bronze.lisbon_weekdays UNION ALL
SELECT *, 'lisbon_weekends' AS source_file FROM bronze.lisbon_weekends UNION ALL
SELECT *, 'london_weekdays' AS source_file FROM bronze.london_weekdays UNION ALL
SELECT *, 'london_weekends' AS source_file FROM bronze.london_weekends UNION ALL
SELECT *, 'paris_weekdays' AS source_file FROM bronze.paris_weekdays UNION ALL
SELECT *, 'paris_weekends' AS source_file FROM bronze.paris_weekends UNION ALL
SELECT *, 'rome_weekdays' AS source_file FROM bronze.rome_weekdays UNION ALL
SELECT *, 'rome_weekends' AS source_file FROM bronze.rome_weekends UNION ALL
SELECT *, 'vienna_weekdays' AS source_file FROM bronze.vienna_weekdays UNION ALL
SELECT *, 'vienna_weekends' AS source_file FROM bronze.vienna_weekends;
GO



