# Airbnb Warehouse and Dashboard

An end-to-end Airbnb analytics project that organizes raw European city listing data into a warehouse-style Bronze/Silver/Gold workflow and dashboard-ready Power BI assets.

## Project Goals

- Store raw Airbnb city CSV files in a reproducible Bronze layer.
- Transform raw listing fields into cleaned Silver analytics data.
- Model the Gold layer with SQL Server dimensions and fact tables.
- Build a Power BI dashboard for market overview, city performance, pricing, and host/listing analysis.

## Repository Structure

```text
.
|-- Bronze layer/                    Raw city CSV files
|-- Silver layer/                    Cleaned/intermediate layer placeholder
|-- Silver layer (scraped)/          Scraped/enriched layer placeholder
|-- Gold layer/
|   |-- SQL/                         Bronze, Silver, and Gold SQL scripts
|   |-- PowerBI/                     PBIX, PBIP zip, and dashboard screenshots
|-- scripts/                         Airbnb scraping notebook
|-- README.md
|-- requirements.txt
|-- .gitignore
|-- .gitattributes
```

## Data

The Bronze layer contains 20 raw CSV files for 10 European cities:

- Amsterdam
- Athens
- Barcelona
- Berlin
- Budapest
- Lisbon
- London
- Paris
- Rome
- Vienna

Each city has weekday and weekend source files.

## SQL Warehouse

The SQL scripts are in `Gold layer/SQL`:

- `Bronze_layer.sql`
- `Silver_layer.sql`
- `Gold_layer.sql`

The scripts create a SQL Server database named `DataWareHouse` with `bronze`, `silver`, and `gold` schemas. The Gold layer includes dimension and fact tables for dashboard reporting.

The SQL Server database package is included here:

- `Gold layer/Database/DataWareHouse.dacpac`

Use the DACPAC to publish or restore the warehouse schema in SQL Server tooling such as SQL Server Management Studio or SqlPackage.

The project also includes the final flat Gold export:

- `Gold layer/gold_flat.csv`

This file is the combined dashboard-ready dataset with listing, city, room, host, price, rating, distance, and coordinate fields.

## Power BI

Power BI assets are in `Gold layer/PowerBI`:

- `Airbnb-GPT.pbix`
- `Airbnb-GPT-PBIP.zip`
- Dashboard preview screenshots

## Quick Start

Create a Python environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Open the notebook:

```text
scripts/7-Scrape_Airbnb.ipynb
```

Run the SQL scripts in SQL Server Management Studio in this order:

```text
1. Gold layer/SQL/Bronze_layer.sql
2. Gold layer/SQL/Silver_layer.sql
3. Gold layer/SQL/Gold_layer.sql
```

Then open:

```text
Gold layer/PowerBI/Airbnb-GPT.pbix
```

## Upload To GitHub

From this folder:

```powershell
git init
git branch -M main
git add .
git commit -m "Initial Airbnb warehouse and dashboard project"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
git push -u origin main
```

## Notes

This project is for analytics and learning. Before publishing, confirm that you have the right to share the dataset and dashboard files.
