---
title: SPRUCE SQL Advisor
---

# SPRUCE SQL Advisor

A [Claude skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
that grounds Claude in accurate knowledge for writing and optimising SQL queries against
AWS CUR 2.0 data enriched with [SPRUCE](https://github.com/DigitalPebble/spruce) greenops
columns.

Without this skill, Claude has only generic knowledge of CUR 2.0 — it will frequently
guess the wrong column name (`lineItem/UnblendedCost` vs. `line_item_unblended_cost`),
mishandle nested arrays, forget that SPRUCE emissions are in **grams** rather than tonnes,
or skip the `BILLING_PERIOD` partition key entirely. With the skill loaded, all of those
become reliable.

## What it covers

**CUR 2.0 schema fluency**

- Snake-case `group_columnname` naming convention
- The 125 standard CUR 2.0 columns, with the most common ones called out
- Conditional columns (`line_item_resource_id`, `split_line_item_*`)
- Nested arrays (`resource_tags`, `cost_category`, `product`, `discount`) and how to
  extract from them
- `BILLING_PERIOD` as the partition key in Athena, with guidance on when to filter vs.
  group by it

**SPRUCE greenops columns**

- `operational_energy_kwh`, `operational_emissions_co2eq_g`, `embodied_emissions_co2eq_g`
- `embodied_adp_sbeq_g`, `power_usage_effectiveness`, `carbon_intensity`
- `water_cooling_l`, `water_electricity_production_l`, `water_consumption_stress_area_l`
- `region` (flat VARCHAR, preferred over the nested product region)
- Unit handling (grams → tonnes) and NULL handling for non-modelled line items

**Engine-specific syntax**

The skill detects which SQL engine you're using up front (Athena, DuckDB, or Other) and
adapts every subsequent query accordingly:

| Concern | Athena | DuckDB |
|---|---|---|
| Table reference | `COST_AND_USAGE_REPORT` | `read_parquet('s3://.../**/*.parquet')` or local glob |
| Date cast | `from_unixtime(col / 1000)` | `to_timestamp(col / 1000.0)` |
| Tag access | `element_at(resource_tags, 'user:Key')` | `list_filter(resource_tags, x -> x.key = 'user:Key')[1].value` |

## Install

1. Download the latest `spruce-sql-advisor.skill` from the
   [Releases page](https://github.com/DigitalPebble/spruce-sql-advisor/releases).
2. In Claude.ai, go to **Settings → Capabilities → Skills** and upload the file.
3. Start a new chat and ask a CUR 2.0 SQL question.

## Example prompts

- _"I have a table loaded from SPRUCE parquet output. Show me total CO₂ emissions per
  AWS region for the last three months."_
- _"What percentage of my AWS spend is covered by SPRUCE emissions data?"_
- _"Break down embodied vs. operational emissions by EC2 instance type."_
- _"My DuckDB query is slow when filtering by date — should I be using BILLING_PERIOD
  instead?"_

## Related

- [SPRUCE](https://github.com/DigitalPebble/spruce) — the GreenOps platform that produces
  the enriched CUR 2.0 data.
- [DigitalPebble](https://digitalpebble.com) — green software consultancy.
- [Anthropic Skills documentation](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)

## Licence

Apache License 2.0. See [LICENSE](https://github.com/DigitalPebble/spruce-sql-advisor/blob/main/LICENSE)
and [NOTICE](https://github.com/DigitalPebble/spruce-sql-advisor/blob/main/NOTICE).
