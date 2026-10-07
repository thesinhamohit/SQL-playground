

-- 1. Base Loan & Part (BO)
WITH cte_loan AS (
    SELECT nr_lnng, nr_klnt
    FROM bo_loan_management_loan 
    WHERE etl_updated::DATE = '2026-08-31'
),
cte_loan_part AS (
    SELECT nr_lnng, nr_lnngdl, dtm_ing_lnngdl, dtm_eind_lnngdl, lptd_lnngdl, bedr_hfdsm_lnngdl, kd_aflswze_oms, aantl_mnd_rntevst, kd_gar, etl_updated
    FROM bo_loan_management_loan_part 
    WHERE etl_updated::DATE = '2026-08-31'
),
-- 2. Pool
cte_pool AS (
    SELECT nr_lnng, nr_lnngdl, nr_pool 
    FROM bo_account_management_pool_loan_part 
    WHERE etl_updated::DATE = '2026-08-31' 
      AND per_bkng_eind_pool IS NULL
),
-- 3. Payment Schedule
cte_term AS (
    SELECT nr_lnng, nr_lnngdl, bedr_trmn
    FROM bo_loan_management_loan_part_term_schedule 
    WHERE etl_updated::DATE = '2026-08-31' 
      AND dtm_eind_trmn >= '2050-01-01'
),
-- 4. Interest
cte_interest AS (
    SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn
    FROM (
        SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn, 
               ROW_NUMBER() OVER(PARTITION BY nr_lnng, nr_lnngdl ORDER BY dtm_ing_akternte ASC) as rn
        FROM bo_interest_specification_deed_interest_loan_part 
        WHERE etl_updated::DATE = '2026-08-31'
    ) WHERE rn = 1
),
-- 5. Arrears
cte_arrears_base AS (
    SELECT nr_lnng, MAX(per_bkng_ing_achtrstnd) AS per_bkng_ing_achtrstnd, MAX(kd_catgor_debtr_oms) AS kd_catgor_debtr_oms
    FROM bo_loan_arrears 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_arrears_balance AS (
    SELECT nr_lnng, MAX(sldo_achtrstnd) AS sldo_achtrstnd, MAX(wrde_aantl_mnd_achtr) AS wrde_aantl_mnd_achtr
    FROM bo_arrears_over_booking_period 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
-- 6. Deposits
cte_deposit AS (
    SELECT nr_lnng, SUM(bedr_dept) AS bedr_dept
    FROM bo_construction_deposit_available_credit 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
-- 7. Collateral & Valuation (BO)
cte_col_link AS (
    SELECT nr_lnng, MAX(vlgnr_ondrpnd) AS vlgnr_ondrpnd 
    FROM bo_collateral_loan_collateral 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_val AS (
    SELECT vlgnr_ondrpnd, bedr_vov
    FROM bo_collaterals_collateral_valuation 
    WHERE etl_updated::DATE = '2026-08-31'
),
-- 8. MO Applications & Credit Score
cte_mo_app1 AS (
    SELECT loannumber, loantomarketvalue, isemployee
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = '2026-08-31'
),
cte_mo_app2 AS (
    SELECT loannumber, appliedmarketvalue_total 
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = '2026-08-31'
),
cte_mo_part AS (
    SELECT loannumber, originalloanpartnumber, MAX(remainingdebtamount_cal) AS remainingdebtamount_cal, MAX(purpose) AS purpose
    FROM mo_loan_application_in_process_loan_part 
    WHERE applicationindexnumber = 2 
      AND origin != 'Deactivated' 
      AND etl_updated::DATE = '2026-08-31'
    GROUP BY loannumber, originalloanpartnumber
),
cte_mo_score AS (
    SELECT loannumber, MAX(testincome) AS testincome
    FROM mo_credit_check_credit_score 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = '2026-08-31' 
    GROUP BY loannumber
),
-- 9. Geographic Extractor (Raw Postal Code from BKR)
cte_geo AS (
    SELECT loannumber, 
           MAX(REGEXP_SUBSTR(searchkey, '[0-9]{4}[A-Za-z]{2}')) AS postal_code
    FROM mo_credit_check_bkr_application
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = '2026-08-31'
    GROUP BY loannumber
)

-- MAIN SELECT (Raw DWH Values)
SELECT 
    TO_CHAR(lp.etl_updated, 'YYYY-MM-DD') AS portfolio_date,
    pool.nr_pool AS pool_identifier,
    lp.nr_lnng AS loan_identifier_number,
    lp.nr_lnngdl AS loan_identifier_part,
    CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) AS loan_identifier,
    l.nr_klnt AS borrower_identifier,
    col.vlgnr_ondrpnd AS property_identifier,
    
    -- Geographic & Employment (Raw Values)
    geo.postal_code AS geographic_region_list,
    mo_app1.isemployee AS borrowers_employment_status,
    
    -- Income & Ratios (Native Numerics)
    score.testincome AS primary_income, 
    NULL AS secondary_income,
    (mo_part.remainingdebtamount_cal / NULLIF(score.testincome, 0)) AS debt_to_income,
    
    -- Dates & Terms (Native Formats)
    TO_CHAR(lp.dtm_ing_lnngdl, 'YYYY-MM-DD') AS loan_origination_date,
    TO_CHAR(lp.dtm_eind_lnngdl, 'YYYY-MM-DD') AS date_of_loan_maturity,
    lp.lptd_lnngdl AS loan_term,
    TO_CHAR(intr.dtm_rnte_herzn, 'YYYY-MM-DD') AS interest_revision_date_1,
    
    -- Balances & Payments (Native Numerics)
    lp.bedr_hfdsm_lnngdl AS original_balance,
    mo_part.remainingdebtamount_cal AS current_balance,
    dep.bedr_dept AS deposit_amount,
    ts.bedr_trmn AS payment_due,
    intr.perc_akternte AS current_interest_rate,
    lp.aantl_mnd_rntevst AS interest_rate_reset_interval,
    
    -- Arrears
    TO_CHAR(arr_base.per_bkng_ing_achtrstnd, 'YYYY-MM-DD') AS date_last_in_arrears,
    arr_bal.sldo_achtrstnd AS arrears_balance,
    arr_bal.wrde_aantl_mnd_achtr AS number_months_in_arrears,
    
    -- Valuations & LTV
    (mo_part.remainingdebtamount_cal / NULLIF(mo_app2.appliedmarketvalue_total, 0)) * 100 AS current_loan_to_value,
    mo_app2.appliedmarketvalue_total AS current_valuation_amount,
    mo_app1.loantomarketvalue AS original_loan_to_value,
    val.bedr_vov AS valuation_amount,
    
    -- Extracted Categorical Enums (Raw DWH Strings)
    mo_part.purpose AS purpose,
    lp.kd_aflswze_oms AS payment_type,
    arr_base.kd_catgor_debtr_oms AS account_status,
    lp.kd_gar AS type_of_guarantee_provider

FROM cte_loan_part lp
LEFT JOIN cte_loan l ON lp.nr_lnng = l.nr_lnng
LEFT JOIN cte_pool pool ON lp.nr_lnng = pool.nr_lnng AND lp.nr_lnngdl = pool.nr_lnngdl
LEFT JOIN cte_term ts ON lp.nr_lnng = ts.nr_lnng AND lp.nr_lnngdl = ts.nr_lnngdl
LEFT JOIN cte_interest intr ON lp.nr_lnng = intr.nr_lnng AND lp.nr_lnngdl = intr.nr_lnngdl
LEFT JOIN cte_arrears_base arr_base ON lp.nr_lnng = arr_base.nr_lnng
LEFT JOIN cte_arrears_balance arr_bal ON lp.nr_lnng = arr_bal.nr_lnng
LEFT JOIN cte_deposit dep ON lp.nr_lnng = dep.nr_lnng
LEFT JOIN cte_col_link col ON lp.nr_lnng = col.nr_lnng
LEFT JOIN cte_val val ON col.vlgnr_ondrpnd = val.vlgnr_ondrpnd
LEFT JOIN cte_mo_app1 mo_app1 ON lp.nr_lnng = mo_app1.loannumber
LEFT JOIN cte_mo_app2 mo_app2 ON lp.nr_lnng = mo_app2.loannumber
LEFT JOIN cte_mo_part mo_part ON lp.nr_lnng = mo_part.loannumber AND lp.nr_lnngdl = mo_part.originalloanpartnumber
LEFT JOIN cte_mo_score score ON lp.nr_lnng = score.loannumber
LEFT JOIN cte_geo geo ON lp.nr_lnng = geo.loannumber;








SELECT *
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-07-31'::DATE
    and nr_lnng = 2173981
order by nr_lnng, nr_lnngdl


WITH dwh_raw AS (
    -- Extracts native values directly from DWH for the target date
    SELECT 
        CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) AS loan_identifier,
        CAST(l.nr_klnt AS VARCHAR) AS borrower_identifier,
        CAST(col_link.vlgnr_ondrpnd AS VARCHAR) AS property_identifier,
        COALESCE(score.testincome, 0) AS total_income,
        lp.dtm_ing_lnngdl::DATE AS loan_orig_date,
        lp.dtm_eind_lnngdl::DATE AS loan_maturity,
        CAST(lp.lptd_lnngdl AS INT) AS loan_term,
        TO_CHAR(intr.dtm_rnte_herzn, 'YYYY-MM') AS interest_revision_date_yyyymm,
        COALESCE(lp.bedr_hfdsm_lnngdl, 0) AS original_balance,
        COALESCE(mo_part.remainingdebtamount_cal, 0) AS current_balance,
        COALESCE(dep.bedr_dept, 0) AS deposit_amt,
        COALESCE(intr.perc_akternte, 0) AS current_interest_rate,
        COALESCE(arr_bal.sldo_achtrstnd, 0) AS arrears_balance,
        COALESCE(arr_bal.wrde_aantl_mnd_achtr, 0) AS num_months_in_arrear,
        COALESCE(val.bedr_vov, 0) AS valuation_amt,
        COALESCE(mo_app2.appliedmarketvalue_total, 0) AS current_val_amt
    FROM bo_loan_management_loan_part lp
    LEFT JOIN bo_loan_management_loan l 
        ON lp.nr_lnng = l.nr_lnng AND l.etl_updated::DATE = '2026-08-31'
    LEFT JOIN (SELECT nr_lnng, nr_lnngdl, bedr_trmn FROM bo_loan_management_loan_part_term_schedule WHERE etl_updated::DATE = '2026-08-31' AND dtm_eind_trmn >= '2050-01-01') ts 
        ON lp.nr_lnng = ts.nr_lnng AND lp.nr_lnngdl = ts.nr_lnngdl
    LEFT JOIN (
        SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn, ROW_NUMBER() OVER(PARTITION BY nr_lnng, nr_lnngdl ORDER BY dtm_ing_akternte ASC) as rn
        FROM bo_interest_specification_deed_interest_loan_part WHERE etl_updated::DATE = '2026-08-31'
    ) intr 
        ON lp.nr_lnng = intr.nr_lnng AND lp.nr_lnngdl = intr.nr_lnngdl AND intr.rn = 1
    LEFT JOIN (SELECT nr_lnng, MAX(sldo_achtrstnd) AS sldo_achtrstnd, MAX(wrde_aantl_mnd_achtr) AS wrde_aantl_mnd_achtr FROM bo_arrears_over_booking_period WHERE etl_updated::DATE = '2026-08-31' GROUP BY nr_lnng) arr_bal 
        ON lp.nr_lnng = arr_bal.nr_lnng
    LEFT JOIN (SELECT nr_lnng, SUM(bedr_dept) AS bedr_dept FROM bo_construction_deposit_available_credit WHERE etl_updated::DATE = '2026-08-31' GROUP BY nr_lnng) dep 
        ON lp.nr_lnng = dep.nr_lnng
    LEFT JOIN (SELECT nr_lnng, MAX(vlgnr_ondrpnd) AS vlgnr_ondrpnd FROM bo_collateral_loan_collateral WHERE etl_updated::DATE = '2026-08-31' GROUP BY nr_lnng) col_link 
        ON lp.nr_lnng = col_link.nr_lnng
    LEFT JOIN bo_collaterals_collateral_valuation val 
        ON col_link.vlgnr_ondrpnd = val.vlgnr_ondrpnd AND val.etl_updated::DATE = '2026-08-31'
    LEFT JOIN (SELECT loannumber, originalloanpartnumber, MAX(remainingdebtamount_cal) AS remainingdebtamount_cal FROM mo_loan_application_in_process_loan_part WHERE applicationindexnumber = 2 AND origin != 'Deactivated' AND etl_updated::DATE = '2026-08-31' GROUP BY loannumber, originalloanpartnumber) mo_part 
        ON lp.nr_lnng = mo_part.loannumber AND lp.nr_lnngdl = mo_part.originalloanpartnumber
    LEFT JOIN (SELECT loannumber, MAX(appliedmarketvalue_total) AS appliedmarketvalue_total FROM mo_loan_application_in_process WHERE applicationindexnumber = 2 AND etl_updated::DATE = '2026-08-31' GROUP BY loannumber) mo_app2 
        ON lp.nr_lnng = mo_app2.loannumber
    LEFT JOIN (SELECT loannumber, MAX(testincome) AS testincome FROM mo_credit_check_credit_score WHERE applicationindexnumber = 1 AND etl_updated::DATE = '2026-08-31' GROUP BY loannumber) score 
        ON lp.nr_lnng = score.loannumber
    WHERE lp.etl_updated::DATE = '2026-08-31'
),

ecb_target AS (
    -- Normalizes ECB target table formats for comparison
    SELECT 
        loan_identifier,
        CAST(borrower_identifier AS VARCHAR) AS borrower_identifier,
        CAST(property_identifier AS VARCHAR) AS property_identifier,
        COALESCE(CAST(primary_income AS FLOAT), 0) + COALESCE(CAST(secondary_income AS FLOAT), 0) AS total_income,
        TO_DATE(loan_origination_date, 'Month DD, YYYY') AS loan_orig_date,
        TO_DATE(date_of_loan_maturity, 'Month DD, YYYY') AS loan_maturity,
        CAST(loan_term AS INT) AS loan_term,
        interest_revision_date_1 AS interest_revision_date_yyyymm,
        COALESCE(CAST(original_balance AS FLOAT), 0) AS original_balance,
        COALESCE(CAST(current_balance AS FLOAT), 0) AS current_balance,
        COALESCE(CAST(retained_amount AS FLOAT), 0) AS deposit_amt,
        COALESCE(CAST(current_interest_rate AS FLOAT), 0) AS current_interest_rate,
        COALESCE(CAST(arrears_balance AS FLOAT), 0) AS arrears_balance,
        COALESCE(CAST(number_months_in_arrears AS INT), 0) AS num_months_in_arrear,
        COALESCE(CAST(valuation_amount AS FLOAT), 0) AS valuation_amt,
        COALESCE(CAST(current_valuation_amount AS FLOAT), 0) AS current_val_amt
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2026-08-31'
),

row_by_row_diff AS (
    -- Compares row-by-row with strict matching rules (allowing minor float rounding)
    SELECT 
        d.loan_identifier,
        CASE WHEN d.borrower_identifier = e.borrower_identifier THEN 1 ELSE 0 END AS m_borrower,
        CASE WHEN d.property_identifier = e.property_identifier THEN 1 ELSE 0 END AS m_property,
        CASE WHEN ABS(d.total_income - e.total_income) < 1.0 THEN 1 ELSE 0 END AS m_income,
        CASE WHEN d.loan_orig_date = e.loan_orig_date THEN 1 ELSE 0 END AS m_orig_date,
        CASE WHEN d.loan_maturity = e.loan_maturity THEN 1 ELSE 0 END AS m_mat_date,
        CASE WHEN d.loan_term = e.loan_term THEN 1 ELSE 0 END AS m_term,
        CASE WHEN d.interest_revision_date_yyyymm = e.interest_revision_date_yyyymm THEN 1 ELSE 0 END AS m_rev_date,
        CASE WHEN ABS(d.original_balance - e.original_balance) < 1.0 THEN 1 ELSE 0 END AS m_orig_bal,
        CASE WHEN ABS(d.current_balance - e.current_balance) < 1.0 THEN 1 ELSE 0 END AS m_curr_bal,
        CASE WHEN ABS(d.deposit_amt - e.deposit_amt) < 1.0 THEN 1 ELSE 0 END AS m_dep_amt,
        CASE WHEN ABS(d.current_interest_rate - e.current_interest_rate) < 0.01 THEN 1 ELSE 0 END AS m_int_rate,
        CASE WHEN ABS(d.arrears_balance - e.arrears_balance) < 1.0 THEN 1 ELSE 0 END AS m_arr_bal,
        CASE WHEN d.num_months_in_arrear = e.num_months_in_arrear THEN 1 ELSE 0 END AS m_arr_months,
        CASE WHEN ABS(d.valuation_amt - e.valuation_amt) < 1.0 THEN 1 ELSE 0 END AS m_val_amt,
        CASE WHEN ABS(d.current_val_amt - e.current_val_amt) < 1.0 THEN 1 ELSE 0 END AS m_curr_val
    FROM dwh_raw d
    INNER JOIN ecb_target e ON d.loan_identifier = e.loan_identifier
)

-- AGGREGATED VALIDATION SUMMARY
SELECT 
    COUNT(*) AS total_loans_analyzed,
    
    SUM(m_borrower) AS match_borrower_id,
    COUNT(*) - SUM(m_borrower) AS mismatch_borrower_id,
    
    SUM(m_property) AS match_property_id,
    COUNT(*) - SUM(m_property) AS mismatch_property_id,
    
    SUM(m_income) AS match_total_income,
    COUNT(*) - SUM(m_income) AS mismatch_total_income,
    
    SUM(m_orig_date) AS match_orig_date,
    COUNT(*) - SUM(m_orig_date) AS mismatch_orig_date,
    
    SUM(m_mat_date) AS match_maturity_date,
    COUNT(*) - SUM(m_mat_date) AS mismatch_maturity_date,
    
    SUM(m_term) AS match_loan_term,
    COUNT(*) - SUM(m_term) AS mismatch_loan_term,
    
    SUM(m_rev_date) AS match_revision_date,
    COUNT(*) - SUM(m_rev_date) AS mismatch_revision_date,
    
    SUM(m_orig_bal) AS match_orig_balance,
    COUNT(*) - SUM(m_orig_bal) AS mismatch_orig_balance,
    
    SUM(m_curr_bal) AS match_curr_balance,
    COUNT(*) - SUM(m_curr_bal) AS mismatch_curr_balance,
    
    SUM(m_dep_amt) AS match_deposit_amt,
    COUNT(*) - SUM(m_dep_amt) AS mismatch_deposit_amt,
    
    SUM(m_int_rate) AS match_int_rate,
    COUNT(*) - SUM(m_int_rate) AS mismatch_int_rate,
    
    SUM(m_arr_bal) AS match_arrears_balance,
    COUNT(*) - SUM(m_arr_bal) AS mismatch_arrears_balance,
    
    SUM(m_arr_months) AS match_arrears_months,
    COUNT(*) - SUM(m_arr_months) AS mismatch_arrears_months,
    
    SUM(m_val_amt) AS match_valuation_amt,
    COUNT(*) - SUM(m_val_amt) AS mismatch_valuation_amt,
    
    SUM(m_curr_val) AS match_current_val_amt,
    COUNT(*) - SUM(m_curr_val) AS mismatch_current_val_amt

FROM row_by_row_diff;


WITH dwh_loans AS (
    SELECT DISTINCT CONCAT(CAST(nr_lnng AS VARCHAR), CAST(nr_lnngdl AS VARCHAR)) AS loan_identifier
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-08-31'
),
ecb_loans AS (
    SELECT DISTINCT loan_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2026-08-31'
)
SELECT 
    COUNT(d.loan_identifier) AS total_in_dwh,
    COUNT(e.loan_identifier) AS total_in_ecb,
    COUNT(CASE WHEN e.loan_identifier IS NULL THEN 1 END) AS missing_in_ecb,
    COUNT(CASE WHEN d.loan_identifier IS NULL THEN 1 END) AS extra_in_ecb
FROM dwh_loans d
FULL OUTER JOIN ecb_loans e ON d.loan_identifier = e.loan_identifier;


WITH dwh_raw AS (
    SELECT 
        CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) AS loan_identifier,
        COALESCE(lp.bedr_hfdsm_lnngdl, 0) AS dwh_original_balance
    FROM bo_loan_management_loan_part lp
    WHERE lp.etl_updated::DATE = '2026-08-31'
),
ecb_target AS (
    SELECT 
        loan_identifier,
        COALESCE(CAST(original_balance AS FLOAT), 0) AS ecb_original_balance
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2026-08-31'
)
SELECT 
    d.loan_identifier,
    d.dwh_original_balance,
    e.ecb_original_balance,
    (d.dwh_original_balance - e.ecb_original_balance) AS balance_difference
FROM dwh_raw d
INNER JOIN ecb_target e ON d.loan_identifier = e.loan_identifier
WHERE ABS(d.dwh_original_balance - e.ecb_original_balance) >= 1.0
ORDER BY ABS(d.dwh_original_balance - e.ecb_original_balance) DESC;


    SELECT DISTINCT CONCAT(CAST(nr_lnng AS VARCHAR), CAST(nr_lnngdl AS VARCHAR)) AS loan_identifier
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-08-31'
    
    
WITH dwh_loans AS (
    SELECT DISTINCT CONCAT(CAST(nr_lnng AS VARCHAR), CAST(nr_lnngdl AS VARCHAR)) AS loan_identifier
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-08-31'
),
ecb_loans AS (
    SELECT DISTINCT loan_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2026-08-31'
)
SELECT 
    COALESCE(d.loan_identifier, e.loan_identifier) AS loan_identifier,
    CASE 
        WHEN e.loan_identifier IS NULL THEN 'In DWH, Missing in ESMA (The 1405)'
        WHEN d.loan_identifier IS NULL THEN 'In ESMA, Missing in DWH (The 6)'
    END AS discrepancy_type
FROM dwh_loans d
FULL OUTER JOIN ecb_loans e ON d.loan_identifier = e.loan_identifier
WHERE d.loan_identifier IS NULL OR e.loan_identifier IS NULL
ORDER BY discrepancy_type, loan_identifier;


WITH cte_loan AS (
    SELECT nr_lnng, nr_klnt
    FROM bo_loan_management_loan 
    WHERE etl_updated::DATE = '2026-08-31'
),
cte_loan_part AS (
    SELECT nr_lnng, nr_lnngdl, dtm_ing_lnngdl, dtm_eind_lnngdl, lptd_lnngdl, bedr_hfdsm_lnngdl, kd_aflswze_oms, aantl_mnd_rntevst, kd_gar, etl_updated
    FROM bo_loan_management_loan_part 
    WHERE etl_updated::DATE = '2026-08-31'
),
cte_pool AS (
    SELECT nr_lnng, nr_lnngdl, nr_pool 
    FROM bo_account_management_pool_loan_part 
    WHERE etl_updated::DATE = '2026-08-31' 
      AND per_bkng_eind_pool IS NULL
),
cte_term AS (
    SELECT nr_lnng, nr_lnngdl, bedr_trmn
    FROM bo_loan_management_loan_part_term_schedule 
    WHERE etl_updated::DATE = '2026-08-31' 
      AND dtm_eind_trmn >= '2050-01-01'
),
cte_interest AS (
    SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn
    FROM (
        SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn, 
               ROW_NUMBER() OVER(PARTITION BY nr_lnng, nr_lnngdl ORDER BY dtm_ing_akternte ASC) as rn
        FROM bo_interest_specification_deed_interest_loan_part 
        WHERE etl_updated::DATE = '2026-08-31'
    ) WHERE rn = 1
),
cte_arrears_base AS (
    SELECT nr_lnng, MAX(per_bkng_ing_achtrstnd) AS per_bkng_ing_achtrstnd, MAX(kd_catgor_debtr_oms) AS kd_catgor_debtr_oms
    FROM bo_loan_arrears 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_arrears_balance AS (
    SELECT nr_lnng, MAX(sldo_achtrstnd) AS sldo_achtrstnd, MAX(wrde_aantl_mnd_achtr) AS wrde_aantl_mnd_achtr
    FROM bo_arrears_over_booking_period 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_deposit AS (
    SELECT nr_lnng, SUM(bedr_dept) AS bedr_dept
    FROM bo_construction_deposit_available_credit 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_col_link AS (
    SELECT nr_lnng, MAX(vlgnr_ondrpnd) AS vlgnr_ondrpnd 
    FROM bo_collateral_loan_collateral 
    WHERE etl_updated::DATE = '2026-08-31' 
    GROUP BY nr_lnng
),
cte_val AS (
    SELECT vlgnr_ondrpnd, bedr_vov
    FROM bo_collaterals_collateral_valuation 
    WHERE etl_updated::DATE = '2026-08-31'
),
cte_mo_app1 AS (
    SELECT loannumber, loantomarketvalue, isemployee
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = '2026-08-31'
),
cte_mo_app2 AS (
    SELECT loannumber, appliedmarketvalue_total 
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = '2026-08-31'
),
cte_mo_part AS (
    SELECT loannumber, originalloanpartnumber, MAX(remainingdebtamount_cal) AS remainingdebtamount_cal, MAX(purpose) AS purpose
    FROM mo_loan_application_in_process_loan_part 
    WHERE applicationindexnumber = 2 
      AND origin != 'Deactivated' 
      AND etl_updated::DATE = '2026-08-31'
    GROUP BY loannumber, originalloanpartnumber
),
cte_mo_score AS (
    SELECT loannumber, MAX(testincome) AS testincome
    FROM mo_credit_check_credit_score 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = '2026-08-31' 
    GROUP BY loannumber
),
cte_geo AS (
    SELECT loannumber, 
           MAX(REGEXP_SUBSTR(searchkey, '[0-9]{4}[A-Za-z]{2}')) AS postal_code
    FROM mo_credit_check_bkr_application
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = '2026-08-31'
    GROUP BY loannumber
)

SELECT 
    TO_CHAR(lp.etl_updated, 'YYYY-MM-DD') AS portfolio_date,
    pool.nr_pool AS pool_identifier,
    lp.nr_lnng AS loan_identifier_number,
    lp.nr_lnngdl AS loan_identifier_part,
    CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) AS loan_identifier,
    l.nr_klnt AS borrower_identifier,
    col_link.vlgnr_ondrpnd AS property_identifier,
    geo.postal_code AS geographic_region_list,
    mo_app1.isemployee AS borrowers_employment_status,
    score.testincome AS primary_income, 
    NULL AS secondary_income,
    (mo_part.remainingdebtamount_cal / NULLIF(score.testincome, 0)) AS debt_to_income,
    TO_CHAR(lp.dtm_ing_lnngdl, 'YYYY-MM-DD') AS loan_origination_date,
    TO_CHAR(lp.dtm_eind_lnngdl, 'YYYY-MM-DD') AS date_of_loan_maturity,
    lp.lptd_lnngdl AS loan_term,
    TO_CHAR(intr.dtm_rnte_herzn, 'YYYY-MM-DD') AS interest_revision_date_1,
    lp.bedr_hfdsm_lnngdl AS original_balance,
    mo_part.remainingdebtamount_cal AS current_balance,
    dep.bedr_dept AS deposit_amount,
    ts.bedr_trmn AS payment_due,
    intr.perc_akternte AS current_interest_rate,
    lp.aantl_mnd_rntevst AS interest_rate_reset_interval,
    TO_CHAR(arr_base.per_bkng_ing_achtrstnd, 'YYYY-MM-DD') AS date_last_in_arrears,
    arr_bal.sldo_achtrstnd AS arrears_balance,
    arr_bal.wrde_aantl_mnd_achtr AS number_months_in_arrears,
    (mo_part.remainingdebtamount_cal / NULLIF(mo_app2.appliedmarketvalue_total, 0)) * 100 AS current_loan_to_value,
    mo_app2.appliedmarketvalue_total AS current_valuation_amount,
    mo_app1.loantomarketvalue AS original_loan_to_value,
    val.bedr_vov AS valuation_amount,
    mo_part.purpose AS purpose,
    lp.kd_aflswze_oms AS payment_type,
    arr_base.kd_catgor_debtr_oms AS account_status,
    lp.kd_gar AS type_of_guarantee_provider

FROM cte_loan_part lp
LEFT JOIN cte_loan l ON lp.nr_lnng = l.nr_lnng
LEFT JOIN cte_pool pool ON lp.nr_lnng = pool.nr_lnng AND lp.nr_lnngdl = pool.nr_lnngdl
LEFT JOIN cte_term ts ON lp.nr_lnng = ts.nr_lnng AND lp.nr_lnngdl = ts.nr_lnngdl
LEFT JOIN cte_interest intr ON lp.nr_lnng = intr.nr_lnng AND lp.nr_lnngdl = intr.nr_lnngdl
LEFT JOIN cte_arrears_base arr_base ON lp.nr_lnng = arr_base.nr_lnng
LEFT JOIN cte_arrears_balance arr_bal ON lp.nr_lnng = arr_bal.nr_lnng
LEFT JOIN cte_deposit dep ON lp.nr_lnng = dep.nr_lnng
LEFT JOIN cte_col_link col_link ON lp.nr_lnng = col_link.nr_lnng
LEFT JOIN cte_val val ON col_link.vlgnr_ondrpnd = val.vlgnr_ondrpnd
LEFT JOIN cte_mo_app1 mo_app1 ON lp.nr_lnng = mo_app1.loannumber
LEFT JOIN cte_mo_app2 mo_app2 ON lp.nr_lnng = mo_app2.loannumber
LEFT JOIN cte_mo_part mo_part ON lp.nr_lnng = mo_part.loannumber AND lp.nr_lnngdl = mo_part.originalloanpartnumber
LEFT JOIN cte_mo_score score ON lp.nr_lnng = score.loannumber
LEFT JOIN cte_geo geo ON lp.nr_lnng = geo.loannumber
-- FILTER ONLY TO MISSING LOANS
WHERE CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) NOT IN (
    SELECT loan_identifier 
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw 
    WHERE pool_cut_off_date = '2026-08-31'
);


SELECT *
FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
WHERE pool_cut_off_date = '2026-08-31'
  AND loan_identifier NOT IN (
      SELECT CONCAT(CAST(nr_lnng AS VARCHAR), CAST(nr_lnngdl AS VARCHAR))
      FROM bo_loan_management_loan_part
      WHERE etl_updated::DATE = '2026-08-31'
  );







