
-- Mortgage Loan Tape

DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_09_30;
CREATE TABLE credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_09_30 AS 

WITH temp_tbl AS (
    SELECT 
        reportdate,
        calc_date,
        instrument_id,
        itemno AS user_id,
        legalentity,
        country,
        on_balance_ead AS onbalance_ead,
        off_balance_eod AS offbalance_ead,
        ead,
        maturitydate,
        initial_pd AS initialpd,
        currentrating,
        pd,
        lgd,
        NULL AS "limit",
        stage,
        ecl_on,
        ecl_off,
        ecl,
        dpd,
        ccf,
        ROW_NUMBER() OVER(PARTITION BY instrument_id, itemno) AS dups
    FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
    WHERE reportdate = '2026-09-30'
),

temp_tbl1 AS (
    SELECT 
        reportdate,
        calc_date,
        instrument_id,
        user_id,
        legalentity,
        country,
        onbalance_ead,
        offbalance_ead,
        ead,
        maturitydate,
        initialpd,
        currentrating,
        pd,
        lgd,
        "limit",
        stage,
        ecl_on,
        ecl_off,
        ecl,
        dpd,
        ccf
    FROM temp_tbl 
    WHERE dups = 1
),

neo_extended AS (
    SELECT 
        c.borrower_identifier,
        c.loan_identifier,
        'Neo' AS business_line,
        c.purpose,
        c.segment,
        c.loan_origination_date,
        c.original_balance,
        c.current_balance,
        c.undrawn_loanpart,
        c.current_balance + c.undrawn_loanpart AS total_committment, 
        c.current_valuation_amount,
        c.collateral_value,
        c.interest_rate_reset_interval,
        c.current_interest_rate,
        c.payment_type,
        c.current_loan_to_value,
        c.payment_type AS amortization_type,
        c.original_loan_to_value,
        c.debt_service_coverage_ratio,
        c.arrears_balance,
        c.months_to_revision_date,
        c.remaining_term,
        c.fitch_dti,
        c.fitch_ltv_class,
        c.fitch_term_class,
        c.fitch_dti_class,
        c.fitch_cltv_class,
        c.fitch_cltv_term_class,
        
        --- fitch adjustments ---
        c.income_adjustment,
        c.final_baseline_ff,
        c.final_io_adjustment,
        c.final_ff_floor,
        ----
        
        c.adjusted_fitch_base_ff / 100 AS adjusted_fitch_base_ff,
        c.annualised_ff / 100 AS annualised_ff,
        c.cure_rate,
        c.pd_factor,
        c.indexed_vlaue_scalar,
        c.fitch_foreclosure_value,
        c.pd_ttc / 100 AS pd_ttc,
        c.pd_pit / 100 AS pd_pit,
        c.pd_pit_mastered / 100 AS pd_pit_mastered,
        c.pd_pit_class,
        c.lgd AS lgd_new,
        
        -- Raw integrations
        r.current_balance::DECIMAL(18,2) AS current_bal_raw,
        r.pool_identifier,
        
        ROW_NUMBER() OVER(
            PARTITION BY c.borrower_identifier, c.loan_identifier 
            ORDER BY c.borrower_identifier, c.loan_identifier
        ) AS reps
    FROM credit_risk_playground.stg_mrt_neo_credit_risk_calculations c
    LEFT JOIN credit_risk_playground.stg_mrt_neo_esme_raw r
        ON c.loan_identifier = r.loan_identifier
        AND r.pool_cut_off_date = '2026-08-31'
    WHERE c.pool_cut_off_date = '2026-08-31'
),

