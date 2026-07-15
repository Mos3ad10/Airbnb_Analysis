# Airbnb Warehouse And Dashboard

An Airbnb analytics project with a SQL Server warehouse export and a final Power BI Project dashboard.

## Repository Structure

```text
.
|-- Bronze layer/                    Raw city CSV files
|-- Silver layer/                    SQL Server Silver export
|-- Gold layer/
|   |-- Database/                    SQL Server DACPAC package
|   |-- SQL/                         Bronze, Silver, and Gold SQL scripts
|   |-- Star Schema/                 Exported Gold dimension and fact CSV files
|   |-- PowerBI/                     Final Power BI Project dashboard
|   |-- gold_flat.csv                Final flat Gold export
|-- scripts/                         Airbnb scraping notebook
|-- README.md
|-- requirements.txt
```

## Dashboard

The final dashboard is the Power BI Project from `D:\Bi\Airbnb.pbip`:

```text
Gold layer/PowerBI/
|-- Airbnb.pbip
|-- Airbnb.Report/
|-- Airbnb.SemanticModel/
```

Open `Gold layer/PowerBI/Airbnb.pbip` in Power BI Desktop to view or edit the dashboard.

## Warehouse Files

- `Silver layer/silver_airbnb_listings.csv`
- `Gold layer/gold_flat.csv`
- `Gold layer/Star Schema/DimLocation.csv`
- `Gold layer/Star Schema/DimRoom.csv`
- `Gold layer/Star Schema/DimHostProfile.csv`
- `Gold layer/Star Schema/FactListings.csv`
- `Gold layer/Database/DataWareHouse.dacpac`

## SQL Scripts

```text
Gold layer/SQL/Bronze_layer.sql
Gold layer/SQL/Silver_layer.sql
Gold layer/SQL/Gold_layer.sql
```
