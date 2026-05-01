# CUR 2.0 Full Schema Reference

Source: AWS Data Exports documentation.
SQL table name: `COST_AND_USAGE_REPORT`. Up to 125 standard columns.

---

## Bill columns (always present)

| Column | Type | Description |
|---|---|---|
| `bill_bill_type` | STRING | ANNIVERSARY (regular monthly), PURCHASE (upfront), REFUND |
| `bill_billing_entity` | STRING | AWS or AWS Marketplace |
| `bill_billing_period_end_date` | LONG (epoch ms) | End of billing period (exclusive), UTC — cast with `from_unixtime(col/1000)` in Athena, `to_timestamp(col/1000)` in DuckDB |
| `bill_billing_period_start_date` | LONG (epoch ms) | Start of billing period — **partition key in Athena**; cast before filtering |
| `bill_invoice_id` | STRING | Invoice ID; blank if billing period not yet finalised |
| `bill_invoicing_entity` | STRING | Legal entity issuing the invoice |
| `bill_payer_account_id` | STRING | AWS account ID of the payer |
| `bill_payer_account_name` | STRING | Friendly name of payer account (**CUR 2.0 addition**) |

---

## Identity columns (always present)

| Column | Type | Description |
|---|---|---|
| `identity_line_item_id` | STRING | Unique ID within a partition — not stable across report deliveries |
| `identity_time_interval` | STRING | ISO 8601 interval for the line item period |

---

## Line item columns (always present)

| Column | Type | Description |
|---|---|---|
| `line_item_availability_zone` | STRING | AZ of the resource, e.g. `us-east-1a` |
| `line_item_blended_cost` | DOUBLE | Org-averaged cost; blank for Discount-type rows |
| `line_item_blended_rate` | STRING | Average rate across the org for this SKU |
| `line_item_currency_code` | STRING | Currency code, default USD |
| `line_item_legal_entity` | STRING | Seller of record |
| `line_item_line_item_description` | STRING | Human-readable description of the charge |
| `line_item_line_item_type` | STRING | Usage, Tax, Credit, Refund, DiscountedUsage, RIFee, SavingsPlanUpfrontFee, SavingsPlanRecurringFee, EdpDiscount, PrivateRateDiscount |
| `line_item_net_blended_cost` | DOUBLE | Blended cost after discounts — **not in actual schema, do not use** |
| `line_item_net_unblended_cost` | DOUBLE | Unblended cost after negotiated discounts / EDP |
| `line_item_net_unblended_rate` | STRING | Net unblended rate |
| `line_item_normalization_factor` | DOUBLE | Normalisation factor for size-flexible RIs (DOUBLE, not STRING) |
| `line_item_normalized_usage_amount` | DOUBLE | Normalised usage for RI flex matching |
| `line_item_operation` | STRING | Specific API operation, e.g. `RunInstances` |
| `line_item_product_code` | STRING | AWS service code, e.g. `AmazonEC2`, `AmazonS3` |
| `line_item_resource_id` | STRING | ARN or resource ID — **only if INCLUDE_RESOURCES = TRUE** |
| `line_item_tax_type` | STRING | Tax type, e.g. VAT, US Sales Tax |
| `line_item_unblended_cost` | DOUBLE | What this account actually paid — **most commonly used** |
| `line_item_unblended_rate` | STRING | On-demand rate for this account |
| `line_item_usage_account_id` | STRING | Account that generated the usage |
| `line_item_usage_account_name` | STRING | Friendly name of usage account (**CUR 2.0 addition**) |
| `line_item_usage_amount` | DOUBLE | Amount of usage in the pricing unit |
| `line_item_usage_end_date` | LONG (epoch ms) | End of usage period (exclusive), UTC — cast before use |
| `line_item_usage_start_date` | LONG (epoch ms) | Start of usage period, UTC — cast before use |
| `line_item_usage_type` | STRING | Detailed usage type, e.g. `BoxUsage:t3.medium` |

---

## Pricing columns

| Column | Type | Description |
|---|---|---|
| `pricing_currency` | STRING | Currency for pricing |
| `pricing_lease_contract_length` | STRING | RI contract length, e.g. `1yr`, `3yr` |
| `pricing_offering_class` | STRING | Standard or Convertible (RI) |
| `pricing_public_on_demand_cost` | DOUBLE | Total on-demand cost at list price |
| `pricing_public_on_demand_rate` | STRING | On-demand rate at list price |
| `pricing_purchase_option` | STRING | All Upfront, Partial Upfront, No Upfront |
| `pricing_rate_code` | STRING | Unique rate code for the SKU |
| `pricing_rate_id` | STRING | Rate ID |
| `pricing_term` | STRING | OnDemand, Reserved, Spot |
| `pricing_unit` | STRING | Unit of pricing measure, e.g. `Hrs`, `GB-Mo` |

---

## Product columns — hybrid structure

The actual schema has **two forms** of product data:

**1. Nested array** — `product` is an `array<struct<key:string, value:string>>` (not a simple MAP).

Athena access: `element_at(product, 'region')` or unnest with a CROSS JOIN.
DuckDB access: filter the array — `(SELECT value FROM unnest(product) WHERE key='region')`.

**2. Flat product_* columns** — commonly used product attributes are also available as flat columns:

| Column | Type | Description |
|---|---|---|
| `product_comment` | STRING | Product comment |
| `product_fee_code` | STRING | Fee code |
| `product_fee_description` | STRING | Fee description |
| `product_from_location` | STRING | Origin location (data transfer) |
| `product_from_location_type` | STRING | Origin location type |
| `product_from_region_code` | STRING | Origin region code |
| `product_instance_family` | STRING | Instance family, e.g. `t3` |
| `product_instance_type` | STRING | Instance type, e.g. `t3.medium` |
| `product_instancesku` | STRING | Instance SKU |
| `product_location` | STRING | Human-readable region name |
| `product_location_type` | STRING | Location type |
| `product_operation` | STRING | Product operation |
| `product_pricing_unit` | STRING | Pricing unit |
| `product_product_family` | STRING | Product family, e.g. `Compute Instance` |
| `product_region_code` | STRING | Region code, e.g. `eu-west-1` — **prefer this over the nested array for region** |
| `product_servicecode` | STRING | Service code |
| `product_sku` | STRING | SKU |
| `product_to_location` | STRING | Destination location (data transfer) |
| `product_to_location_type` | STRING | Destination location type |
| `product_to_region_code` | STRING | Destination region code |
| `product_usagetype` | STRING | Usage type |

**Recommendation**: use flat `product_*` columns wherever possible — they are simpler and avoid array unnesting.

---

## Reservation columns (present for RI line items)

| Column | Type | Description |
|---|---|---|
| `reservation_amortized_upfront_cost_for_usage` | DOUBLE | Amortised upfront RI cost for this usage |
| `reservation_amortized_upfront_fee_for_billing_period` | DOUBLE | Amortised upfront fee for the billing period |
| `reservation_availability_zone` | STRING | AZ of the reservation |
| `reservation_effective_cost` | DOUBLE | Amortised cost of RI usage |
| `reservation_end_time` | STRING | RI end time |
| `reservation_modification_status` | STRING | Whether RI was modified |
| `reservation_net_amortized_upfront_cost_for_usage` | DOUBLE | Net amortised upfront cost after discounts |
| `reservation_net_amortized_upfront_fee_for_billing_period` | DOUBLE | Net amortised upfront fee for billing period |
| `reservation_net_effective_cost` | DOUBLE | Net effective cost after discounts |
| `reservation_net_recurring_fee_for_usage` | DOUBLE | Net recurring fee after discounts |
| `reservation_net_unused_amortized_upfront_fee_for_billing_period` | DOUBLE | Net unused upfront fee for billing period |
| `reservation_net_unused_recurring_fee` | DOUBLE | Net unused recurring fee |
| `reservation_net_upfront_value` | DOUBLE | Net upfront value |
| `reservation_normalized_units_per_reservation` | STRING | Normalised units per reservation |
| `reservation_number_of_reservations` | STRING | Number of reservations |
| `reservation_recurring_fee_for_usage` | DOUBLE | Recurring fee for RI usage |
| `reservation_reservation_a_r_n` | STRING | ARN of the reservation — **note: actual column name is `reservation_reservation_a_r_n`** |
| `reservation_start_time` | STRING | RI start time |
| `reservation_subscription_id` | STRING | Subscription ID |
| `reservation_total_reserved_normalized_units` | STRING | Total normalised units reserved |
| `reservation_total_reserved_units` | STRING | Total reserved units |
| `reservation_units_per_reservation` | STRING | Units per reservation |
| `reservation_unused_amortized_upfront_fee_for_billing_period` | DOUBLE | Unused amortised upfront fee |
| `reservation_unused_normalized_unit_quantity` | DOUBLE | Unused normalised units |
| `reservation_unused_quantity` | DOUBLE | Unused reservation quantity |
| `reservation_unused_recurring_fee` | DOUBLE | Unused recurring fee |
| `reservation_upfront_value` | DOUBLE | Upfront RI value |

---

## Savings Plan columns (present for SP line items)