rabo_extended AS (
    SELECT 
        c.borrower_identifier,
        c.loan_identifier,
        'Rabo' AS business_line,
        c.purpose,
        c.segment,
        c.loan_origination_date,
        c.original_balance,
        c.current_balance,
        c.undrawn_loanpart,
        c.current_balance + c.undrawn_loanpart AS total_committment, 
        c.current_valuation_amount,
        c.collateral_value,
        c.interest_rate_reset_interval,
        c.current_interest_rate,
        c.payment_type,
        c.current_loan_to_value,
        c.payment_type AS amortization_type,
        c.original_loan_to_value,
        c.debt_service_coverage_ratio,
        c.arrears_balance,
        c.months_to_revision_date,
        c.remaining_term,
        c.fitch_dti,
        c.fitch_ltv_class,
        c.fitch_term_class,
        c.fitch_dti_class,
        c.fitch_cltv_class,
        c.fitch_cltv_term_class,
        
        --- fitch adjustments ---
        c.income_adjustment,
        c.final_baseline_ff,
        c.final_io_adjustment,
        c.final_ff_floor,
        ----
        
        c.adjusted_fitch_base_ff / 100 AS adjusted_fitch_base_ff,
        c.annualised_ff / 100 AS annualised_ff,
        c.cure_rate,
        c.pd_factor,
        c.indexed_vlaue_scalar,
        c.fitch_foreclosure_value,
        c.pd_ttc / 100 AS pd_ttc,
        c.pd_pit / 100 AS pd_pit,
        c.pd_pit_mastered / 100 AS pd_pit_mastered,
        c.pd_pit_class,
        c.lgd AS lgd_new,
        
        -- Raw integrations
        r.current_balance::DECIMAL(18,2) AS current_bal_raw,
        r.pool_identifier,

        ROW_NUMBER() OVER(
            PARTITION BY c.borrower_identifier, c.loan_identifier 
            ORDER BY c.borrower_identifier, c.loan_identifier
        ) AS reps
    FROM credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations c
    LEFT JOIN credit_risk_playground.stg_mrt_rabobank_raw_temp r
        ON c.loan_identifier = r.loan_identifier
        AND r.pool_cut_off_date = '2026-08-31'
    WHERE c.pool_cut_off_date = '2026-08-31'
),

extensions AS (
    SELECT * FROM neo_extended WHERE reps = 1
    UNION ALL 
    SELECT * FROM rabo_extended WHERE reps = 1
),

forbearance_status AS (
    SELECT 
        loan_identifier,
        forbearance_flag,
        forborne_exposure
    FROM credit_risk_playground.mrt_forbearance_records
),

extension_1 AS (
    SELECT 
        x.*,
        y.business_line,
        y.purpose,
        y.segment,
        y.loan_origination_date,
        y.current_balance,
        y.arrears_balance,
        y.undrawn_loanpart,
        y.total_committment,
        y.collateral_value,
        y.interest_rate_reset_interval,
        y.current_interest_rate,
        y.payment_type,
        y.current_loan_to_value,
        y.debt_service_coverage_ratio,
        y.months_to_revision_date,
        y.remaining_term,
        y.fitch_cltv_class,
        y.fitch_cltv_term_class,
        y.fitch_dti,
        y.fitch_ltv_class,
        y.fitch_term_class,
        y.fitch_dti_class,
        y.income_adjustment,
        y.final_baseline_ff,
        y.final_io_adjustment,
        y.final_ff_floor,
        y.adjusted_fitch_base_ff,
        y.annualised_ff,
        y.cure_rate,
        y.pd_factor,
        y.indexed_vlaue_scalar,
        y.fitch_foreclosure_value,
        y.pd_ttc,
        y.pd_pit,
        y.pd_pit_mastered,
        y.pd_pit_class,
        y.lgd_new,
        y.current_bal_raw,
        y.pool_identifier,
        fb.forbearance_flag,
        fb.forborne_exposure
    FROM temp_tbl1 AS x
    LEFT JOIN extensions AS y
        ON x.instrument_id = y.loan_identifier
    LEFT JOIN forbearance_status fb 
        ON x.instrument_id = fb.loan_identifier
),

