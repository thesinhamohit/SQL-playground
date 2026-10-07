/*
----
DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios_Sept26;

CREATE TABLE credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios_Sept26 AS
SELECT 
    *,
    NULL::VARCHAR(255) AS ifrs_stage_reason
FROM credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios
WHERE reporting_date <= '2026-06-30';



----
*/
INSERT INTO credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios_Sept26
WITH RECURSIVE horizon(next_period) AS (
    SELECT 0
    UNION ALL
    SELECT next_period + 1 FROM horizon WHERE next_period < 36
),

report_date AS (
    SELECT '2026-07-31'::date AS reporting_date
),

-- 1. Baseline risk parameters
base_calculations AS (
    SELECT 
        risk_cal.pool_cut_off_date AS reporting_date,	
        risk_cal.borrower_identifier,
        risk_cal.loan_identifier,
        risk_cal.segment,
        risk_cal.purpose,
        risk_cal.current_balance,	
        risk_cal.customer_level_current_balance, 
        risk_cal.undrawn_loanpart,
        risk_cal.loan_origination_date,
        risk_cal.date_of_loan_maturity,	
        risk_cal.loan_term,
        risk_cal.remaining_term,
        COALESCE(risk_cal.current_interest_rate, non_null_rate) AS current_interest_rate,
        risk_cal.payment_type, 
        risk_cal.payment_due,
        risk_cal.arrears_balance,	
        risk_cal.number_months_in_arrears,
        risk_cal.account_status,
        risk_cal.consecutive_months_in_arrears AS mpd,
        risk_cal.pd_pit_mastered AS one_year_pd,	
        risk_cal.pd_pit_class AS rating_class,
        risk_cal.pd_pit_mastered_down_scen,
        risk_cal.pd_pit_mastered_neu_scen,
        risk_cal.pd_pit_mastered_up_scen,
        risk_cal.lgd_down_scen,
        risk_cal.lgd_neu_scen,
        risk_cal.lgd_up_scen,
        risk_cal.lgd_weighted,
        risk_cal.expected_loss_1year
    FROM credit_risk_playground.stg_mrt_neo_credit_risk_calculations_with_scenarios AS risk_cal
    LEFT JOIN (
        SELECT
            borrower_identifier, 
            loan_identifier,
            current_interest_rate AS non_null_rate,
            ROW_NUMBER() OVER(PARTITION BY borrower_identifier, loan_identifier ORDER BY pool_cut_off_date) AS rankings
        FROM credit_risk_playground.stg_mrt_neo_credit_risk_calculations_with_scenarios
        WHERE current_interest_rate IS NOT NULL
    ) AS init_rates
        ON risk_cal.borrower_identifier = init_rates.borrower_identifier
        AND risk_cal.loan_identifier = init_rates.loan_identifier
        AND init_rates.rankings = 1
),

-- 2. Extract PDs at initial recognisation
initial_recognition_values AS (
    SELECT 
        a.*, 
        b.initial_pd
    FROM (
        SELECT
            MIN(pool_cut_off_date) AS first_date_in_portfolio,
            loan_identifier
        FROM credit_risk_playground.stg_mrt_neo_credit_risk_calculations
        GROUP BY loan_identifier
    ) a
    INNER JOIN (
        SELECT 
            pool_cut_off_date AS reporting_date,
            borrower_identifier, 
            loan_identifier,
            pd_pit_mastered AS initial_pd
        FROM credit_risk_playground.stg_mrt_neo_credit_risk_calculations
    ) b 
        ON a.first_date_in_portfolio = b.reporting_date
        AND a.loan_identifier = b.loan_identifier
),

-- Merge base_calculations with initial_recognition_values
merged_data AS (
    SELECT 
        init_values.first_date_in_portfolio,
        base.*,
        CASE 
            WHEN base.reporting_date::date > init_values.first_date_in_portfolio::date THEN init_values.initial_pd
            ELSE one_year_pd
        END AS initial_pd,
        ROW_NUMBER() OVER(PARTITION BY base.borrower_identifier, base.loan_identifier, base.reporting_date ORDER BY base.borrower_identifier, base.loan_identifier, base.reporting_date) AS duplicates
    FROM base_calculations AS base
    LEFT JOIN initial_recognition_values AS init_values
        USING(loan_identifier)
),

