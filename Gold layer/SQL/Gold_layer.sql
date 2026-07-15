USE DataWareHouse;
GO

-- ============================================================================
-- 1. GOLD SCHEMA INITIALIZATION
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold') 
    EXEC('CREATE SCHEMA gold');
GO

-- ============================================================================
-- 2. GOLD LAYER: CLEANUP (Drop in reverse dependency order)
-- ============================================================================
IF OBJECT_ID('gold.FactListings', 'U') IS NOT NULL DROP TABLE gold.FactListings;
IF OBJECT_ID('gold.DimLocation', 'U') IS NOT NULL DROP TABLE gold.DimLocation;
IF OBJECT_ID('gold.DimRoom', 'U') IS NOT NULL DROP TABLE gold.DimRoom;
IF OBJECT_ID('gold.DimHostProfile', 'U') IS NOT NULL DROP TABLE gold.DimHostProfile;
GO

-- ============================================================================
-- 3. GOLD LAYER: DIMENSION TABLES (Creation & Population)
-- ============================================================================
CREATE TABLE gold.DimLocation ( 
    LocationKey INT IDENTITY(1,1) PRIMARY KEY, 
    CityName VARCHAR(50), 
    TimePeriod VARCHAR(50) 
);
GO
INSERT INTO gold.DimLocation (CityName, TimePeriod) 
SELECT DISTINCT CityName, TimePeriod FROM silver.airbnb_listings;
GO

CREATE TABLE gold.DimRoom ( 
    RoomKey INT IDENTITY(1,1) PRIMARY KEY, 
    RoomType VARCHAR(50), 
    IsShared BIT, 
    IsPrivate BIT 
);
GO
INSERT INTO gold.DimRoom (RoomType, IsShared, IsPrivate) 
SELECT DISTINCT RoomType, IsRoomShared, IsRoomPrivate FROM silver.airbnb_listings;
GO

CREATE TABLE gold.DimHostProfile ( 
    HostProfileKey INT IDENTITY(1,1) PRIMARY KEY, 
    IsSuperhost BIT, 
    IsMultiListing BIT, 
    IsBusiness BIT 
);
GO
INSERT INTO gold.DimHostProfile (IsSuperhost, IsMultiListing, IsBusiness) 
SELECT DISTINCT IsSuperhost, IsMultiListing, IsBusiness FROM silver.airbnb_listings;
GO

-- ============================================================================
-- 4. GOLD LAYER: FACT TABLE CREATION
-- ============================================================================
CREATE TABLE gold.FactListings (
    ListingSK VARCHAR(64) PRIMARY KEY, 
    LocationKey INT, 
    RoomKey INT, 
    HostProfileKey INT, 
    IsMissingCriticalData BIT, 
    PriceEUR DECIMAL(10,2), 
    PriceEUR_Normalized FLOAT, 
    PersonCapacity INT, 
    Bedrooms INT,
    CleanlinessRating INT, 
    GuestSatisfactionScore INT, 
    DistanceToCityCenterKM FLOAT,
    DistanceToMetroKM FLOAT, 
    AttractionIndexNorm FLOAT, 
    RestaurantIndexNorm FLOAT,
    Latitude FLOAT, 
    Longitude FLOAT
);
GO

-- ============================================================================
-- 5. GOLD LAYER: FACT TABLE POPULATION
-- ============================================================================
INSERT INTO gold.FactListings (
    ListingSK, LocationKey, RoomKey, HostProfileKey, IsMissingCriticalData, 
    PriceEUR, PriceEUR_Normalized, PersonCapacity, Bedrooms, CleanlinessRating, 
    GuestSatisfactionScore, DistanceToCityCenterKM, DistanceToMetroKM, 
    AttractionIndexNorm, RestaurantIndexNorm, Latitude, Longitude
)
SELECT 
    s.ListingSK, 
    loc.LocationKey, 
    r.RoomKey, 
    h.HostProfileKey, 
    s.IsMissingCriticalData, 
    s.PriceEUR, 
    s.PriceEUR_Normalized,
    s.PersonCapacity, 
    s.Bedrooms, 
    s.CleanlinessRating, 
    s.GuestSatisfactionScore, 
    s.DistanceToCityCenterKM, 
    s.DistanceToMetroKM, 
    s.AttractionIndexNorm, 
    s.RestaurantIndexNorm, 
    s.Latitude, 
    s.Longitude
FROM silver.airbnb_listings s
LEFT JOIN gold.DimLocation loc ON loc.CityName = s.CityName AND loc.TimePeriod = s.TimePeriod
LEFT JOIN gold.DimRoom r ON r.RoomType = s.RoomType AND r.IsShared = s.IsRoomShared AND r.IsPrivate = s.IsRoomPrivate
LEFT JOIN gold.DimHostProfile h ON h.IsSuperhost = s.IsSuperhost AND h.IsMultiListing = s.IsMultiListing AND h.IsBusiness = s.IsBusiness;
GO