required_data AS (
    SELECT 
        -- report dates ---
        reportdate,
        calc_date,
        -- borrower and business lines
        instrument_id,
        user_id,
        legalentity,
        business_line,
        pool_identifier,
        country,
        -- loan characteristics ---
        purpose,
        segment,
        loan_origination_date,
        maturitydate,
        current_balance,
        current_bal_raw,
        arrears_balance,
        undrawn_loanpart,
        total_committment,
        collateral_value,
        interest_rate_reset_interval,
        current_interest_rate,
        CASE WHEN payment_type = 6 THEN 'bullet' ELSE 'non-bullet' END AS repayment_type,
        current_loan_to_value,
        debt_service_coverage_ratio,
        months_to_revision_date,
        remaining_term,
        --- ecl parameters ---
        onbalance_ead,
        offbalance_ead,
        ead,
        initialpd,
        currentrating,
        pd,
        lgd,
        stage,
        ecl_on,
        ecl_off,
        ecl,
        dpd,
        ccf,
        --- pd and lgd calculation ---
        fitch_cltv_class,
        fitch_cltv_term_class,
        fitch_dti,
        fitch_ltv_class,
        fitch_term_class,
        fitch_dti_class,
        income_adjustment,
        final_baseline_ff,
        final_io_adjustment,
        final_ff_floor,
        adjusted_fitch_base_ff,
        annualised_ff,
        cure_rate,
        pd_factor,
        indexed_vlaue_scalar,
        fitch_foreclosure_value,
        pd_ttc,
        pd_pit,
        pd_pit_mastered,
        pd_pit_class,
        lgd_new,
        reportdate AS rating_date,
        CASE 
            WHEN stage = 3 THEN 'problem loan'
            WHEN stage = 2 AND dpd >= 60 THEN 'intensified mgmnt'
            ELSE 'ordinary'
        END AS loan_mananment_stage,
        forbearance_flag,
        forborne_exposure
    FROM extension_1 
)

SELECT *
FROM required_data
ORDER BY user_id, instrument_id;




select reportdate, business_line, sum(onbalance_ead), sum(ead), sum(ecl), sum(ecl_on)
from credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_09_30
group by 1,2
order by reportdate desc

2026-09-30	Neo	1277053690.4099996	1295584817.8000004
2026-09-30	Rabo	630728795.8699999	636227290.1600001

2026-08-31	Neo	1286508400.3600004	1307203789.0000002
2026-08-31	Rabo	632789874.1500001	638265874.4899999

2026-07-31	Neo	1293967589.4900002	1316924251.5500002
2026-07-31	Rabo	630220225.2200001	635866392.9400002



select reportdate, calc_date, pool_identifier, instrument_id, user_id, business_line, current_balance, current_bal_raw, current_loan_to_value, currentrating 
from credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_07_31


WITH combined_data AS (
    SELECT 
    	'Vista' AS business_line,
        pool_cut_off_date,
        loan_identifier,
        current_balance::DECIMAL(18,2),
        retained_amount::DECIMAL(18,2) as deposit_amount
    FROM credit_risk_playground.stg_mrt_rabobank_raw_temp
    
    UNION ALL
    
    SELECT 
    	'Neo' AS business_line,
        pool_cut_off_date,
        loan_identifier,
        current_balance::DECIMAL(18,2),
        deposit_amount::DECIMAL(18,2)
    FROM credit_risk_playground.stg_mrt_neo_esme_raw
)
SELECT 
	business_line,
    pool_cut_off_date, 
    COUNT(DISTINCT loan_identifier) AS num_loan_parts, 
    SUM(current_balance) AS sum_curr_bal_raw, 
    SUM(current_balance - COALESCE(deposit_amount, 0)) AS sum_curr_bal_adj
FROM combined_data
GROUP BY pool_cut_off_date, business_line
ORDER BY pool_cut_off_date desc, business_line DESC;






WITH macro_base AS (
    SELECT 
        reference_date,
        unemployment_rate_hist_q,
        mortgage_interest_rate_hist_m,
        inflation_rate_hist_q
    FROM credit_risk_playground.macroeconomic_scenarios_v3
    WHERE tnc_country = 'NLD'
      AND scenario_date = '2026-06-30'
),

macro_yoy_calculations AS (
    SELECT 
        *,
        -- Note: If the reference_date spacing is quarterly, LAG by 4 for YoY. 
        -- If it contains monthly records, change the offset to 12.
        LAG(unemployment_rate_hist_q, 4) OVER(ORDER BY reference_date) AS unemp_rate_1yr_ago,
        LAG(mortgage_interest_rate_hist_m, 4) OVER(ORDER BY reference_date) AS interest_rate_1yr_ago,
        LAG(inflation_rate_hist_q, 4) OVER(ORDER BY reference_date) AS inflation_rate_1yr_ago
    FROM macro_base
)