-- 3. Restrict data to indicated reporting date & calc ltpd
main_data AS (
    SELECT 
        md.reporting_date,	
        borrower_identifier,
        loan_identifier,
        segment,
        purpose,
        current_balance,
        undrawn_loanpart,
        customer_level_current_balance,
        loan_origination_date,
        first_date_in_portfolio,
        date_of_loan_maturity,	
        loan_term,
        payment_type,
        payment_due,
        remaining_term,
        current_interest_rate,
        arrears_balance,	
        number_months_in_arrears,
        account_status,
        mpd,
        initial_pd,
        one_year_pd,	
        rating_class,
        pd_pit_mastered_down_scen,
        pd_pit_mastered_neu_scen,
        pd_pit_mastered_up_scen,
        lgd_down_scen,
        lgd_neu_scen,
        lgd_up_scen,
        lgd_weighted,
        expected_loss_1year,
        CASE 
            WHEN initial_pd = 0 THEN 0
            ELSE 100 * (1 - POWER(1 - initial_pd / 100, remaining_term))  
        END AS initial_ltpd,
        CASE 
            WHEN one_year_pd = 0 THEN 0
            ELSE 100 * (1 - POWER(1 - one_year_pd / 100, remaining_term)) 
        END AS current_ltpd
    FROM merged_data AS md
    INNER JOIN report_date AS r_date
        USING(reporting_date)
    WHERE duplicates = 1
),
-- Fetch the most recent insurance status <= 1 month prior to reporting_date
insurance_status AS (
    SELECT 
        nr_pers, 
        provided, 
        ROW_NUMBER() OVER(PARTITION BY nr_pers ORDER BY as_of_date DESC) as rn
    FROM credit_risk_playground.mrt_insurance_flag
    WHERE as_of_date <= (SELECT DATEADD(MONTH, -1, reporting_date) FROM report_date)
),

-- Fetch forbearance status (one row per loan_identifier based on new logic)
forbearance_status AS (
    SELECT 
        loan_identifier,
        forbearance_flag,
        forborne_exposure
    FROM credit_risk_playground.mrt_forbearance_records
),

-- 4. Staging
ifrs_staging1 AS ( 
    SELECT 
        md.*,		 
        CASE 
            WHEN (md.one_year_pd = 100 OR md.account_status = 3) THEN 3
            WHEN (fb.forbearance_flag = 'Default') THEN 3
            WHEN ins.provided IS NOT NULL AND ins.provided <> 'Yes' THEN 2
            WHEN md.mpd >= 2 AND md.one_year_pd < 100 AND md.arrears_balance > 0 THEN 2
            WHEN md.current_ltpd > 3 * md.initial_ltpd THEN 2
            WHEN (fb.forbearance_flag in ('Performing', 'Probation')) THEN 2
            WHEN md.rating_class IN ('15','16','17') THEN 2 
            ELSE 1
        END AS stage,
        CASE 
            WHEN (md.one_year_pd = 100 OR md.account_status = 3) THEN 'PD 1 or account arrear'
            WHEN (fb.forbearance_flag = 'Default') THEN 'Forbearance - Non-performing'
            WHEN (fb.forbearance_flag in ('Performing', 'Probation')) THEN 'Forbearance - Performing'
            WHEN ins.provided IS NOT NULL AND ins.provided <> 'Yes' THEN 'Insurance not provided'
            
            WHEN md.mpd >= 2 AND md.one_year_pd < 100 AND md.arrears_balance > 0 AND md.number_months_in_arrears >= 2 THEN 'PD change 200% (Arrears >= 2 months)'
            WHEN md.mpd >= 2 AND md.one_year_pd < 100 AND md.arrears_balance > 0 THEN 'PD change 200% (Methodological change)'
            
            WHEN md.current_ltpd > 3 * md.initial_ltpd THEN 'Lifetime PD 3 times initial'
            WHEN md.rating_class IN ('15','16','17') THEN 'High Rating class'
            ELSE 'Stage 1'
        END AS stage_reason,
        md.current_balance AS ead
    FROM main_data md
    LEFT JOIN insurance_status ins
        ON md.borrower_identifier = ins.nr_pers::VARCHAR
        AND ins.rn = 1
    LEFT JOIN forbearance_status fb
        ON md.loan_identifier = fb.loan_identifier::VARCHAR
),

