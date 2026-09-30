/*--- default in past 3 years ----------*/
with arrears_data as (
select *, 'neo' as portfolio from credit_risk_playground.stg_mrt_neo_arrears_list
where pool_cut_off_date between '2023-09-30' and  '2025-08-31'
union all (
select *, 'rabo' as portfolio from credit_risk_playground.stg_mrt_rabobank_arrears_list 
where pool_cut_off_date  between '2023-09-30' and  '2025-08-31')
),

temp_tbl as (
select 
	pool_cut_off_date,
	portfolio,
	borrower_identifier,
	loan_identifier,
	months_in_arrears
from(
select 
	pool_cut_off_date,
	portfolio,
	borrower_identifier,
	loan_identifier,
	months_in_arrears,
	row_number() over(partition by borrower_identifier, months_in_arrears  order by borrower_identifier) as dups

from arrears_data
)
where dups = 1
order by borrower_identifier, months_in_arrears
)
select 
	months_in_arrears,
	count(distinct borrower_identifier) as users
from temp_tbl 
group by 1
order by 1


--select * from temp_tbl
--where months_in_arrears = '>3'






--select * from credit_risk_playground.stg_mrt_rabobank_portfolio_stats
--where pool_cut_off_date = '2025-08-31'

SELECT * FROM credit_risk_playground.stg_mrt_neo_arrears_list
where 1=1
and loan_identifier in (
'2195354103',
'2208061101',
'2208642101',
'2221580101')
-- pool_cut_off_date = '2026-07-31'
order by borrower_identifier, loan_identifier, pool_cut_off_date DESC
--LIMIT 100;

SELECT * FROM credit_risk_playground.stg_mrt_rabobank_arrears_list
where 1=1
and loan_identifier in (
'3141028-31410280101',
'3145444-31454440102',
'3192992-31929920101',
'3197002-31970020101',
'3216903-32169030301',
'3248168-32481680102'
)
-- pool_cut_off_date = '2026-07-31'
order by borrower_identifier, loan_identifier, pool_cut_off_date DESC
--LIMIT 100;

select * from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where 1=1
and loan_identifier in (
'2195354103',
'2208061101',
'2208642101',
'2221580101')
order by borrower_identifier, loan_identifier, pool_cut_off_date desc


select borrower_identifier, count(distinct loan_identifier) from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
limit 100;


select * from credit_risk_playground.stg_neo_loan_purchases
where pool_cut_off_date = '2026-07-31'
and borrower_identifier ='5562249'
limit 100;


select * from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
and borrower_identifier ='5562249'
limit 100;

select min(pool_cut_off_date) from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
and borrower_identifier ='5562249'
limit 100;

WITH rep_date AS (
    SELECT '2026-07-31'::DATE AS pool_cut_off_date
),
selected_loans AS (
    SELECT 
        p.*,
        e.deposit_amount
    FROM credit_risk_playground.stg_neo_loan_purchases AS p
    INNER JOIN rep_date AS r
        ON p.pool_cut_off_date = r.pool_cut_off_date
    -- Left join to safely bring in the deposit amount without losing purchase records
    LEFT JOIN credit_risk_playground.stg_mrt_neo_esme_raw AS e
        ON p.borrower_identifier = e.borrower_identifier
        AND p.loan_identifier = e.loan_identifier
        AND p.pool_cut_off_date = e.pool_cut_off_date 
)
 select * from selected_loans order by borrower_identifier, loan_identifier;

SELECT 
    SUM(original_balance) AS total_original_balance,
    SUM(net_current_balance) AS total_current_balance,
    
    -- New aggregated columns based on your request
    SUM(deposit_amount) AS total_deposit_amount,
    SUM(net_current_balance - COALESCE(deposit_amount, 0)) AS net_current_balance_less_deposit,
    
    SUM(retained_amount) AS retained_balance,
    COUNT(DISTINCT borrower_identifier) AS borrowers,
    COUNT(DISTINCT loan_identifier) AS loans,
    COUNT(*) AS datapoints,
    AVG(current_loan_to_value) AS ltv,
    100 * AVG(pd) AS avg_pd,
    100 * AVG(lgd) AS avg_lgd,
    -- Expanded alias to prevent Redshift execution error, and added NULLIF to prevent divide-by-zero
    100 * SUM(ecl) / NULLIF(SUM(net_current_balance), 0) AS ecl
FROM selected_loans;

