# NYC Taxi Trip Analysis

> **Databricks · PySpark · SQL · Interactive Dashboard**

[![Platform](https://img.shields.io/badge/Platform-Databricks-FF3621?style=flat-square&logo=databricks)](https://dbc-a3d6af82-c511.cloud.databricks.com/dashboardsv3/01f0d68accda1c859b7de3d26bd6d29e/published?o=4075981409173999)
[![Language](https://img.shields.io/badge/Language-PySpark%20%7C%20SQL-E25A1C?style=flat-square&logo=apachespark)](https://spark.apache.org/)
[![Dataset](https://img.shields.io/badge/Records-20.69k%20Trips-blue?style=flat-square)]()

---

## Project Overview

Built an end-to-end data analytics project on **Databricks** using **PySpark** and **SQL** to analyze New York City taxi trip data. The project processes **20,690 trip records**, uncovers demand patterns, evaluates fare trends, and tracks route-level revenue through an interactive published dashboard.

🔗 **Live Dashboard:** [View on Databricks](https://dbc-a3d6af82-c511.cloud.databricks.com/dashboardsv3/01f0d68accda1c859b7de3d26bd6d29e/published?o=4075981409173999)

---

## Dashboard

![NYC Taxi Trip Analysis Dashboard](./images/NYC%20Taxi%20Trip%20Analysis%20-%20Dashboard%20.png)

---

## Dashboard Components

### KPI — Total Trips
- Headline metric showing **20.69k total trips** across the dataset
- Provides immediate context for all downstream analysis

### Daily Fare Trends by Day of Week
- **Scatter plot** mapping trip distance (miles) against fare amount (USD)
- Color-coded by day of week (Friday, Monday, Sunday, Thursday, Tuesday, Wednesday)
- Reveals fare-distance correlation and day-of-week pricing patterns
- Highlights outliers — short-distance high-fare and long-distance low-fare trips

### Route Revenue Attribution
- **Paginated table** (135 pages) listing each route by pickup–dropoff zone pair
- Columns: Route, Number of Trips, Total Revenue
- Enables identification of highest-revenue corridors (e.g., routes generating $105+ per trip)
- Supports operational decisions around fleet allocation and route prioritization

### Pickup Hour Distribution
- **Time-series bar chart** showing ride volume by pickup hour across January 2016
- Reveals peak demand windows for driver scheduling and surge pricing analysis
- Identifies daily and weekly cyclical patterns in rider behavior

### Dropoff Hour Distribution
- **Time-series bar chart** showing ride volume by dropoff hour across January–February 2016
- Complements pickup analysis to understand full trip lifecycle timing
- Highlights evening rush patterns and late-night activity

### Interactive Filters
- **Time Range** — date picker to isolate specific periods
- **Pickup Zip** — filter by origin zip code
- **Dropoff Zip** — filter by destination zip code
- Enables drill-down analysis for specific neighborhoods and time windows

---

## Technical Stack

| Component | Technology |
|:----------|:-----------|
| **Platform** | Databricks Community Edition |
| **Processing** | PySpark (DataFrame API) |
| **Querying** | Databricks SQL |
| **Visualization** | Databricks Dashboards (published) |
| **Dataset** | NYC Taxi Trip Records (2016) |

---

## Key Analyses Performed

1. **Demand Pattern Analysis** — Identified hourly and daily pickup/dropoff distributions to understand when and where demand peaks
2. **Fare-Distance Correlation** — Scatter analysis revealing the relationship between trip distance and fare amount, segmented by day of week
3. **Route Revenue Ranking** — Aggregated revenue by origin-destination zone pairs to surface the most profitable routes
4. **Temporal Trends** — Time-series decomposition of ride volumes across weeks to detect cyclical patterns and anomalies

---

## Skills Demonstrated

- **PySpark** — Large-scale data transformation, aggregation, and feature engineering on distributed compute
- **SQL** — Complex analytical queries with grouping, filtering, and window functions on Databricks SQL Warehouses
- **Data Visualization** — Designed a multi-panel interactive dashboard with KPIs, scatter plots, tables, and time-series charts
- **Databricks Platform** — Workspace management, notebook development, SQL Warehouses, dashboard publishing, and scheduling