ifrs_staging_temp AS ( 
    SELECT 
        *,
        MAX(stage) OVER(PARTITION BY reporting_date, borrower_identifier) AS ifrs_stage,
        FIRST_VALUE(stage_reason) OVER(
            PARTITION BY reporting_date, borrower_identifier 
            ORDER BY stage DESC, stage_reason ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS ifrs_stage_reason,
        one_year_pd AS one_year_pd_tmp
    FROM ifrs_staging1
),

ifrs_staging AS (
    SELECT
        reporting_date,
        borrower_identifier,
        loan_identifier,
        segment,
        purpose,
        current_balance,
        undrawn_loanpart,
        customer_level_current_balance,
        loan_origination_date,
        first_date_in_portfolio,
        date_of_loan_maturity,
        loan_term,
        payment_type,
        payment_due,
        remaining_term,
        current_interest_rate,
        arrears_balance,
        number_months_in_arrears,
        account_status,
        mpd,
        initial_pd,
        CASE WHEN ifrs_stage = 3 THEN 100 ELSE one_year_pd_tmp END AS one_year_pd,
        rating_class,
        pd_pit_mastered_down_scen,
        pd_pit_mastered_neu_scen,
        pd_pit_mastered_up_scen,
        lgd_down_scen,
        lgd_neu_scen,
        lgd_up_scen,
        lgd_weighted,
        expected_loss_1year,
        initial_ltpd,
        current_ltpd,
        stage,
        stage_reason,
        ead,
        ifrs_stage,
        ifrs_stage_reason
    FROM ifrs_staging_temp
),

-- 5. ECL for stage 1 and 3
ecl_calculation AS (
    SELECT 
        *,
        CASE 
            WHEN ifrs_stage = 1 THEN (one_year_pd / 100) * (lgd_down_scen / 100) * ead 
            WHEN ifrs_stage = 3 THEN (lgd_down_scen / 100) * ead 
        END AS ecl_down_scen,
        
        CASE 
            WHEN ifrs_stage = 1 THEN (one_year_pd / 100) * (lgd_neu_scen / 100) * ead 
            WHEN ifrs_stage = 3 THEN (lgd_neu_scen / 100) * ead 
        END AS ecl_neu_scen,
        
        CASE 
            WHEN ifrs_stage = 1 THEN (one_year_pd / 100) * (lgd_up_scen / 100) * ead 
            WHEN ifrs_stage = 3 THEN (lgd_up_scen / 100) * ead 
        END AS ecl_up_scen
    FROM ifrs_staging 
),

-- 6. Make cashflow projection for stage 2 and non-defaulted stage 3 ecl calculation
cashflow_projection1 AS (
    SELECT 
        reporting_date,	
        borrower_identifier,
        loan_identifier,
        remaining_term,
        payment_type,
        payment_due,
        current_interest_rate,
        ifrs_stage,
        one_year_pd,	
        lgd_down_scen,
        lgd_neu_scen,
        lgd_up_scen,
        ead,
        next_period AS future_period
    FROM ecl_calculation 
    CROSS JOIN horizon
    WHERE ifrs_stage = 2
),

cashflow_projection2 AS (
    SELECT 
        *,
        100 * (POWER(1 - one_year_pd / 100, future_period) - POWER(1 - one_year_pd / 100, future_period + 1)) AS pd_future_period,
        CASE 
            WHEN payment_type = 1 THEN (CASE WHEN future_period = 0 THEN ead 
                        ELSE ROUND(ead * (POWER(1 + current_interest_rate / 1200, remaining_term) - POWER(1 + current_interest_rate / 1200, LEAST(future_period, remaining_term))) 
                                        / (POWER(1 + current_interest_rate / 1200, remaining_term) - 1), 2) END)
            WHEN payment_type = 2 THEN ROUND(GREATEST(ead - (future_period * ead / NULLIF(remaining_term, 0)), 0), 2)
            WHEN payment_type = 6 THEN (CASE WHEN future_period <= remaining_term THEN ead ELSE 0 END)
        END AS ead_future_period,
        POWER(1 + current_interest_rate / 100, -future_period) AS discount_factor
    FROM cashflow_projection1
),

-- 7. Lifetime ecl calculations
temp_lifetime_ecl AS (
    SELECT 
        *,
        (pd_future_period / 100) * (lgd_neu_scen / 100) * ead_future_period AS ecl_future_period_neu_scen,
        (pd_future_period / 100) * (lgd_down_scen / 100) * ead_future_period AS ecl_future_period_down_scen,
        (pd_future_period / 100) * (lgd_up_scen / 100) * ead_future_period AS ecl_future_period_up_scen,
        
        (pd_future_period / 100) * (lgd_neu_scen / 100) * ead_future_period * discount_factor AS ecl_future_period_discounted_neu_scen,
        (pd_future_period / 100) * (lgd_down_scen / 100) * ead_future_period * discount_factor AS ecl_future_period_discounted_down_scen,
        (pd_future_period / 100) * (lgd_up_scen / 100) * ead_future_period * discount_factor AS ecl_future_period_discounted_up_scen
    FROM cashflow_projection2
),

lifetime_ecl AS (
    SELECT 
        reporting_date,
        borrower_identifier,
        loan_identifier,
        ROUND(SUM(ecl_future_period_discounted_neu_scen * 0.955 + ecl_future_period_discounted_down_scen * 0.0225 + ecl_future_period_discounted_up_scen * 0.0225), 2) AS lifetime_ecl
    FROM temp_lifetime_ecl 
    GROUP BY reporting_date, borrower_identifier, loan_identifier, ifrs_stage
),

-- 8. Combine ecl calculation for all stages
final_ecl_calculation AS (
    SELECT 
        a.*,
        ROUND(COALESCE(a.ecl_down_scen * 0.0225 + a.ecl_neu_scen * 0.955 + a.ecl_up_scen * 0.0225, b.lifetime_ecl), 2) AS expected_credit_loss
    FROM ecl_calculation a
    LEFT JOIN lifetime_ecl b
        USING(reporting_date, borrower_identifier, loan_identifier)
)

SELECT 
    reporting_date,
    borrower_identifier,
    loan_identifier,
    segment,
    purpose,
    current_balance,
    undrawn_loanpart,
    customer_level_current_balance,
    loan_origination_date,
    first_date_in_portfolio,
    date_of_loan_maturity,
    loan_term,
    payment_type,
    payment_due,
    remaining_term,
    current_interest_rate,
    arrears_balance,
    number_months_in_arrears,
    account_status,
    mpd,
    initial_pd,
    one_year_pd,
    rating_class,
    pd_pit_mastered_down_scen,
    pd_pit_mastered_neu_scen,
    pd_pit_mastered_up_scen,
    lgd_down_scen,
    lgd_neu_scen,
    lgd_up_scen,
    lgd_weighted,
    expected_loss_1year,
    initial_ltpd,
    current_ltpd,
    stage,
    ead,
    ifrs_stage,
    ecl_down_scen,
    ecl_neu_scen,
    ecl_up_scen,
    expected_credit_loss,
    GETDATE() AS etl_updated,
    'alfred_teye'::TEXT AS created_by,
    ifrs_stage_reason 
FROM final_ecl_calculation;



select ifrs_stage, ifrs_stage_reason, count(*) as vol
from credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios_Sept26
where reporting_date = '2026-07-31'
group by 1,2

DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios_Sept26;

CREATE TABLE credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios_Sept26 AS
SELECT 
    *,
    NULL::VARCHAR(255) AS ifrs_stage_reason
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios
WHERE ReportDate <= '2026-06-30';



INSERT INTO credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios_Sept26
WITH report_date AS (
    SELECT '2026-08-31'::date AS reporting_date  ---- account date as is
),

rabo_mortgages AS (
    SELECT 
        temp_b.reporting_date::date AS ReportDate,
        temp_a.reporting_date::date AS CalcDate,
        loan_identifier::varchar AS Instrument_ID, 
        borrower_identifier::varchar AS User_ID,
        'EU'::varchar AS LegalEntity,
        'NLD'::varchar AS Country,
        ead AS OnBalance_EAD,
        undrawn_loanpart::decimal(10,2) AS OffBalance_EAD,
        date_of_loan_maturity AS MaturityDate,
        initial_pd / 100::float AS InitialPD,
        rating_class AS CurrentRating,
        one_year_pd / 100::float AS PD,
        CASE
            WHEN OnBalance_EAD < 0 THEN 0.05
            ELSE lgd_weighted / 100::float 
        END AS LGD,
        NULL AS limit,
        ifrs_stage AS Stage,
        'Unavailable' AS ifrs_stage_reason, -- Uncommented
        expected_credit_loss::float AS ECL_On,
        (PD * LGD * OffBalance_EAD)::decimal(10,2) AS ECL_Off,
        ROUND(mpd / 0.0329)::float AS dpd,
        NULL AS CCF,
        'yes' AS IS_IFRS, 
        'mortgage' AS Instrument_Type,
        'credit' AS Instrument
    -- Assuming Rabo also has ifrs_stage_reason; if not, cast NULL AS stage_reason
    FROM credit_risk_playground.stg_mrt_rabobank_ifrs9_ecl_reporting_with_scenarios AS temp_a
    INNER JOIN report_date AS temp_b
        ON temp_a.reporting_date = LAST_DAY(DATE_ADD('month', -1, temp_b.reporting_date))::date
),

neo_mortgages AS (
    SELECT 
        temp_b.reporting_date::date AS ReportDate,
        temp_a.reporting_date::date AS CalcDate,
        loan_identifier::varchar AS Instrument_ID, 
        borrower_identifier::varchar AS User_ID,
        'Neo hypotheken'::varchar AS LegalEntity,
        'NLD'::varchar AS Country,
        ead AS OnBalance_EAD,
        undrawn_loanpart::decimal(10,2) AS OffBalance_EAD,
        date_of_loan_maturity AS MaturityDate,
        initial_pd / 100::float AS InitialPD,
        rating_class AS CurrentRating,
        one_year_pd / 100::float AS PD,
        CASE
            WHEN OnBalance_EAD < 0 THEN 0.05
            ELSE lgd_weighted / 100::float 
        END AS LGD,
        NULL AS limit,
        ifrs_stage AS Stage,
        ifrs_stage_reason AS stage_reason, -- Uncommented
        expected_credit_loss::float AS ECL_On,
        (PD * LGD * OffBalance_EAD)::decimal(10,2) AS ECL_Off,
        ROUND(mpd / 0.0329)::float AS dpd,
        NULL AS CCF,
        'yes' AS IS_IFRS, 
        'mortgage' AS Instrument_Type,
        'credit' AS Instrument
    -- Sourced from the newly updated Sept26 Neo table
    FROM credit_risk_playground.stg_mrt_neo_ifrs9_ecl_reporting_with_scenarios_Sept26 AS temp_a
    INNER JOIN report_date AS temp_b
        ON temp_a.reporting_date = LAST_DAY(DATE_ADD('month', -1, temp_b.reporting_date))::date
),

temp_tbl AS (
    SELECT * FROM rabo_mortgages 
    UNION (SELECT * FROM neo_mortgages)
)

SELECT 
    ReportDate,
    CalcDate,
    Instrument_ID, 
    User_ID,
    LegalEntity,
    Country,
    OnBalance_EAD,
    MaturityDate,
    InitialPD,
    CurrentRating,
    PD,
    LGD,
    "limit",
    Stage,
    ECL_On,
    dpd,
    CCF,
    IS_IFRS, 
    Instrument_Type,
    Instrument,
    GETDATE() AS etl_update,
    'alfred_teye_reader' AS created_by,
    OffBalance_EAD,
    ECL_Off,
    ifrs_stage_reason
FROM temp_tbl;



/*
DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26;

CREATE TABLE credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26 AS
SELECT 
    *,
    NULL::VARCHAR(255) AS ifrs_stage_reason,
    NULL::VARCHAR(50) AS forbearance_flag
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
WHERE reportdate <= '2026-07-31';
*/

DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V0;

CREATE TABLE credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V0 AS

WITH reporting_date AS (
    SELECT '2026-08-31'::date AS reportdate
),

temp_tbl AS (
    SELECT 
        a.reportdate,
        calcdate,
        instrument_id,
        user_id,
        legalentity,
        country,
        onbalance_ead,
        offbalance_ead,
        maturitydate,
        initialpd,
        currentrating,
        pd,
        lgd,
        "limit",
        stage,
        ifrs_stage_reason,
        ecl_on,
        ecl_off,
        dpd,
        ccf,
        is_ifrs,
        instrument_type,
        instrument,
        ROW_NUMBER() OVER(PARTITION BY instrument_id, user_id) AS dups
    FROM credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios_Sept26 AS a 
    INNER JOIN reporting_date AS b
        ON a.reportdate = b.reportdate
),

temp_tbl1 AS (
    SELECT 
        reportdate,
        calcdate,
        instrument_id,
        user_id,
        legalentity,
        country,
        onbalance_ead,
        offbalance_ead,
        maturitydate,
        initialpd,
        currentrating,
        pd,
        lgd,
        "limit",
        stage,
        ifrs_stage_reason,
        ecl_on,
        ecl_off,
        dpd,
        ccf,
        is_ifrs,
        instrument_type,
        instrument
    FROM temp_tbl 
    WHERE dups = 1
),

add_label AS (
    SELECT 
        a.*,
        CASE WHEN b.pool_identifier = '310' AND a.legalentity = 'Neo hypotheken' THEN 'Hypotheken B.V.' ELSE 'N26 Bank' END AS label
    FROM temp_tbl1 AS a
    LEFT JOIN (
        SELECT DISTINCT
            loan_identifier,
            pool_identifier
        FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw AS p 
        INNER JOIN reporting_date AS q
            ON p.pool_cut_off_date = LAST_DAY(DATE_ADD('month', -1, q.reportdate))::date 
    ) AS b
        ON a.instrument_id = b.loan_identifier
),

arrears_data AS (
    SELECT
         *,
         pool_cut_off_date AS reportdate
    FROM credit_risk_playground.stg_mrt_rabobank_arrears_list
    UNION ALL (SELECT *, pool_cut_off_date AS reportdate FROM credit_risk_playground.stg_mrt_neo_arrears_list)
),

default_date AS ( 
    SELECT 
        borrower_identifier, 
        MIN(reportdate) AS first_time_default,
        MAX(reportdate) AS last_time_default
    FROM arrears_data
    WHERE months_in_arrears = 'default'
    GROUP BY borrower_identifier  
),

extended_arrears_data AS (
    SELECT * FROM (
        SELECT 
            arr.*,
            df_dt.first_time_default,
            df_dt.last_time_default
        FROM arrears_data AS arr
        LEFT JOIN default_date AS df_dt
            USING(borrower_identifier)  
    ) AS a 
    INNER JOIN reporting_date AS b
        ON a.reportdate = LAST_DAY(DATE_ADD('month', -1, b.reportdate::date)::date)
),

ecl_data AS (
    SELECT 
        main.*,
        def.arrears_balance_customer_level,
        def.arrears_balance_ratio,
        def.months_in_arrears,
        def.first_date_in_arrears,
        def.last_arrears_info_date,
        def.first_time_default,
        def.last_time_default,
        fb.forbearance_flag -- Pulled from the new table
    FROM add_label AS main
    LEFT JOIN extended_arrears_data AS def
        ON main.user_id = def.borrower_identifier
        AND main.instrument_id = def.loan_identifier
    -- New join to fetch forbearance info
    LEFT JOIN credit_risk_playground.mrt_forbearance_records AS fb
        ON main.user_id = fb.borrower_identifier
        AND main.instrument_id = fb.loan_identifier
        AND LAST_DAY(DATE_ADD('month', -1, main.reportdate::date)::date) = fb.pool_cut_off_date
),

reg_reporting_appendix AS (
    SELECT 
        reportdate,
        calcdate,
        user_id AS entityno,
        instrument_id,
        instrument_type,
        instrument,
        user_id AS itemno,
        is_ifrs,
        CASE 
            WHEN label = 'N26 Bank' THEN 'EU'
            ELSE 'NLD'
        END AS country,
        label AS legalentity,
        instrument_type AS product_flag,
        onbalance_ead,
        offbalance_ead,
        onbalance_ead + offbalance_ead AS ead,
        0 AS isoffbalance,  
        CASE 
            WHEN stage = 3 AND pd < 1 THEN 18
            ELSE currentrating
        END AS currentrating,
        CASE 
            WHEN stage = 3 AND pd < 1 THEN 1
            ELSE pd
        END AS pd,
        CASE 
            WHEN 100 * initialpd <  0.01 THEN 1
            WHEN 100 * initialpd <= 0.04 THEN 2
            WHEN 100 * initialpd <= 0.09 THEN 3
            WHEN 100 * initialpd <= 0.15 THEN 4
            WHEN 100 * initialpd <= 0.23 THEN 5
            WHEN 100 * initialpd <= 0.38 THEN 6
            WHEN 100 * initialpd <= 0.73 THEN 7
            WHEN 100 * initialpd <= 1.42 THEN 8
            WHEN 100 * initialpd <= 2.25 THEN 9
            WHEN 100 * initialpd <= 3.21 THEN 10
            WHEN 100 * initialpd <= 4.29 THEN 11
            WHEN 100 * initialpd <= 5.61 THEN 12
            WHEN 100 * initialpd <= 11.18 THEN 13
            WHEN 100 * initialpd <= 27.89 THEN 14
            WHEN 100 * initialpd <= 46.00 THEN 15
            WHEN 100 * initialpd <= 60.86 THEN 16
            WHEN 100 * initialpd > 60.86 AND initialpd <= 99.99 THEN 17
            ELSE 18
        END AS initialrating,
        initialpd,
        dpd,
        ccf,
        lgd,
        maturitydate,
        stage,
        ifrs_stage_reason,
        forbearance_flag, -- Passed through
        ecl_on + ecl_off AS ecl,
        ecl_on,
        ecl_off,
        CASE 
            WHEN stage = 3 THEN 'J'
            ELSE 'N'
        END AS ausfl,
        CASE 
            WHEN stage = 3 THEN COALESCE(first_time_default, LAST_DAY(DATE_ADD('day', (dpd*-1)::int, calcdate)))   
            ELSE NULL 
        END AS adxaud,
        CASE 
            WHEN stage = 3 THEN 'C'
            WHEN stage = 2 THEN 'B' 
            ELSE 'A'
        END AS risgr,
        CASE 
            WHEN stage = 3 THEN first_time_default
            ELSE NULL 
        END AS dxnpe,
        NULL AS dxfbe,
        NULL AS fbsfi,
        CASE 
            WHEN stage = 3 THEN '1801'
            ELSE '1808'
        END AS imsfi,
        CASE 
            WHEN stage = 3 THEN '3292'
            WHEN months_in_arrears = 'probation' THEN '3294'
            ELSE '3293'
        END AS pfsfi,
        CASE 
            WHEN dpd IS NULL OR dpd <= 30 THEN '3295'
            WHEN dpd <= 90 THEN '5032'
            WHEN dpd <= 180 THEN '2792'
            WHEN dpd <= 365 THEN '2785'
            WHEN dpd <= 730 THEN '3280'
            ELSE '3282'
        END AS tpdfi,
        NULL AS scra_cluster,
        NULL AS due_dilligence
    FROM ecl_data
)
SELECT 
    reportdate::DATE,
    calcdate::DATE,  
    entityno::VARCHAR,
    instrument_id::VARCHAR,
    instrument_type::VARCHAR,
    instrument::VARCHAR,
    itemno::VARCHAR,
    is_ifrs::VARCHAR,
    country::VARCHAR,
    legalentity::VARCHAR,
    product_flag::VARCHAR,
    onbalance_ead::FLOAT, 
    offbalance_ead,
    ead::FLOAT,
    isoffbalance::INT,
    currentrating::INT,
    pd::FLOAT,
    initialrating::INT,
    initialpd::FLOAT, 
    dpd::INT,
    ccf,
    lgd::FLOAT,
    maturitydate::DATE,
    stage::INT,
    ecl::FLOAT, 
    ecl_on::FLOAT,
    ecl_off::VARCHAR,
    ausfl,
    adxaud,
    risgr,
    dxnpe,
    dxfbe,
    fbsfi,
    imsfi,
    pfsfi,
    tpdfi,
    scra_cluster,
    due_dilligence,
    ifrs_stage_reason::VARCHAR,
    forbearance_flag::VARCHAR -- Appended strictly to the very end of V0
FROM reg_reporting_appendix
ORDER BY itemno, instrument_id;

--- Insert into the final V3 target table
INSERT INTO credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26 
SELECT 
    'mortgage' AS portfolio,
    p.reportdate,
    p.calcdate AS calc_date,
    NULL AS entityno,
    CAST(p.instrument_id AS varchar) AS instrument_id,
    p.instrument_type,
    p.instrument,
    CAST(p.itemno AS varchar) AS itemno,
    p.is_ifrs,
    p.country,
    p.legalentity,
    p.instrument_type AS product_flag,
    COALESCE(p.onbalance_ead::float, 0) AS on_balance_ead,
    COALESCE(p.offbalance_ead::float, 0) AS off_balance_eod,
    COALESCE(p.onbalance_ead::float, 0) + COALESCE(p.offbalance_ead::float, 0) AS ead,
    0 AS isoffbalance,
    CAST(p.currentrating AS varchar) AS currentrating,
    p.pd,
    CAST(p.initialrating AS varchar) AS initialrating,
    p.initialpd AS initial_pd,
    p.dpd,
    TRY_CAST(p.ccf AS float) AS ccf,
    p.lgd,
    p.maturitydate,
    p.stage,
    p.ecl_on::float + COALESCE(p.ecl_off::float, 0) AS ecl,
    p.ecl_off::float AS ecl_off,
    p.ecl_on::float AS ecl_on,
    p.ausfl,
    p.adxaud AS dxaud,
    p.risgr,
    CAST(p.dxnpe AS date) AS dxnpe,
    CAST(p.dxfbe AS date) AS dxfbe,
    p.fbsfi::varchar AS fbsfi,
    p.imsfi::varchar AS imsfi,
    p.pfsfi::varchar AS pfsfi,
    p.tpdfi::varchar AS tpdfi,
    NULL AS scra_cluster,
    NULL AS due_dilligence,
    p.ifrs_stage_reason AS ifrs_stage_reason,
    p.forbearance_flag AS forbearance_flag -- Appended strictly to the very end of V3
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V0 p;

DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V0;

SELECT 
    old_v3.reportdate,
    old_v3.legalentity,
    old_v3.itemno AS borrower_identifier,
    old_v3.instrument_id AS loan_identifier,
    
    -- Stage comparison
    old_v3.stage AS old_stage,
    new_v3.stage AS new_stage,
    
    -- The new reason column to explain the migration
    new_v3.ifrs_stage_reason AS new_stage_reason,
    
    -- EAD comparison just to ensure balances map correctly
    old_v3.ead AS old_ead,
    new_v3.ead AS new_ead,
    old_v3.ecl AS old_ecl,
    new_v3.ecl AS new_ecl

FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 AS old_v3
JOIN credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26 AS new_v3
    ON old_v3.instrument_id = new_v3.instrument_id
    AND old_v3.itemno = new_v3.itemno
    AND old_v3.reportdate = new_v3.reportdate
    
WHERE old_v3.reportdate = '2026-08-31'
  -- Isolates only the records where the stage is different
  AND COALESCE(old_v3.stage, -1) <> COALESCE(new_v3.stage, -1)
ORDER BY old_v3.legalentity, old_v3.itemno;


select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26 
where reportdate = '2026-08-31'
limit 100;


select reportdate, calc_date, instrument_id, stage, ifrs_stage_reason, ecl, ead, forbearance_flag
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3_Sept26
where reportdate = '2026-08-31'
--and stage = 2
--and ifrs_stage_reason <> 'Unavailable'
and instrument_id = '2185742101'



select *
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
where reportdate = '2026-09-30'



SELECT * FROM credit_risk_playground.mrt_insurance_flag
LIMIT 100;






