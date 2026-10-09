# Bauchi State Health Facility Readiness: Excel, MySQL and Power BI

An end-to-end data project that takes a raw national health facility file and turns it into a cleaned relational database, a set of SQL measures, and an interactive Power BI dashboard on facility readiness in Bauchi State, Nigeria.

![Bauchi State Facility Readiness Dashboard](Bauchi%20State%20Facility%20Readiness_page-001.jpg)
## Important note on the data

- **Facility records are real.** They come from the GRID3 Nigeria health facility dataset (1,787 facilities in Bauchi State).
- **Monitoring results are simulated.** Real facility-level monitoring records are not public, so the visit and indicator data were generated for portfolio demonstration: 304 facilities, 3 visit rounds (July to September 2026) and 18 SARA-style readiness indicators. Findings below describe the simulated data and say nothing about real facilities.

## Project goals

1. Clean a messy national dataset in Excel and document every decision.
2. Design a relational schema with correct keys and relationships in MySQL.
3. Create the measures in SQL first, then rebuild and reconcile them in DAX.
4. Present the results in a Power BI dashboard.

## Tools

| Stage | Tool |
|---|---|
| Cleaning | Microsoft Excel (lookup tables, pivots, formulas) |
| Database | MySQL 8, MySQL Workbench |
| Modelling and visuals | Power BI Desktop, DAX, Power Query |

## Process

### 1. Data cleaning (Excel)
- Filtered the national file (41,778 facilities, 24 states) to Bauchi State: **1,787 facilities, 20 LGAs**.
- Reduced 38 columns to the 14 needed. Dropped empty, constant and internal GIS columns.
- Replaced blanks in level, type, ownership and functional status with `Unknown`, without guessing values.
- Mapped 19 facility types into 7 groups (PHC, Health Post, Clinic, Maternity, Hospital, Other, Unknown) using a mapping table and lookup formula.
- Added a `coordinate_status` column: 1,598 Valid, 165 Missing and 24 Outside Bauchi. Invalid coordinates were kept for counts but excluded from the map.

### 2. Database design (MySQL)
- Lookup tables: `lga`, `ward`, `facility_level`, `facility_type_group`, `facility_type`, `ownership`, `ownership_type`.
- Main table: `facility` (1,787 rows), linked to its lookups through foreign keys.
- Monitoring tables: `monitor`, `indicator_domain`, `indicator`, `monitoring_visit`, `visit_indicator_result`.
- A staging table loads the CSV, and lookup tables are filled from it before `facility` is built.
- **Design finding:** five ward names (Lariye, Mball, Yangamai, Yola, Zaura) exist in two LGAs each. Wards are therefore unique only within their LGA (334 wards, not 329), so `ward` has a composite unique key on `(lga_id, ward_name)`.

### 3. Measures (SQL views)
Seven views calculate readiness before any dashboard work: visit readiness score and band, domain scores, medicine stockouts, latest visit per facility, score change, LGA summary and LGA trend.

### 4. Dashboard (Power BI)
- Star-style model with one-to-many relationships and single-direction filtering.
- 5 calculated columns and 13 DAX measures, each reconciled against the SQL view results.
- Visuals: KPI cards, readiness by LGA, readiness by domain, trend by visit month, readiness band donut and a facility map.

## Key measures

| Measure | Definition |
|---|---|
| Readiness Score % | Items present / items checked |
| Readiness Band | Ready (75% or more), Partly ready (50 to 74.9%), Not ready (below 50%) |
| Stockout Rate % | Share of facilities missing at least one of 3 essential medicines at the latest visit |
| Coverage % | Monitored facilities / all facilities |
| Score Change (pts) | Latest readiness minus first-round readiness |

## Findings (simulated monitoring data)

- 304 of 1,787 facilities monitored (17.0% coverage).
- Latest readiness: **66.1%**. Only **36.5%** of monitored facilities reach the Ready band.
- **67.1%** of monitored facilities had at least one essential medicine stockout.
- Readiness rose by **5.1 points** from July to September.
- Hospitals averaged about 90% readiness, PHCs about 73% and Health Posts about 51%.
- Weakest domain: Basic Amenities (59.1%). Strongest: Basic Equipment (72.8%).

## Data quality observations

- Functional status is `Unknown` for 1,294 of 1,787 facilities (about 72%), so it was treated as a data-quality finding and not as a headline metric.
- Only 145 facilities carry an NHFR code, so `facility_id` is the primary key.
- 189 facilities (165 missing and 24 outside the state boundary) have unusable coordinates.

## Repository structure

```
/data
    bauchi_facilities_clean.csv
/sql
    01_bauchi_schema.sql
    02_monitoring_tables_and_data.sql
    03_measures_views.sql
    04_powerbi_dimension_views.sql
/powerbi
    bauchi_health_dashboard.pbix
    dax_measures.txt
/images
    dashboard.png
README.md
```

## How to reproduce

1. Run `01_bauchi_schema.sql` parts 1 to 4 in MySQL Workbench, import `bauchi_facilities_clean.csv` into `stg_facility`, then run parts 5 to 7.
2. Run `02_monitoring_tables_and_data.sql`, then `03_measures_views.sql` and `04_powerbi_dimension_views.sql`.
3. Export `vw_dim_facility`, `vw_dim_indicator`, `monitor`, `monitoring_visit` and `visit_indicator_result` to CSV.
4. Open the `.pbix` file and refresh from those CSV files, or rebuild using `dax_measures.txt`.

## Limitations

- Monitoring data is simulated, so findings are illustrative.
- Readiness indicators follow SARA-style domains and were not taken from an official Nigerian monitoring form.
- The coordinate check uses an approximate bounding box for Bauchi State, so a wrong point inside the box would not be caught.

## Data source

GRID3 Nigeria, Health Facilities dataset (v3.0).

## Author

**Faith Nina** | M&E, research and data analysis
Background in field monitoring and data validation. Open to monitoring and evaluation, research and development-sector roles.
