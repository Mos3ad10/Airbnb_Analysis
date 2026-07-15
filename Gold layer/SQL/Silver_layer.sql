USE master;
GO

-- ============================================================================
-- 1. DATABASE & SCHEMA INITIALIZATION
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'DataWareHouse')
    CREATE DATABASE DataWareHouse;
GO

USE DataWareHouse;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver') EXEC('CREATE SCHEMA silver');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold') EXEC('CREATE SCHEMA gold');
GO

-- ============================================================================
-- 2. BRONZE LAYER: UNIFIED VIEW
-- (Assumes the 20 raw Python-ingested tables already exist in 'bronze')
-- ============================================================================
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

-- ============================================================================
-- 3. SILVER LAYER: TARGET TABLE (With Normalization Column)
-- ============================================================================
IF OBJECT_ID('silver.airbnb_listings', 'U') IS NOT NULL DROP TABLE silver.airbnb_listings;
CREATE TABLE silver.airbnb_listings (
    ListingSK VARCHAR(64) PRIMARY KEY,
    CityName VARCHAR(50),
    TimePeriod VARCHAR(50),
    RoomType VARCHAR(50),
    IsRoomShared BIT,
    IsRoomPrivate BIT,
    IsSuperhost BIT,
    IsMultiListing BIT,
    IsBusiness BIT,
    PriceEUR DECIMAL(10,2),
    PriceEUR_Normalized FLOAT, 
    PersonCapacity INT,
    Bedrooms INT,
    CleanlinessRating INT,
    GuestSatisfactionScore INT,
    DistanceToCityCenterKM FLOAT,
    DistanceToMetroKM FLOAT,
    AttractionIndex FLOAT,
    RestaurantIndex FLOAT,
    AttractionIndexNorm FLOAT,
    RestaurantIndexNorm FLOAT,
    Longitude FLOAT,
    Latitude FLOAT,
    IsMissingCriticalData BIT,
    LoadTimestamp DATETIME
);
GO

-- ============================================================================
-- 4. SILVER LAYER: TRANSFORMATION PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE silver.usp_LoadAirBnbSilverLayer
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SourceCount INT;
    SELECT @SourceCount = COUNT(*) FROM bronze.vw_all_airbnb_combined;
    
    IF @SourceCount = 0
    BEGIN
        RAISERROR('Source view is empty. Aborting.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        
        TRUNCATE TABLE silver.airbnb_listings;

        WITH hashed_data AS (
            SELECT *, 
            CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 
                CONCAT_WS('||', 
                    COALESCE(CAST(lat AS VARCHAR(50)), 'UNKNOWN_LAT'), 
                    COALESCE(CAST(lng AS VARCHAR(50)), 'UNKNOWN_LNG'), 
                    COALESCE(room_type, 'UNKNOWN_ROOM'), 
                    COALESCE(CAST(person_capacity AS VARCHAR(10)), '0'), 
                    COALESCE(CAST(bedrooms AS VARCHAR(10)), '0'), 
                    source_file
                )
            ), 2) AS listing_sk
            FROM bronze.vw_all_airbnb_combined
        ),
        deduplicated_data AS (
            SELECT *, ROW_NUMBER() OVER(PARTITION BY listing_sk ORDER BY source_file DESC) as duplicate_row_num
            FROM hashed_data
        )
        INSERT INTO silver.airbnb_listings (
            ListingSK, CityName, TimePeriod, RoomType, IsRoomShared, IsRoomPrivate, 
            IsSuperhost, IsMultiListing, IsBusiness, PriceEUR, PriceEUR_Normalized, 
            PersonCapacity, Bedrooms, CleanlinessRating, GuestSatisfactionScore, 
            DistanceToCityCenterKM, DistanceToMetroKM, AttractionIndex, RestaurantIndex, 
            AttractionIndexNorm, RestaurantIndexNorm, Longitude, Latitude, 
            IsMissingCriticalData, LoadTimestamp
        )
        SELECT 
            listing_sk,
            CAST(SUBSTRING(source_file, 1, CHARINDEX('_', source_file) - 1) AS VARCHAR(50)),
            CAST(SUBSTRING(source_file, CHARINDEX('_', source_file) + 1, LEN(source_file)) AS VARCHAR(50)),
            CAST(TRIM(room_type) AS VARCHAR(50)),
            CAST(CASE WHEN room_shared LIKE 'T%' OR room_shared = '1' THEN 1 ELSE 0 END AS BIT),
            CAST(COALESCE(room_private, 0) AS BIT),
            CAST(COALESCE(host_is_superhost, 0) AS BIT),
            CAST(COALESCE(multi, 0) AS BIT),
            CAST(COALESCE(biz, 0) AS BIT),
            CAST(realSum AS DECIMAL(10,2)),
            
            -- MIN-MAX SCALING FOR PRICE
            CAST(
                (realSum - MIN(realSum) OVER()) 
                / NULLIF((MAX(realSum) OVER() - MIN(realSum) OVER()), 0) 
            AS FLOAT),
            
            CAST(ROUND(person_capacity, 0) AS INT),
            CAST(COALESCE(bedrooms, 0) AS INT),
            CAST(COALESCE(cleanliness_rating, 0) AS INT),
            CAST(COALESCE(guest_satisfaction_overall, 0) AS INT),
            CAST(dist AS FLOAT),
            CAST(metro_dist AS FLOAT),
            CAST(attr_index AS FLOAT),
            CAST(rest_index AS FLOAT),
            CAST(attr_index_norm AS FLOAT), 
            CAST(rest_index_norm AS FLOAT), 
            CAST(lng AS FLOAT),
            CAST(lat AS FLOAT),
            CAST(CASE WHEN lat IS NULL OR lng IS NULL OR realSum IS NULL THEN 1 ELSE 0 END AS BIT),
            GETDATE()
        FROM deduplicated_data
        WHERE duplicate_row_num = 1;

        COMMIT TRANSACTION;
        PRINT 'Silver Layer successfully updated with ' + CAST(@SourceCount AS VARCHAR(10)) + ' records processed.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error occurred: ' + ERROR_MESSAGE();
    END CATCH