-- ============================================================================
-- 6. GOLD LAYER: CONSTRAINTS & INDEXES (PERFORMANCE TUNING)
-- ============================================================================
-- Add Foreign Keys to enforce Referential Integrity
ALTER TABLE gold.FactListings ADD CONSTRAINT FK_Fact_Location FOREIGN KEY (LocationKey) REFERENCES gold.DimLocation (LocationKey);
ALTER TABLE gold.FactListings ADD CONSTRAINT FK_Fact_Room FOREIGN KEY (RoomKey) REFERENCES gold.DimRoom (RoomKey);
ALTER TABLE gold.FactListings ADD CONSTRAINT FK_Fact_Host FOREIGN KEY (HostProfileKey) REFERENCES gold.DimHostProfile (HostProfileKey);
GO

-- Create B-Tree Indexes for fast dimension lookups and JOIN operations
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DimLocation_CityName' AND object_id = OBJECT_ID('gold.DimLocation'))
    CREATE NONCLUSTERED INDEX IX_DimLocation_CityName ON gold.DimLocation(CityName);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactListings_LocationKey' AND object_id = OBJECT_ID('gold.FactListings'))
    CREATE NONCLUSTERED INDEX IX_FactListings_LocationKey ON gold.FactListings(LocationKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactListings_RoomKey' AND object_id = OBJECT_ID('gold.FactListings'))
    CREATE NONCLUSTERED INDEX IX_FactListings_RoomKey ON gold.FactListings(RoomKey);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_FactListings_HostProfileKey' AND object_id = OBJECT_ID('gold.FactListings'))
    CREATE NONCLUSTERED INDEX IX_FactListings_HostProfileKey ON gold.FactListings(HostProfileKey);
GO

-- Create Columnstore Index for massive analytical aggregation performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'NCCI_FactListings_Metrics' AND object_id = OBJECT_ID('gold.FactListings'))
    CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactListings_Metrics 
    ON gold.FactListings (PriceEUR, PriceEUR_Normalized, PersonCapacity, CleanlinessRating, GuestSatisfactionScore, DistanceToCityCenterKM);
GO

PRINT 'Gold Layer Architecture, Data Load, and Indexing Completed Successfully.';
GO



-- 1. Verify Pipeline Row Counts
SELECT 
    'Row Count Audit' AS TestType,
    (SELECT COUNT(*) FROM silver.airbnb_listings) AS Silver_TotalRows,
    (SELECT COUNT(*) FROM gold.FactListings) AS Gold_TotalRows,
    CASE 
        WHEN (SELECT COUNT(*) FROM silver.airbnb_listings) = (SELECT COUNT(*) FROM gold.FactListings) 
        THEN 'PASSED: Perfect Match' 
        ELSE 'FAILED: Mismatch Detected' 
    END AS StatusCheck;



    -- 2. Verify there are no "Orphaned" facts missing their dimensions
SELECT 
    'Orphan Audit' AS TestType,
    SUM(CASE WHEN dLoc.LocationKey IS NULL THEN 1 ELSE 0 END) AS Missing_Locations,
    SUM(CASE WHEN dRoom.RoomKey IS NULL THEN 1 ELSE 0 END) AS Missing_Rooms,
    SUM(CASE WHEN dHost.HostProfileKey IS NULL THEN 1 ELSE 0 END) AS Missing_Hosts
FROM gold.FactListings f
LEFT JOIN gold.DimLocation dLoc ON f.LocationKey = dLoc.LocationKey
LEFT JOIN gold.DimRoom dRoom ON f.RoomKey = dRoom.RoomKey
LEFT JOIN gold.DimHostProfile dHost ON f.HostProfileKey = dHost.HostProfileKey;






-- 3. The Analytical Performance Test
SELECT TOP 10
    dLoc.CityName,
    dRoom.RoomType,
    COUNT(f.ListingSK) AS TotalListings,
    ROUND(AVG(f.PriceEUR), 2) AS AvgRawPriceEUR,
    ROUND(AVG(f.PriceEUR_Normalized), 4) AS AvgNormalizedPrice,
    ROUND(AVG(CAST(f.GuestSatisfactionScore AS FLOAT)), 1) AS AvgSatisfaction
FROM gold.FactListings f
JOIN gold.DimLocation dLoc ON f.LocationKey = dLoc.LocationKey
JOIN gold.DimRoom dRoom ON f.RoomKey = dRoom.RoomKey
GROUP BY dLoc.CityName, dRoom.RoomType
ORDER BY TotalListings DESC;