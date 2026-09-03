# 🧱 Airbnb End-to-End Data Engineering Project

## 📋 Overview

This project implements a complete end-to-end data engineering pipeline for Airbnb data using modern cloud technologies. The solution demonstrates best practices in data warehousing, transformation, and analytics using Snowflake, dbt (Data Build Tool), and AWS.

The pipeline processes Airbnb listings, bookings, and hosts data through a medallion architecture (Bronze → Silver → Gold), implementing incremental loading, slowly changing dimensions (SCD Type 2), and creating analytics-ready datasets.

## 🏗️ Architecture

### Data Flow

```
Source Data (CSV) → AWS S3 → Snowflake (Staging) → dbt: Bronze tables → Silver tables → Gold tables
                                                        (AIRBNB.BRONZE)   (AIRBNB.SILVER) (AIRBNB.GOLD)
```

Raw CSVs are uploaded to **AWS S3**, then loaded into a `staging` schema in **Snowflake**. From there, **dbt** takes over and materializes every layer as real tables in its own Snowflake schema — Bronze, Silver, and Gold are not views over staging, they're persisted tables dbt owns end to end.

### Technology Stack

* Cloud Data Warehouse: Snowflake
* Transformation Layer: dbt (Data Build Tool)
* Cloud Storage: AWS S3 (implied)
* Version Control: Git
* Python: 3.12+
* Key dbt Features:
   * Incremental models
   * Snapshots (SCD Type 2)
   * Custom macros
   * Jinja templating

## 📊 Data Model

### Medallion Architecture

#### 🥉 Bronze Layer (Raw Data)

Raw data ingested from staging with minimal transformations, materialized as tables in `AIRBNB.BRONZE`:

* `bronze_bookings` - Raw booking transactions
* `bronze_hosts` - Raw host information
* `bronze_listings` - Raw property listings

#### 🥈 Silver Layer (Cleaned Data)

Cleaned and standardized data, materialized as tables in `AIRBNB.SILVER`:

* `silver_bookings` - Validated booking records
* `silver_hosts` - Enhanced host profiles with quality metrics
* `silver_listings` - Standardized listing information with price categorization

#### 🥇 Gold Layer (Analytics-Ready)

Business-ready datasets optimized for analytics, materialized as tables in `AIRBNB.GOLD`:

* `obt` (One Big Table) - Denormalized fact table joining bookings, listings, and hosts
* `fact` - Fact table for dimensional modeling
* Ephemeral models for intermediate transformations

### Snapshots (SCD Type 2)

Slowly Changing Dimensions to track historical changes:

* `dim_bookings` - Historical booking changes
* `dim_hosts` - Historical host profile changes
* `dim_listings` - Historical listing changes

## 🧩 Metadata-Driven Pipeline

The Gold layer models don't hard-code their `SELECT`/`JOIN` clauses. Instead, each model declares a small **config list** — one entry per table, with its columns, alias, and join condition — and a Jinja loop expands that metadata into SQL:

```sql
{% set configs = [
    {"table": "AIRBNB.SILVER.SILVER_BOOKINGS", "columns": "...", "alias": "silver_bookings"},
    {"table": "AIRBNB.SILVER.SILVER_LISTINGS", "columns": "...", "alias": "silver_listings",
     "join_condition": "silver_bookings.listing_id = silver_listings.listing_id"},
    ...
] %}

SELECT
    {% for config in configs %}{{ config.columns }}{% if not loop.last %},{% endif %}{% endfor %}
FROM
    {% for config in configs %}
        {% if loop.first %}{{ config['table'] }} AS {{ config['alias'] }}
        {% else %}LEFT JOIN {{ config['table'] }} AS {{ config['alias'] }} ON {{ config['join_condition'] }}
        {% endif %}
    {% endfor %}
```

Adding, removing, or reordering a joined table is a change to the `configs` list, not to the SQL shape itself — see [`models/gold/obt.sql`](aws_dbt_snowflake_project/models/gold/obt.sql) and [`models/gold/fact.sql`](aws_dbt_snowflake_project/models/gold/fact.sql).

## 📁 Project Structure

