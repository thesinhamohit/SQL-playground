

WITH target_params AS (
    SELECT 
        2173981 AS target_loan,
        101 AS target_loan_part,
        '2026-07-31'::DATE AS target_date
),
-- 1. Base Loan & Part (BO)
cte_loan AS (
    SELECT nr_lnng, nr_klnt, nm_gldgvr_offrte 
    FROM bo_loan_management_loan 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params)
),
cte_loan_part AS (
    SELECT nr_lnng, nr_lnngdl, dtm_ing_lnngdl, dtm_eind_lnngdl, lptd_lnngdl, bedr_hfdsm_lnngdl, kd_aflswze_oms, aantl_mnd_rntevst, kd_gar, kd_gar_oms
    FROM bo_loan_management_loan_part 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params)
),
-- 2. Pool
cte_pool AS (
    SELECT nr_lnng, nr_lnngdl, nr_pool 
    FROM bo_account_management_pool_loan_part 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
      AND per_bkng_eind_pool IS NULL
),
-- 3. Payment Schedule
cte_term AS (
    SELECT nr_lnng, nr_lnngdl, bedr_trmn
    FROM bo_loan_management_loan_part_term_schedule 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
      AND dtm_eind_trmn >= '2050-01-01'
),
-- 4. Interest
cte_interest AS (
    SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn
    FROM (
        SELECT nr_lnng, nr_lnngdl, perc_akternte, dtm_rnte_herzn, 
               ROW_NUMBER() OVER(PARTITION BY nr_lnng, nr_lnngdl ORDER BY dtm_ing_akternte ASC) as rn
        FROM bo_interest_specification_deed_interest_loan_part 
        WHERE etl_updated::DATE = (SELECT target_date FROM target_params)
    ) WHERE rn = 1
),
-- 5. Arrears
cte_arrears_base AS (
    SELECT nr_lnng, MAX(per_bkng_ing_achtrstnd) AS per_bkng_ing_achtrstnd, MAX(kd_catgor_debtr) AS kd_catgor_debtr
    FROM bo_loan_arrears 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
    GROUP BY nr_lnng
),
cte_arrears_balance AS (
    SELECT nr_lnng, MAX(sldo_achtrstnd) AS sldo_achtrstnd, MAX(wrde_aantl_mnd_achtr) AS wrde_aantl_mnd_achtr
    FROM bo_arrears_over_booking_period 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
    GROUP BY nr_lnng
),
-- 6. Deposits
cte_deposit AS (
    SELECT nr_lnng, SUM(bedr_dept) AS bedr_dept
    FROM bo_construction_deposit_available_credit 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
    GROUP BY nr_lnng
),
-- 7. Collateral & Valuation (BO)
cte_col_link AS (
    SELECT nr_lnng, MAX(vlgnr_ondrpnd) AS vlgnr_ondrpnd 
    FROM bo_collateral_loan_collateral 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params) 
    GROUP BY nr_lnng
),
cte_val AS (
    SELECT vlgnr_ondrpnd, bedr_vov, dtm_tax 
    FROM bo_collaterals_collateral_valuation 
    WHERE etl_updated::DATE = (SELECT target_date FROM target_params)
),
-- 8. MO Applications & Credit Score
cte_mo_app1 AS (
    SELECT loannumber, loantomarketvalue, isemployee
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = (SELECT target_date FROM target_params)
),
cte_mo_app2 AS (
    SELECT loannumber, appliedmarketvalue_total 
    FROM mo_loan_application_in_process 
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = (SELECT target_date FROM target_params)
),
cte_mo_part AS (
    SELECT loannumber, originalloanpartnumber, MAX(remainingdebtamount_cal) AS remainingdebtamount_cal, MAX(purpose) AS purpose
    FROM mo_loan_application_in_process_loan_part 
    WHERE applicationindexnumber = 2 
      AND origin != 'Deactivated' 
      AND etl_updated::DATE = (SELECT target_date FROM target_params)
    GROUP BY loannumber, originalloanpartnumber
),
cte_mo_col AS (
    SELECT loannumber, purchaseprice, issurfacerented, typeofrealestate, valuationdate 
    -- REMOVED 'zipcode' as it does not exist in your Redshift DDL
    FROM mo_collateral_collateral 
    WHERE applicationindexnumber = 2 
      AND etl_updated::DATE = (SELECT target_date FROM target_params)
),
cte_mo_score AS (
    SELECT loannumber, MAX(testincome) AS testincome
    FROM mo_credit_check_credit_score 
    WHERE applicationindexnumber = 1 
      AND etl_updated::DATE = (SELECT target_date FROM target_params) 
    GROUP BY loannumber
)

