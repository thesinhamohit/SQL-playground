select * from residential_real_estate_loan_nl

select distinct(collateral_type) from residential_real_estate_customer_nl limit 100;



select * from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-06-30'
limit 100;
and purpose NOT IN ('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', 'ND');

select 
pool_cut_off_date, 
count(loan_identifier) as #neo_loans, 
-- sum(original_balance) as orig_bal,  
sum(current_balance) as curr_bal
from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_additional_date <> 'ND5'
--where pool_cut_off_date = '2026-06-30'
group by 1
order by 1;

select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 limit 100;


select reportdate,
stage,
--case
--		when instrument_id like '%-%' then 'Vista'
--        else 'Neo'
--	end as business_line,
--count(instrument_id) as #numloans,
--sum(on_balance_ead) as curr_bal,
--sum(ead) as tot_ead,
--sum(ecl_on) as ecl_on,
sum(ecl) as ecl
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
--where reportdate = '2026-06-30'
group by 1,2
order by 1,2;

select reportdate,
calcdate,
--case
--		when instrument_id like '%-%' then 'Vista'
--        else 'Neo'
--	end as business_line,
count(instrument_id) as #numloans,
sum(onbalance_ead) as curr_bal,
sum(coalesce(offbalance_ead, 0)+onbalance_ead) as tot_ead,
sum(ecl_on) as ecl_on,
sum(coalesce(ecl_off, 0)+ecl_on) as ecl
from credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios
group by 1,2
order by 1,2;



select pool_cut_off_date,
count(loan_identifier) as loan_ct,
sum(current_balance_adj) as curr_bal
from credit_risk_playground.stg_mrt_rabobank_raw_temp
group by 1
order by 1;


select pool_cut_off_date,
count(loan_identifier) as loan_ct,
sum(current_balance) as curr_bal
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
group by 1
order by 1;

select pool_cut_off_date,
count(loan_identifier) as loan_ct,
sum(current_balance) as curr_bal
from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations
group by 1
order by 1;


select reporting_date,
count(loan_identifier) as loan_ct,
sum(current_balance) as curr_bal,
sum(ead) as total_ead
from credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios
group by 1
order by 1;


limit 100;

select reportdate, 
count(instrument_id) as #neoloans,
sum(ead) as tot_ead
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V0
--where reportdate = '2026-06-30'
group by 1
order by 1;

select pool_cut_off_date, count(loan_identifier) as loan_ct, sum(current_balance) as curr_bal
from etl_reporting.rabobank_mortgages
WHERE current_balance > 0 OR retained_amount > 0
group by 1
order by 1;


select *
from etl_reporting.rabobank_mortgages
limit 100;




select reportdate,
case
		when instrument_id like '%-%' then 'Vista'
        else 'Neo'
	end as business_line,
--stage,
count(instrument_id) as #numloans,
sum(on_balance_ead) as curr_bal,
sum(ead) as tot_ead,
sum(ecl_on) as ecl_on,
sum(ecl) as ecl
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
--where reportdate >= '2026-06-30'
group by 1,2
order by 1,2;

-- loan orign after July Vista





select borrower_identifier, loan_identifier, loan_term, repayment_method, payment_type, original_balance, current_balance, valuation_amount
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
-- and borrower_identifier = '5352985'
and loan_term <= 30;

order by 1,2
limit 100


select borrower_identifier, loan_identifier, loan_term, repayment_method, payment_type, original_balance, current_balance, valuation_amount
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
--and borrower_identifier = '5700703'
 and borrower_identifier = '5352985'
-- and loan_term <= 30;

SELECT 
    neo_esme.loan_identifier, original_balance, isavailablevaluationreport, col.constructionplan, col.constructionsite, col.buildtype
FROM 
    credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw AS neo_esme
JOIN 
    mo_collateral_collateral AS col
    ON neo_esme.property_identifier = col.collateralindexnumber
WHERE 
    neo_esme.pool_cut_off_date = {{pool_cut_off_date}}
    AND col.etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
    AND (
        col.isavailablevaluationreport IS NULL
        OR col.isavailablevaluationreport NOT IN ('Y', 'DesktopTaxation', 'N', 'WOZ Beschikking')
        OR (
            col.isavailablevaluationreport = 'N' 
            AND col.constructionplan IS NULL
            AND col.constructionsite IS NULL
            AND col.buildtype IS NULL
        )
        OR (
            col.isavailablevaluationreport = 'WOZ Beschikking'
            AND col.loannumber NOT IN (SELECT nr_lnng FROM bo_loan_management_loan)
        )
    );

WITH borrower_aggregations AS (
    SELECT 
        borrower_identifier,
        SUM(CASE 
            WHEN repayment_method = '1' AND loan_term > 30 THEN original_balance 
            ELSE 0 
        END) AS sum_qualifying_balance,
        CEIL(SUM(valuation_amount)) AS total_valuation
        
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    GROUP BY borrower_identifier
)
SELECT 
    *
FROM borrower_aggregations
WHERE sum_qualifying_balance > (0.5 * total_valuation);


