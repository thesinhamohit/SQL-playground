DROP TABLE IF EXISTS credit_risk_playground.mrt_forbearance_records;

CREATE TABLE credit_risk_playground.mrt_forbearance_records AS
SELECT 
    neo.pool_cut_off_date::DATE AS pool_cut_off_date,
    neo.loan_identifier,
    neo.borrower_identifier,
    '60 DPD+'::VARCHAR(50) AS forbearance_eligbility_reason,
    NULL::VARCHAR(20) AS forbearance_date,
    NULL::VARCHAR(50) AS forbearance_flag
FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw AS neo
INNER JOIN credit_risk_playground.stg_mrt_neo_arrears_list AS arr
    ON neo.pool_cut_off_date = arr.pool_cut_off_date
    AND neo.borrower_identifier = arr.borrower_identifier
    AND neo.loan_identifier = arr.loan_identifier
WHERE neo.current_balance <> 0
  AND arr.consecutive_months_in_arrears >= 2;
/*
UPDATE credit_risk_playground.mrt_forbearance_records
SET 
    forbearance_date = '2026-09-08',
    forbearance_flag = 'Forborne - performing'
WHERE pool_cut_off_date = '2026-07-31'
  AND loan_identifier = '2185742101';

TRUNCATE TABLE credit_risk_playground.mrt_forbearance_records;

INSERT INTO credit_risk_playground.mrt_forbearance_records (
    pool_cut_off_date,
    loan_identifier,
    borrower_identifier,
    forbearance_eligbility_reason,
    forbearance_date,
    forbearance_flag
) VALUES (
    '2026-08-31',
    '2185742101',
    '5423410',
    '60 DPD+',
    '2026-09-08',
    '1'
);

ALTER TABLE credit_risk_playground.mrt_forbearance_records
ADD COLUMN forborne_exposure DECIMAL(18, 2);

UPDATE credit_risk_playground.mrt_forbearance_records
SET forbearance_flag = 'Performing'
WHERE loan_identifier = '2185742101'
  AND pool_cut_off_date = '2026-08-31';
*/

select * from credit_risk_playground.mrt_forbearance_records;
--where pool_cut_off_date = '2026-07-31'
--and loan_identifier like '2185742101'

select pool_cut_off_date, loan_identifier, borrower_identifier, account_status, arrears_balance, number_months_in_arrears  from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where loan_identifier like '2185742101'
order by pool_cut_off_date desc

select LAST_DAY(CONCAT(REPLACE(SUBSTRING(etl_source_file, 42, 7), '_', '-'), '-28')::DATE) AS pool_cut_off_date,
loan_identifier_number,
 original_balance,
 current_balance,
 arrears_balance
 from
residential_real_estate_loan_nl
where loan_identifier_number = '2185742'
order by 1 DESC

select loan_identifier, account_status
, original_balance, current_balance, cumulative_recoveries, loss_on_sale
from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_cut_off_date = '2026-07-31'
and loss_on_sale is not null 
and loss_on_sale not in ('ND5', '0', '0.00')
limit 100;

select count(distinct loan_identifier)
from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_cut_off_date = '2026-07-31'
and loss_on_sale is not null 
and loss_on_sale not in ('ND5', '0', '0.00')
limit 100;




SELECT Instrument_ID as loan_identifier, User_ID as borrower_identifier, '2185742' AS loan_identifier_number, stage
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios
WHERE ReportDate = '2026-08-31'
AND Instrument_ID = '2185742101'

consecutive_mth_arrear > (first_date_in_arrear - forbearance_date)

as of 1st Aug -> consec= 1
as of 1st July -> consec= 2
forbearance_date - 1st June
first_date_in_arrear - 1st May


select count(distinct loan_identifier)
from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_cut_off_date = {{pool_cut_off_date}}
and loss_on_sale is not null 
and loss_on_sale not in ('ND5', '0', '0.00')
and number_months_in_arrears::INT > 120
limit 100;



select pool_cut_off_date, loan_identifier, loan_identifier_number, arrears_balance, number_months_in_arrears from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_cut_off_date = '2026-07-31'
and number_months_in_arrears::INT > 120
limit 100;


select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
where Instrument_Id like ('2267969%')
and calc_date in ('2026-05-31', '2026-06-30')
