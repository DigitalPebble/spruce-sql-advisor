---
name: spruce-sql-advisor
description: >
  Expert SQL advisor for AWS CUR 2.0 queries enriched with SPRUCE greenops columns.
  Load this skill whenever a user asks for help writing, fixing, explaining, or optimising
  SQL against cloud cost and usage data that includes SPRUCE carbon, electricity, or water
  metrics. Trigger on: "Athena billing", "DuckDB cost report", "CUR 2.0 query",
  "cloud cost SQL", "SPRUCE columns", "operational_energy_kwh", "embodied_emissions_co2eq_g",
  "operational_emissions_co2eq_g", "water_cooling_l", "water_consumption_stress_area_l",
  or any mention of querying AWS spend with SPRUCE sustainability metrics. This skill makes
  Claude dramatically more accurate on CUR 2.0 schema details, BILLING_PERIOD partitioning,
  nested column syntax, engine-specific quirks, and all SPRUCE column semantics.
---

# SPRUCE CUR 2.0 SQL Advisor

This skill grounds Claude in accurate knowledge for writing and optimising SQL queries
against AWS CUR 2.0 tables enriched with **SPRUCE** greenops columns.

For the full standard column reference, read `references/schema.md`.

When the session engine is **DuckDB**, also read `references/duckdb-examples.sql` before
writing queries. It contains real, working DuckDB query patterns against an `enriched_curs`
table loaded from SPRUCE parquet output, and reflects the user's preferred style for:
table loading from local parquet or S3, monthly impact roll-ups, service/operation
breakdowns, instance-type rankings, coverage checks (cost covered by SPRUCE vs. not),
and per-region impact summaries with PUE and carbon intensity. Match this style when
suggesting DuckDB queries — including idioms like `FILTER (WHERE ...)`, `len(col) > 0`
for non-empty checks, and `line_item_line_item_type LIKE '%Usage'` for usage-type
filtering.

---

## Engine and table detection — do this first

**At the start of every session**, before writing any SQL, ask the user which query engine
they are using and what to call the table. Do not assume.

Use the `ask_user_input_v0` tool with a single-select question so the user can tap their
choice instead of typing:

- Question: `Which SQL engine are you using?`
- Options: `Athena`, `DuckDB`, `Other`

Once the user answers, store it as the **session engine**. Then ask a follow-up question
about the table name (this matters when the user has already created a table — e.g.
`CREATE TABLE enriched_curs AS SELECT * FROM 'output/**/*.parquet'` — and just wants to
query it by name):

- Question: `What should I use for the table reference in queries?`
- Options:
  - For Athena: `COST_AND_USAGE_REPORT (default)`, `Custom name — I'll tell you`
  - For DuckDB: `enriched_curs`, `Inline read_parquet(...)`, `Custom name — I'll tell you`

If the user picks a custom name, ask for it in plain text. Store the answer as the
**session table reference** and use it in every query for the rest of the session
instead of the defaults shown in the engine table below.

Generate all subsequent SQL exclusively for the chosen engine. Do not offer alternatives
or add footnotes for other engines.

If `ask_user_input_v0` is not available in this environment, fall back to asking in plain
text: "Which SQL engine are you querying with — Athena, DuckDB, or something else? And
do you want me to use a specific table name, or the default?"

If the user later switches engine or table name, update the session values and confirm:
"Got it, switching to DuckDB with table `enriched_curs` for the rest of the session."

**Engine-specific rules to apply once the engine is known:**

| Concern | Athena | DuckDB |
|---|---|---|
| Table reference | `COST_AND_USAGE_REPORT` | `read_parquet('s3://.../**/*.parquet')` (or a local glob like `'output/**/*.parquet'`) |
| Date cast | `from_unixtime(col / 1000)` | `to_timestamp(col / 1000.0)` |
| Tag/struct access | `element_at(resource_tags, 'user:Key')` | `list_filter(resource_tags, x -> x.key = 'user:Key')[1].value` |
| BILLING_PERIOD | Partition key when present — use for month filtering/grouping if available | Same — inferred from the hive path automatically (DuckDB enables `hive_partitioning` by default) |