-- MAIN SELECT MINIMAL REQUIRED COLUMNS
SELECT 
    '2026-07-31' AS pool_cut_off_date,
    COALESCE(CAST(pool.nr_pool AS VARCHAR), 'ND5') AS pool_identifier,
    CAST(lp.nr_lnng AS VARCHAR) AS loan_identifier_number,
    CAST(lp.nr_lnngdl AS VARCHAR) AS loan_identifier_part,
    CONCAT(CAST(lp.nr_lnng AS VARCHAR), CAST(lp.nr_lnngdl AS VARCHAR)) AS loan_identifier,
    CAST(l.nr_klnt AS VARCHAR) AS borrower_identifier,
    CAST(col.vlgnr_ondrpnd AS VARCHAR) AS property_identifier,
    
    -- Geographic Mapping (Hardcoded to NL350 due to missing zipcode column in MO)
    'NL350' AS geographic_region_list,
    
    -- Employment Status Mapping
    CASE 
        WHEN mo_app1.isemployee = 'T' THEN 'EMRS' 
        WHEN mo_app1.isemployee = 'F' THEN 'EMUK' 
        ELSE 'ND5' 
    END AS borrowers_employment_status,
    
    -- Income & Ratios
    CAST(ROUND(score.testincome, 3) AS VARCHAR) AS primary_income, 
    '0.000' AS secondary_income,
    CAST(ROUND((mo_part.remainingdebtamount_cal / NULLIF(score.testincome, 0)), 3) AS VARCHAR) AS debt_to_income,
    
    -- Dates & Terms
    TO_CHAR(lp.dtm_ing_lnngdl, 'YYYY-MM-DD') AS loan_origination_date,
    TO_CHAR(lp.dtm_eind_lnngdl, 'YYYY-MM-DD') AS date_of_loan_maturity,
    CAST(lp.lptd_lnngdl AS VARCHAR) AS loan_term,
    TO_CHAR(intr.dtm_rnte_herzn, 'YYYY-MM-DD') AS interest_revision_date_1,
    
    -- Balances & Payments
    CAST(ROUND(lp.bedr_hfdsm_lnngdl, 3) AS VARCHAR) AS original_balance,
    CAST(ROUND(mo_part.remainingdebtamount_cal, 3) AS VARCHAR) AS current_balance,
    COALESCE(CAST(dep.bedr_dept AS VARCHAR), '0.00') AS deposit_amount,
    CAST(ROUND(ts.bedr_trmn, 3) AS VARCHAR) AS payment_due,
    CAST(ROUND(intr.perc_akternte, 3) AS VARCHAR) AS current_interest_rate,
    CAST(lp.aantl_mnd_rntevst AS VARCHAR) AS interest_rate_reset_interval,
    
    -- Arrears
    COALESCE(TO_CHAR(arr_base.per_bkng_ing_achtrstnd, 'YYYY-MM-DD'), 'ND5') AS date_last_in_arrears,
    COALESCE(CAST(arr_bal.sldo_achtrstnd AS VARCHAR), '0') AS arrears_balance,
    COALESCE(CAST(arr_bal.wrde_aantl_mnd_achtr AS VARCHAR), '0') AS number_months_in_arrears,
    
    -- Valuations & LTV
    CAST(ROUND((mo_part.remainingdebtamount_cal / mo_app2.appliedmarketvalue_total) * 100, 3) AS VARCHAR) AS current_loan_to_value,
    CAST(ROUND(mo_app2.appliedmarketvalue_total, 3) AS VARCHAR) AS current_valuation_amount,
    CAST(ROUND(mo_app1.loantomarketvalue, 3) AS VARCHAR) AS original_loan_to_value,
    CAST(ROUND(val.bedr_vov, 3) AS VARCHAR) AS valuation_amount,
    
    -- Regulatory Enums
    CASE WHEN mo_part.purpose = 'Standard' THEN 'PURC' ELSE 'ND5' END AS purpose,
    CASE WHEN lp.kd_aflswze_oms = 'Annuïteit' THEN 'FRXX' ELSE 'ND5' END AS payment_type,
    CASE WHEN arr_base.kd_catgor_debtr = 'N' THEN 'PERF' ELSE 'ND5' END AS account_status,
    CASE WHEN lp.kd_gar = 'NHG' THEN '7' ELSE '0' END AS type_of_guarantee_provider

FROM cte_loan_part lp
INNER JOIN target_params tp ON lp.nr_lnng = tp.target_loan AND lp.nr_lnngdl = tp.target_loan_part
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
LEFT JOIN cte_mo_col mo_col ON lp.nr_lnng = mo_col.loannumber
LEFT JOIN cte_mo_score score ON lp.nr_lnng = score.loannumber;




SELECT *
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-07-31'::DATE
    and nr_lnng = 2173981
order by nr_lnng, nr_lnngdl


SELECT *
    FROM bo_loan_management_loan_part
    WHERE etl_updated::DATE = '2026-08-31'::DATE
    and nr_lnng = 2173981
order by nr_lnng, nr_lnngdl


select *
from credit_risk_playground.stg_mrt_neo_esme_raw
WHERE pool_cut_off_date = '2026-07-31'
and loan_identifier_number = '2173981'









