
SELECT dbt_mev.* 
FROM dbt.macro_economic_scenarios AS dbt_mev
WHERE dbt_mev.scenario_date = '2026-08-31'::DATE;



select * from credit_risk_playground.stg_mrt_ifrs9_mev_input_data
order by reference_date desc
where 