END
GO




EXEC silver.usp_LoadAirBnbSilverLayer;





-- Compare Bronze vs Silver counts
SELECT 
    (SELECT COUNT(*) FROM bronze.vw_all_airbnb_combined) AS BronzeCount,
    (SELECT COUNT(*) FROM silver.airbnb_listings) AS SilverCount;





    -- Check how many rows were flagged as "Missing Critical Data"
SELECT IsMissingCriticalData, COUNT(*) AS TotalCount
FROM silver.airbnb_listings
GROUP BY IsMissingCriticalData;




-- Check for any weird price or capacity values
SELECT TOP 5 
    CityName, 
    PriceEUR, 
    PersonCapacity
FROM silver.airbnb_listings
WHERE PriceEUR <= 0 OR PersonCapacity <= 0
ORDER BY PriceEUR ASC;




-- If this returns 0, your deduplication worked perfectly
SELECT ListingSK, COUNT(*)
FROM silver.airbnb_listings
GROUP BY ListingSK
HAVING COUNT(*) > 1;




SELECT 
    'silver.airbnb_listings' AS TableName,
    SUM(CASE WHEN ListingSK IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Pct_ListingSK_Null,
    SUM(CASE WHEN CityName IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Pct_CityName_Null,
    SUM(CASE WHEN PriceEUR IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Pct_Price_Null,
    SUM(CASE WHEN GuestSatisfactionScore IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Pct_Satisfaction_Null,
    SUM(CASE WHEN Bedrooms IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Pct_Bedrooms_Null
FROM silver.airbnb_listings;







SELECT 
    ListingSK, 
    COUNT(*) AS Occurrences
FROM silver.airbnb_listings
GROUP BY ListingSK
HAVING COUNT(*) > 1;



SELECT 
    Latitude, 
    Longitude, 
    RoomType, 
    PersonCapacity, 
    COUNT(*) AS DuplicateCount
FROM silver.airbnb_listings
GROUP BY Latitude, Longitude, RoomType, PersonCapacity
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC;