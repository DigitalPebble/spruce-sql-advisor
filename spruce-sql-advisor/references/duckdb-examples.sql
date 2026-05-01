create table enriched_curs as select * from 'output/**/*.parquet';

-- create table enriched_curs as select * from 'dipe-curs/spruced/**/*.parquet';

-- INSTALL httpfs;
--  LOAD httpfs;
--  CREATE SECRET (
--      TYPE s3,
--      PROVIDER credential_chain
--  );

-- create table enriched_curs as select * from 's3://cf-curs/spruced/**/*.parquet';

select count() from enriched_curs;

select BILLING_PERIOD,
       round(sum(operational_energy_kwh),2) as energie_kwh,
       round(sum(operational_emissions_co2eq_g) / 1000, 2) as operational_kg,
       round(sum(embodied_emissions_co2eq_g) / 1000, 2)    as embodied_kg,
       round(sum(embodied_adp_sbeq_g), 2)    as adp_g
       from enriched_curs
       group by BILLING_PERIOD
       order by BILLING_PERIOD;

select line_item_product_code, product_servicecode, line_item_operation,
       round(sum(operational_emissions_co2eq_g)/1000, 2) as co2_usage_kg,
       round(sum(operational_energy_kwh),2) as energy_usage_kwh,
       round(sum(embodied_emissions_co2eq_g)/1000, 2) as co2_embodied_kg,
       round(sum(embodied_adp_sbeq_g), 2) as embodied_adp_sbeq_g,
       from enriched_curs where operational_emissions_co2eq_g is not null
       group by 1, 2, 3 order by co2_usage_kg desc, co2_embodied_kg desc, energy_usage_kwh desc, line_item_operation
       limit 20;

select product_instance_type, round(sum(operational_emissions_co2eq_g)/1000,2) as co2_usage_kg from enriched_curs
       where len(product_instance_type) > 0  group by product_instance_type order by co2_usage_kg desc;

select
    round(covered * 100 / "total costs", 2) as percentage_costs_covered
from (
         select
             sum(line_item_unblended_cost) as "total costs",
             sum(line_item_unblended_cost) filter (where operational_emissions_co2eq_g is not null) as covered
         from
             enriched_curs
         where
             line_item_line_item_type like '%Usage'
     );


-- costs not covered

select line_item_product_code, product_servicecode, line_item_operation,
       round(sum(line_item_unblended_cost),2) as cost
from enriched_curs where operational_emissions_co2eq_g is null and line_item_line_item_type like '%Usage' and line_item_unblended_cost > 0
group by 1, 2, 3 order by cost desc limit 20;


-- impacts per region

with agg as (
    select
        region,
        sum(operational_emissions_co2eq_g) as operational_emissions_g,
        sum(embodied_emissions_co2eq_g) as embodied_emissions_g,
        sum(operational_energy_kwh) as energy_kwh,
        sum(pricing_public_on_demand_cost) as public_cost,
        avg(carbon_intensity) as avg_carbon_intensity,
        avg(power_usage_effectiveness) as pue
    from enriched_curs
    where operational_emissions_co2eq_g is not null
    group by 1
)
select
    region,
    round(operational_emissions_g / 1000, 2) as co2_usage_kg,
    round(energy_kwh, 2) as energy_usage_kwh,
    round(avg_carbon_intensity, 2) as carbon_intensity,
    round(pue,2) as pue,
    round((operational_emissions_g + embodied_emissions_g) / public_cost, 2) as g_co2_per_dollar
from agg
order by energy_usage_kwh desc, co2_usage_kg desc, region desc;