For "other" engines: ask the user to describe their dialect, then apply the closest
standard SQL and flag any assumptions made.

---

## Quick orientation

| Property | Value |
|---|---|
| **SQL table name** | `COST_AND_USAGE_REPORT` |
| **Query engines** | Amazon Athena, DuckDB |
| **Partition key** | `BILLING_PERIOD` (STRING, format `YYYY-MM`) — optional; use when available for efficient month filtering/grouping |
| **Standard columns** | 125 possible CUR 2.0 columns |
| **SPRUCE columns** | 10 flat columns (DOUBLE + 1 VARCHAR), no prefix, no nesting |

---

## BILLING_PERIOD — optional but powerful

`BILLING_PERIOD` is a `STRING` column (format: `YYYY-MM`) automatically derived from the
S3 path. It may or may not be present depending on how the data was exported or loaded.

**Do not assume it is available.** Write queries without a `BILLING_PERIOD` filter by
default. After presenting a query, add a note such as:

> "If your table has a `BILLING_PERIOD` column, add `WHERE BILLING_PERIOD = '2025-03'`
> to restrict to a single month (much faster in Athena as it is the partition key), or
> use `GROUP BY BILLING_PERIOD` to break results out by month without filtering."

When `BILLING_PERIOD` is available, it is the best way to scope or group by month:

```sql
-- Restrict to a single month (Athena: uses partition pruning — very efficient)
WHERE BILLING_PERIOD = '2025-03'

-- Range of months
WHERE BILLING_PERIOD BETWEEN '2025-01' AND '2025-03'

-- Group by month without filtering
GROUP BY BILLING_PERIOD ORDER BY BILLING_PERIOD
```

In Athena, `BILLING_PERIOD` is the partition key — omitting it when filtering by month
causes a full table scan and can be very costly. Prefer it over casting the epoch date
columns whenever it is present.

---

## Core CUR 2.0 columns

### Column naming
CUR 2.0 uses `group_columnname` snake_case.
- ✅ `line_item_unblended_cost`
- ❌ `lineItem/UnblendedCost` — legacy CUR 1.0 syntax; convert if a user writes this

### Date columns are LONG (epoch ms)
All date columns store epoch milliseconds as LONG, not TIMESTAMP.
Prefer `BILLING_PERIOD` for period filtering. When you need sub-monthly date work, use
the engine-specific cast from the engine detection table above.

### Most-used columns

```
BILLING_PERIOD                 STRING      ← partition key, YYYY-MM — use this for filtering

-- Identity
identity_line_item_id          STRING
identity_time_interval         STRING

-- Bill
bill_billing_period_start_date LONG (epoch ms)
bill_payer_account_id          STRING
bill_payer_account_name        STRING
bill_bill_type                 STRING      -- ANNIVERSARY | PURCHASE | REFUND

-- Line item
line_item_usage_account_id     STRING
line_item_usage_account_name   STRING
line_item_line_item_type       STRING      -- Usage | Tax | Credit | Refund |
                                           -- DiscountedUsage | RIFee | SavingsPlanUpfrontFee
line_item_usage_start_date     LONG (epoch ms)
line_item_product_code         STRING      -- e.g. AmazonEC2, AmazonS3
line_item_usage_type           STRING
line_item_operation            STRING
line_item_usage_amount         DOUBLE
line_item_unblended_cost       DOUBLE      ← most common cost field
line_item_net_unblended_cost   DOUBLE      ← after EDP/negotiated discounts
line_item_blended_cost         DOUBLE
line_item_currency_code        STRING
line_item_availability_zone    STRING
line_item_resource_id          STRING      ← only if INCLUDE_RESOURCES = TRUE

-- Flat product columns (prefer over unnesting the product array)
product_region_code            STRING      ← use this for region
product_instance_type          STRING
product_instance_family        STRING
product_product_family         STRING
product_servicecode            STRING

-- Flat discount columns (prefer over unnesting the discount array)
discount_total_discount        DOUBLE
discount_bundled_discount      DOUBLE
```