| Column | Type | Description |
|---|---|---|
| `savings_plan_amortized_upfront_commitment_for_billing_period` | DOUBLE | Amortised upfront SP cost |
| `savings_plan_end_time` | STRING | SP end time |
| `savings_plan_instance_type_family` | STRING | Instance type family covered by the SP |
| `savings_plan_net_amortized_upfront_commitment_for_billing_period` | DOUBLE | Net amortised upfront |
| `savings_plan_net_recurring_commitment_for_billing_period` | DOUBLE | Net recurring commitment |
| `savings_plan_net_savings_plan_effective_cost` | DOUBLE | Net SP effective cost |
| `savings_plan_offering_type` | STRING | ComputeSavingsPlans, EC2InstanceSavingsPlans, etc. |
| `savings_plan_payment_option` | STRING | All Upfront, Partial Upfront, No Upfront |
| `savings_plan_purchase_term` | STRING | 1yr or 3yr |
| `savings_plan_recurring_commitment_for_billing_period` | DOUBLE | Recurring SP commitment |
| `savings_plan_region` | STRING | SP region |
| `savings_plan_savings_plan_a_r_n` | STRING | ARN of the Savings Plan — **note: actual column name is `savings_plan_savings_plan_a_r_n`** |
| `savings_plan_savings_plan_effective_cost` | DOUBLE | Effective cost under SP |
| `savings_plan_savings_plan_rate` | DOUBLE | SP rate |
| `savings_plan_start_time` | STRING | SP start time |
| `savings_plan_total_commitment_to_date` | DOUBLE | Total SP commitment to date |
| `savings_plan_used_commitment` | DOUBLE | SP commitment used |

---

## Discount columns — hybrid structure

`discount` is an `array<struct<key:string, value:double>>` in the actual schema — **not a simple MAP, and values are DOUBLE not STRING**.

Additionally, two flat discount columns exist:

| Column | Type | Description |
|---|---|---|
| `discount_bundled_discount` | DOUBLE | Bundled discount amount |
| `discount_total_discount` | DOUBLE | Total discount applied — **use this flat column in preference to unnesting the array** |

---

## Resource tags columns — nested array

`resource_tags` is an `array<struct<key:string, value:string>>` in the actual schema.

**Athena access**: `element_at(resource_tags, 'user:Environment')` — or use a CROSS JOIN UNNEST for filtering.
**DuckDB access**: `(SELECT value FROM unnest(resource_tags) t(key, value) WHERE key = 'user:Environment')`.

The `resource_tags['key']` MAP syntax shown in some AWS docs only applies if the export was configured to unnest tags as separate columns. Check your export configuration.

---

## Cost category columns — nested array

`cost_category` is an `array<struct<key:string, value:string>>` in the actual schema.

Same access patterns as `resource_tags` above.

---

## Split line item columns (conditional: INCLUDE_SPLIT_COST_ALLOCATION_DATA = TRUE)

| Column | Type | Description |
|---|---|---|
| `split_line_item_actual_usage` | DOUBLE | Actual usage attributed to this split |
| `split_line_item_net_split_cost` | DOUBLE | Net cost of split |
| `split_line_item_net_unused_cost` | DOUBLE | Net unused cost of split |
| `split_line_item_parent_resource_id` | STRING | Resource ID of the parent |
| `split_line_item_public_on_demand_split_cost` | DOUBLE | On-demand cost of split |
| `split_line_item_public_on_demand_unused_cost` | DOUBLE | On-demand unused cost of split |
| `split_line_item_reserved_usage` | DOUBLE | Reserved usage attributed to this split |
| `split_line_item_split_cost` | DOUBLE | Total cost of split |
| `split_line_item_split_usage` | DOUBLE | Usage attributed to this split |
| `split_line_item_split_usage_ratio` | DOUBLE | Ratio of usage attributed |
| `split_line_item_unused_cost` | DOUBLE | Unused cost attributed to split |

---

## Capacity reservation columns (conditional: INCLUDE_CAPACITY_RESERVATION_DATA = TRUE)

| Column | Type | Description |
|---|---|---|
| `capacity_reservation_capacity_reservation_arn` | STRING | ARN of the capacity reservation |
| `capacity_reservation_capacity_reservation_status` | STRING | Status of the capacity reservation |
| `capacity_reservation_capacity_reservation_type` | STRING | Type of capacity reservation |

---


## SPRUCE greenops columns (added by SPRUCE pipeline)

All `DOUBLE`. Flat columns, no prefix, no nesting. Emissions in **grams**.

The following columns have been observed in a real enriched DuckDB table:

| Column | Description |
|---|---|
| `operational_energy_kwh` | Electricity consumed in kWh |
| `operational_emissions_co2eq_g` | Operational carbon emissions in grams CO₂eq |
| `embodied_emissions_co2eq_g` | Embodied/manufacturing carbon emissions in grams CO₂eq |
| `embodied_adp_sbeq_g` | Abiotic depletion potential (mineral resources) in grams Sb eq |
| `power_usage_effectiveness` | PUE of the data centre used for this resource |
| `carbon_intensity` | Grid carbon intensity used for operational emissions calculation (gCO₂eq/kWh) |
| `water_cooling_l` | Water for cooling in litres |
| `water_electricity_production_l` | Upstream water for electricity generation in litres |
| `water_consumption_stress_area_l` | Water consumption weighted by regional water stress in litres |
| `region` | AWS region code as used by SPRUCE (VARCHAR, flat column — use instead of `product_region_code` when available) |