SELECT 
    reference_date,
    
    unemployment_rate_hist_q,
    unemp_rate_1yr_ago,
    (unemployment_rate_hist_q - unemp_rate_1yr_ago) AS unemployment_yoy_change,
    
    mortgage_interest_rate_hist_m,
    interest_rate_1yr_ago,
    (mortgage_interest_rate_hist_m - interest_rate_1yr_ago) AS interest_rate_yoy_change_pct,
    
    inflation_rate_hist_q,
    inflation_rate_1yr_ago,
    (inflation_rate_hist_q - inflation_rate_1yr_ago) AS inflation_yoy_change,
    
    CASE 
        -- Checks if the YoY absolute rise in unemployment is > 5% OR if the rate itself exceeds 5%
        WHEN (unemployment_rate_hist_q - unemp_rate_1yr_ago) > 5.0 OR unemployment_rate_hist_q > 5.0 
            THEN 'Trigger: Unemployment Rise / >5%'
            
        -- Checks for > 250 bps (2.5%) rise in 12 months
        WHEN (mortgage_interest_rate_hist_m - interest_rate_1yr_ago) > 2.5 
            THEN 'Trigger: Interest Rate Rise > 250 bps'
            
        -- Checks if CPI inflation > 6%
        WHEN inflation_rate_hist_q > 6.0 
            THEN 'Trigger: Inflation > 6%'
            
        ELSE 'Normal'
    END AS control_flag
    
FROM macro_yoy_calculations
WHERE 
    -- Filter to return only the anomalous/breach periods
    abs(unemployment_rate_hist_q - unemp_rate_1yr_ago) > 5.0 
    OR unemployment_rate_hist_q > 5.0
    OR (mortgage_interest_rate_hist_m - interest_rate_1yr_ago) > 2.5
    OR inflation_rate_hist_q > 6.0
ORDER BY reference_date DESC;




    SELECT 
        reference_date,
        unemployment_rate_hist_m,
        mortgage_interest_rate_hist_m,
        inflation_rate_hist_q
    FROM credit_risk_playground.macroeconomic_scenarios_v3
    WHERE tnc_country = 'NLD'
      AND scenario_date = '2026-06-30'
      
      
      
 select reference_date, unemployment_rate_hist_m, inflation_rate_hist_q, mortgage_interest_rate_hist_m from dbt.macro_economic_scenarios 
where tnc_country = 'NLD'

WITH macro_base AS (
    SELECT 
        reference_date,
        unemployment_rate_hist_m,
        mortgage_interest_rate_hist_m,
        inflation_rate_hist_q
    FROM credit_risk_playground.macroeconomic_scenarios_v3
    WHERE tnc_country = 'NLD'
      AND scenario_date = '2026-06-30'
),

macro_yoy_calculations AS (
    SELECT 
        *,
        -- Lag by 12 rows for YoY calculation because the data is monthly
        LAG(mortgage_interest_rate_hist_m, 12) OVER(ORDER BY reference_date) AS mortgage_rate_1yr_ago
    FROM macro_base
)

SELECT 
    reference_date,
    unemployment_rate_hist_m,
    inflation_rate_hist_q,
    mortgage_interest_rate_hist_m,
    mortgage_rate_1yr_ago,
    (mortgage_interest_rate_hist_m - mortgage_rate_1yr_ago) AS mortgage_yoy_change,
    
    CASE 
        WHEN unemployment_rate_hist_m >= 5.0 THEN 'Breach: Unemployment >= 5%'
        WHEN inflation_rate_hist_q >= 6.0 THEN 'Breach: Inflation >= 6%'
        WHEN (mortgage_interest_rate_hist_m - mortgage_rate_1yr_ago) >= 3.0 THEN 'Breach: Mortgage Rate Rise >= 300 bps'
        ELSE 'Pass'
    END AS control_flag
    
FROM macro_yoy_calculations
-- Filter to look at the latest populated data up to June 2026
WHERE reference_date <= '2026-06-30'
  AND (unemployment_rate_hist_m IS NOT NULL OR mortgage_interest_rate_hist_m IS NOT NULL)
ORDER BY reference_date DESC;
      