### Nested array columns
`resource_tags`, `cost_category`, `product`, and `discount` are `array<struct<key,value>>`
Use flat `product_*` and `discount_*` columns wherever possible. For tag access, use
the engine-specific syntax from the engine detection table above.

**DuckDB struct array extraction** — the only pattern that works for `product`, `resource_tags`, `cost_category`:
```sql
list_filter(product, x -> x.key = 'model')[1].value AS product_model
```
Do not use subquery/unnest patterns for DuckDB — they do not work on this schema.

### Conditional columns
- `line_item_resource_id` — requires `INCLUDE_RESOURCES = TRUE`
- `split_line_item_*` — requires `INCLUDE_SPLIT_COST_ALLOCATION_DATA = TRUE`

---

## SPRUCE greenops columns

Added by the SPRUCE data pipeline. Flat DOUBLE columns, no prefix, no nesting.
Emissions are in **grams CO₂eq** — divide by 1,000,000 to convert to tonnes.

| Column | Description |
|---|---|
| `operational_energy_kwh` | Electricity consumed by the resource in kWh |
| `operational_emissions_co2eq_g` | Operational carbon emissions in **grams** CO₂eq (from electricity) |
| `embodied_emissions_co2eq_g` | Embodied/manufacturing carbon emissions in **grams** CO₂eq |
| `embodied_adp_sbeq_g` | Abiotic depletion potential (mineral resources) in grams Sb eq |
| `power_usage_effectiveness` | PUE of the data centre used for this resource |
| `carbon_intensity` | Grid carbon intensity used for operational emissions (gCO₂eq/kWh) |
| `water_cooling_l` | Water used for cooling, in litres |
| `water_electricity_production_l` | Upstream water used in electricity generation, in litres |
| `water_consumption_stress_area_l` | Water consumption weighted by regional water stress, in litres |
| `region` | AWS region code (VARCHAR flat column — use instead of `product_region_code` when present) |

### Unit note
SPRUCE emissions are in **grams**, not tonnes. To express results in tonnes CO₂eq:
```sql
SUM(operational_emissions_co2eq_g + embodied_emissions_co2eq_g) / 1000000 AS total_emissions_tco2eq
```

### NULL handling
SPRUCE columns are `NULL` for line items with no emissions model (some Marketplace,
Tax, and Support charges). Always handle:
- Filter: `WHERE operational_emissions_co2eq_g IS NOT NULL`
- Include all rows: `COALESCE(operational_emissions_co2eq_g, 0)`

---

## Query writing guidance

Apply the engine-specific syntax from the engine detection table above. The following
rules apply regardless of engine:

- Use `line_item_unblended_cost` for per-account actual spend
- Use `line_item_net_unblended_cost` when EDP/negotiated discounts should be reflected
- Filter `line_item_line_item_type = 'Usage'` for pure consumption rows; exclude noise with `NOT IN ('Tax', 'Credit', 'Refund')`
- Use flat `product_*` columns — simpler than unnesting the `product` array
- Group by `line_item_product_code` for service breakdowns
- Group by `line_item_usage_account_name` for account views

---

## Example queries

These use Athena syntax. If the session engine is DuckDB, substitute the table reference
and any engine-specific functions per the engine detection table above — and prefer the
patterns in `references/duckdb-examples.sql`, which reflect the user's preferred style.

Examples do not include a `BILLING_PERIOD` filter — add one if the column is available
(e.g. `WHERE BILLING_PERIOD = '2025-03'`) for efficient month-scoped queries in Athena.

### Monthly spend by service
```sql
SELECT
  line_item_product_code                        AS service,
  ROUND(SUM(line_item_unblended_cost), 2)       AS cost_usd
FROM COST_AND_USAGE_REPORT
WHERE line_item_line_item_type NOT IN ('Tax', 'Credit', 'Refund')
-- Add: AND BILLING_PERIOD = '2025-03'  if available, to scope to a month
GROUP BY 1
ORDER BY 2 DESC;
```

### Carbon + cost by service
```sql
SELECT
  line_item_product_code                                                           AS service,
  ROUND(SUM(line_item_unblended_cost), 2)                                          AS cost_usd,
  ROUND(SUM(operational_emissions_co2eq_g + embodied_emissions_co2eq_g) / 1e6, 4) AS total_emissions_tco2eq,
  ROUND(SUM(operational_energy_kwh), 2)                                            AS electricity_kwh
FROM COST_AND_USAGE_REPORT
WHERE line_item_line_item_type = 'Usage'
  AND operational_emissions_co2eq_g IS NOT NULL
-- Add: AND BILLING_PERIOD = '2025-03'  if available
GROUP BY 1
ORDER BY 3 DESC;
```

### Carbon trend broken out by month
```sql
-- Requires BILLING_PERIOD to be present in the table
SELECT
  BILLING_PERIOD,
  ROUND(SUM(operational_emissions_co2eq_g + embodied_emissions_co2eq_g) / 1e6, 4) AS total_emissions_tco2eq,
  ROUND(SUM(line_item_unblended_cost), 2)                                          AS cost_usd
FROM COST_AND_USAGE_REPORT
WHERE line_item_line_item_type = 'Usage'
  AND operational_emissions_co2eq_g IS NOT NULL
GROUP BY BILLING_PERIOD
ORDER BY BILLING_PERIOD;
```

### Water footprint by account
```sql
SELECT
  line_item_usage_account_name                          AS account,
  ROUND(SUM(water_cooling_l), 2)                        AS cooling_water_l,
  ROUND(SUM(water_electricity_production_l), 2)         AS upstream_water_l,
  ROUND(SUM(water_consumption_stress_area_l), 2)        AS stress_weighted_water_l
FROM COST_AND_USAGE_REPORT
WHERE line_item_line_item_type = 'Usage'
  AND water_cooling_l IS NOT NULL
-- Add: AND BILLING_PERIOD = '2025-03'  if available
GROUP BY 1
ORDER BY 4 DESC;
```

### Tag-based emissions breakdown
```sql
SELECT
  element_at(resource_tags, 'user:Environment')                                    AS environment,
  ROUND(SUM(operational_emissions_co2eq_g + embodied_emissions_co2eq_g) / 1e6, 4) AS total_emissions_tco2eq,
  ROUND(SUM(line_item_unblended_cost), 2)                                          AS cost_usd
FROM COST_AND_USAGE_REPORT
WHERE line_item_line_item_type = 'Usage'
  AND operational_emissions_co2eq_g IS NOT NULL
-- Add: AND BILLING_PERIOD = '2025-03'  if available
GROUP BY 1
ORDER BY 2 DESC;
```

---

## Column meaning quick-reference

| Column | Plain-English meaning |
|---|---|
| `BILLING_PERIOD` | Month of the charges, `YYYY-MM` — partition key in Athena; optional, use when available |
| `line_item_unblended_cost` | What this account actually paid |
| `line_item_net_unblended_cost` | Actual cost after EDP / negotiated discounts |
| `line_item_blended_cost` | Org-averaged cost — use only for org roll-ups |
| `line_item_line_item_type` | Row type: Usage = real consumption; others = fees, taxes, credits |
| `line_item_product_code` | AWS service identifier (AmazonEC2, AmazonS3, etc.) |
| `operational_emissions_co2eq_g` | Operational carbon footprint for the line item in grams |
| `embodied_emissions_co2eq_g` | Manufacturing/embodied carbon for the line item in grams |
| `water_consumption_stress_area_l` | Water impact adjusted for regional scarcity |

---

## Flags to raise proactively

- **User filters or groups by month**: suggest `BILLING_PERIOD` if available — it is the partition key in Athena and far more efficient than casting date columns
- **Legacy slash-notation column names** (`lineItem/UnblendedCost`): convert to snake_case
- **Bare `resource_tags` in SELECT**: ask which tag key is needed
- **Summing SPRUCE columns without NULL handling**: suggest `IS NOT NULL` or `COALESCE`
- **Result expressed in grams when tonnes expected**: remind user to divide by 1,000,000
- **Sub-monthly date filtering**: remind user to cast with the engine-specific function from the engine detection table