```
AWS_DBT_Snowflake/
├── README.md                           
├── pyproject.toml                      
│
├── SourceData/                         
│   ├── bookings.csv
│   ├── hosts.csv
│   └── listings.csv
│
├── DDL/                                
│   └── ddl.sql                         
│
└── aws_dbt_snowflake_project/         
    ├── dbt_project.yml                 
    ├── ExampleProfiles.yml             
    │
    ├── models/                         
    │   ├── sources/
    │   │   └── sources.yml             
    │   ├── bronze/                     
    │   │   ├── bronze_bookings.sql
    │   │   ├── bronze_hosts.sql
    │   │   └── bronze_listings.sql
    │   ├── silver/                     
    │   │   ├── silver_bookings.sql
    │   │   ├── silver_hosts.sql
    │   │   └── silver_listings.sql
    │   └── gold/                       
    │       ├── fact.sql
    │       ├── obt.sql
    │       └── ephemeral/              
    │           ├── bookings.sql
    │           ├── hosts.sql
    │           └── listings.sql
    │
    ├── macros/                         
    │   ├── generate_schema_name.sql    
    │   ├── multiply.sql                
    │   └── tag.sql                     
    │
    ├── analyses/                       
    │   └── looking.sql
    │
    ├── snapshots/                      
    │   ├── dim_bookings.yml
    │   ├── dim_hosts.yml
    │   └── dim_listings.yml
    │
    ├── tests/                          
    │
    └── seeds/                          
```

## 🚀 Getting Started

### Prerequisites

1. Snowflake Account
2. Python Environment
   * pip or uv package manager
3. **AWS Account (for S3 storage)

### Installation

1. Clone the Repository

```bash
git clone https://github.com/VaclavBenda/airbnb-dbt-snowflake-pipeline.git
cd AWS_DBT_Snowflake
```

2. Create Virtual Environment

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1  # Windows PowerShell
# or
source .venv/bin/activate    # Linux/Mac
```

3. Install Dependencies

```bash
pip install -r requirements.txt
# or using pyproject.toml
pip install -e .
```

Core Dependencies:
   * `dbt-core>=1.11.2`
   * `dbt-snowflake>=1.11.0`
   * `sqlfmt>=0.0.3`

4. Configure Snowflake Connection

Snowflake now requires [key-pair authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth) — password-only auth (as in the example above) no longer works. Generate your own `rsa_key.p8` / `rsa_key.pub` pair and reference the private key via `private_key_path` instead of `password`.

Create `~/.dbt/profiles.yml`:

```yaml
aws_dbt_snowflake_project:
  outputs:
    dev:
      type: snowflake
      account: <your-account-identifier>
      user: <your-username>
      private_key_path: <path-to-your-rsa_key.p8>
      private_key_passphrase: <your-key-passphrase>   # omit if the key has no passphrase
      role: ACCOUNTADMIN
      database: AIRBNB
      warehouse: COMPUTE_WH
      schema: dbt_schema
      threads: 4
  target: dev
```

5. Set Up Snowflake Database

Run the DDL scripts to create tables:

```bash
# Execute DDL/ddl.sql in Snowflake to create staging tables
```

6. Load Source Data

Load CSV files from `SourceData/` to Snowflake staging schema:
   * `bookings.csv` → `AIRBNB.STAGING.BOOKINGS`
   * `hosts.csv` → `AIRBNB.STAGING.HOSTS`
   * `listings.csv` → `AIRBNB.STAGING.LISTINGS`

## 🔧 Usage

### Running dbt Commands

1. Test Connection

```bash
cd aws_dbt_snowflake_project
dbt debug
```

2. Install Dependencies

```bash
dbt deps
```

3. Run All Models

```bash
dbt run
```

4. Run Specific Layer

```bash
dbt run --select bronze.*      # Run bronze models only
dbt run --select silver.*      # Run silver models only
dbt run --select gold.*        # Run gold models only
```

5. Run Snapshots

```bash
dbt snapshot
```

6. Generate Documentation

```bash
dbt docs generate
dbt docs serve
```

7. Build Everything

```bash
dbt build  # Runs models, tests, and snapshots
```

## 🎯 Key Features

1. Incremental Loading

Bronze and silver models use incremental materialization to process only new/changed data:

```sql
{{ config(materialized='incremental') }}
{% if is_incremental() %}
    WHERE CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01') FROM {{ this }})
{% endif %}
```

2. Custom Macros

Reusable business logic:

* `tag()` macro: Categorizes prices into 'low', 'medium', 'high'

```sql
{{ tag('CAST(PRICE_PER_NIGHT AS INT)') }} AS PRICE_PER_NIGHT_TAG
```

3. Dynamic SQL Generation

The OBT (One Big Table) model uses Jinja loops for maintainable joins:

```sql
{% set configs = [...] %}
SELECT {% for config in configs %}...{% endfor %}
```

4. Slowly Changing Dimensions

Track historical changes with timestamp-based snapshots:

* Valid from/to dates automatically maintained
* Historical data preserved for point-in-time analysis

5. Schema Organization

Automatic schema separation by layer:

* Bronze models → `AIRBNB.BRONZE.*`
* Silver models → `AIRBNB.SILVER.*`
* Gold models → `AIRBNB.GOLD.*`

## 📝 License

This project is part of a data engineering portfolio demonstration.

## 👤 Author

**Project:** Airbnb Data Engineering Pipeline

**Technologies:** Snowflake, dbt, AWS, Python

**Author:** Václav Benda
