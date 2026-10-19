    
 SELECT loan_identifier, current_balance, deposit_amount
 FROM credit_risk_playground.stg_mrt_neo_esme_raw
 WHERE pool_cut_off_date = '2026-09-30'
 AND current_balance < 0
 order by current_balance::NUMERIC asc
 
 
    
    
    
 SELECT loan_identifier, current_balance, retained_amount, (current_balance+retained_amount) as total
 FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
 WHERE pool_cut_off_date = '2026-09-30'
 AND current_balance < 0
 order by current_balance ASC

 select original_balance, pool_identifier, pool_additional_date, current_balance, deposit_amount, loan_origination_date  from credit_risk_playground.stg_mrt_neo_esme_raw
 WHERE pool_cut_off_date = '2026-09-30'
 and loan_identifier_number = 2264423
 
     SELECT nr_lnng, nr_lnngdl, dtm_ing_lnngdl, dtm_eind_lnngdl, lptd_lnngdl, bedr_hfdsm_lnngdl, kd_aflswze_oms, aantl_mnd_rntevst, kd_gar, etl_updated
    FROM bo_loan_management_loan_part 
    WHERE etl_updated::DATE = '2026-09-30'
    and nr_lnng = 2290725
    
    
        SELECT nr_lnng, SUM(bedr_dept) AS bedr_dept
    FROM bo_construction_deposit_available_credit 
    WHERE etl_updated::DATE = '2026-09-30'
    and nr_lnng = 2264423
    GROUP BY nr_lnng
    
    
    select loan_identifier_number, current_balance, account_status   from residential_real_estate_loan_nl
    where SUBSTRING(etl_source_file, 42, 7) = '2026_09'
    and current_balance < 0
    order by current_balance::NUMERIC asc
    
    
        select loan_identifier_number, loan_identifier, original_balance, purpose, loan_origination_date, deposit_amount, current_balance, account_status   from residential_real_estate_loan_nl
    where SUBSTRING(etl_source_file, 42, 7) = '2026_09'
--    and current_balance < 0
    and loan_identifier_number = 2275471
    order by current_balance::NUMERIC asc
    
 select * from credit_risk_playground.stg_mrt_rabobank_raw_temp limit 100;
    
SELECT 
    a.*, 
    COALESCE(b.current_balance::DECIMAL, c.current_balance::DECIMAL) AS current_bal_raw, 
    COALESCE(b.pool_identifier, c.pool_identifier) AS pool_identifier
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 a
LEFT JOIN credit_risk_playground.stg_mrt_neo_esme_raw b
    ON a.instrument_id = b.loan_identifier
    AND b.pool_cut_off_date = '2026-08-31'
LEFT JOIN credit_risk_playground.stg_mrt_rabobank_raw_temp c
    ON a.instrument_id = c.loan_identifier
    AND c.pool_cut_off_date = '2026-08-31'
WHERE a.reportdate = '2026-09-30';


SELECT * FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
    WHERE reportdate = '2026-09-30'
    and instrument_id LIKE '2274273%'
    
    
SELECT 
    COUNT(DISTINCT borrower_identifier) 
FROM credit_risk_playground.stg_mrt_neo_arrears_list
WHERE pool_cut_off_date::DATE >= ('2026-09-30'::DATE - INTERVAL '3 years')
  AND pool_cut_off_date::DATE <= '2026-09-30'::DATE
  AND LOWER(months_in_arrears::VARCHAR) LIKE '%default%';
    
    
    select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
    where reportdate = '2026-09-30'
    and itemno in (
    '9000901545',
	'9000818802',
	'9000811728',
	'9001105863'
    )
    
    select * from credit_risk_playground.stg_mrt_neo_esme_raw
    where pool_cut_off_date = '2026-08-31'
    and borrower_identifier in ('5446136', '5476850')
    
    
    select borrower_identifier, loan_identifier, loan_origination_date, original_balance
    from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    where pool_cut_off_date = '2026-08-31'
    and loan_origination_date >= '01-01-2026';
    
 