WITH esma_base AS (
    SELECT 
        loan_identifier,
        property_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2025-05-31'
),
collateral_details AS (
    SELECT DISTINCT 
        collateralindexnumber,
        typeofrealestate,
        CASE 
            WHEN LOWER(typeofrealestate) LIKE '%house%' THEN 'house'
            ELSE 'apartment'
        END AS property_class,
        constructionyear,
        CASE 
            WHEN constructionyear <= 1945 OR constructionyear IS NULL THEN 1
            WHEN constructionyear <= 1964 THEN 2
            WHEN constructionyear <= 1974 THEN 3
            WHEN constructionyear <= 1982 THEN 4
            WHEN constructionyear <= 1987 THEN 5
            WHEN constructionyear <= 1991 THEN 6
            WHEN constructionyear <= 1999 THEN 7
            WHEN constructionyear <= 2005 THEN 8
            ELSE 9
        END AS building_year,
        energylabel,
        CASE 
            WHEN LOWER(energylabel) LIKE '%gel%' THEN 'G'
            WHEN LOWER(energylabel) LIKE '%a%' THEN 'A'
            WHEN energylabel IS NULL AND building_year = 1 THEN 'G'
            WHEN energylabel IS NULL AND building_year IN (1, 2) AND property_class = 'house' THEN 'F'
            WHEN energylabel IS NULL AND building_year = 2 AND property_class = 'apartment' THEN 'E'
            WHEN energylabel IS NULL AND building_year = 3 AND property_class = 'house' THEN 'D'
            WHEN energylabel IS NULL AND building_year = 3 AND property_class = 'apartment' THEN 'F'
            WHEN energylabel IS NULL AND building_year IN (4, 5, 6) THEN 'C'
            WHEN energylabel IS NULL AND building_year = 7 THEN 'B'
            WHEN energylabel IS NULL AND building_year = 8 THEN 'B'
            WHEN energylabel IS NULL AND building_year = 9 THEN 'A'  
            ELSE energylabel
        END AS energy_label
    FROM mo_collateral_collateral 
    WHERE ismaincollateral = 'T' 
      AND etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
),
future_arrears AS (
    SELECT 
        loan_identifier,
        -- Weighs defaults higher than just 'due' to prioritize the worst state reached
        MAX(CASE 
            WHEN months_in_arrears = 'default' THEN 2
            WHEN months_in_arrears IN ('1', '2', '3', '>3') THEN 1
            ELSE 0 
        END) AS arrear_severity
    FROM credit_risk_playground.stg_mrt_neo_arrears_list
    WHERE pool_cut_off_date > '2025-05-31'
    GROUP BY loan_identifier
)
SELECT 
    b.energy_label,
    COUNT(DISTINCT a.loan_identifier) AS total_base_loans,
    COUNT(DISTINCT CASE WHEN c.arrear_severity = 1 THEN a.loan_identifier END) AS loans_became_due,
    COUNT(DISTINCT CASE WHEN c.arrear_severity = 2 THEN a.loan_identifier END) AS loans_became_default,
    COUNT(DISTINCT CASE WHEN c.arrear_severity IN (1, 2) THEN a.loan_identifier END) AS total_ever_in_arrears
FROM esma_base AS a
LEFT JOIN collateral_details AS b
    ON a.property_identifier = b.collateralindexnumber
LEFT JOIN future_arrears AS c
    ON a.loan_identifier = c.loan_identifier
GROUP BY b.energy_label
ORDER BY b.energy_label;




select * from credit_risk_playground.mrt_insurance_flag
where provided <> 'Yes'
order by as_of_date, nr_pers;


SELECT 
    b.nr_pers AS borrower_identifier,
    b.as_of_date AS pool_cut_off_date,
    
    ecl.Instrument_ID AS loan_identifier,
    ecl.LegalEntity AS portfolio,
    ecl."limit" AS original_balance,
    ecl.OnBalance_EAD AS current_balance,
    ecl.OnBalance_EAD AS ead,
    ecl.Stage AS ifrs_stage,
    
    -- Evaluates the flag directly from your base insurance table
    CASE 
        WHEN COALESCE(b.provided, 'No') <> 'Yes' AND ecl.Stage = 1 THEN 2 
        ELSE ecl.Stage 
    END AS final_stage,
    
    ecl.ECL_On AS ecl,
    ecl.CurrentRating,
    ecl.PD,
    ecl.LGD,
    ecl.dpd,
    ecl.IS_IFRS,
    ecl.Instrument_Type

FROM credit_risk_playground.mrt_insurance_flag AS b
LEFT JOIN credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios AS ecl
    ON b.nr_pers::VARCHAR = ecl.User_ID::VARCHAR
    AND b.as_of_date::DATE = ecl.ReportDate::DATE
where b.provided <> 'Yes'
order by pool_cut_off_date, borrower_identifier

SELECT * FROM credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios_Sept26
WHERE reportdate = '2026-08-31'
and instrument_id like '2185742%'
LIMIT 100;





