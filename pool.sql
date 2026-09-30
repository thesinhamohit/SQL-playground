

SELECT borrower_identifier, loan_identifier, property_identifier
FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw

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

select * from credit_risk_playground.stg_mrt_neo_esme_raw
where pool_cut_off_date = '2026-07-31'
--and loan_identifier = '2263216103'
and borrower_identifier = '5610528'
order by loan_origination_date 

select pool_identifier, count(*) from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
group by 1


SELECT * FROM pooldownload_ln_310
where loannumber = 2263216
LIMIT 100;

WITH latest_cut_off AS (
    -- Step 1: Determine the latest cut_off_date from the LP table
    SELECT MAX(CAST(cut_off_date AS DATE)) AS max_date
    FROM pooldownload_lp_310
),

target_risk_cut_off AS (
    -- Step 2: Go back 1 calendar month and take the last day of that month
    SELECT 
        LAST_DAY(DATEADD(month, -1, max_date)) AS risk_reporting_date
    FROM latest_cut_off
),

ranked_loan_parts AS (
    -- Step 3: Rank each loan part per main loan number (1, 2, 3...)
    SELECT 
        lp.*,
        ROW_NUMBER() OVER (
            PARTITION BY lp.loannumber 
            ORDER BY lp.loanpartnumber ASC
        ) AS lp_rank
    FROM pooldownload_lp_310 lp
    INNER JOIN target_risk_cut_off r 
        ON CAST(lp.cut_off_date AS DATE) = r.risk_reporting_date
),

clean_loan_level_data AS (
    -- Step 4: Clean deposits and extra fields from LN 310
    SELECT 
        TRIM(ln.loannumber::varchar) AS loannumber,
        CAST(ln.cut_off_date AS DATE) AS cut_off_date,
        
        -- Deposits
        COALESCE(NULLIF(TRIM(REPLACE(ln.construction_deposit::varchar, ',', '.')), '')::numeric, 0) AS construction_deposit,
        COALESCE(NULLIF(TRIM(REPLACE(ln.sustainability_deposit::varchar, ',', '.')), '')::numeric, 0) AS sustainability_deposit,
        
        -- Extra gevraagde kolommen uit LN 310
        ln.guarantor_type_loan,
        TRY_CAST(NULLIF(TRIM(REPLACE(ln.latest_loan_to_market_value_balance::varchar, ',', '.')), '') AS NUMERIC) AS latest_loan_to_market_value_balance,
        TRY_CAST(NULLIF(TRIM(REPLACE(ln.latest_loan_to_income_balance::varchar, ',', '.')), '') AS NUMERIC) AS latest_loan_to_income_balance,
        TRY_CAST(NULLIF(TRIM(REPLACE(ln.arrears_amount::varchar, ',', '.')), '') AS NUMERIC) AS arrears_amount

    FROM pooldownload_ln_310 ln
    INNER JOIN target_risk_cut_off r 
        ON CAST(ln.cut_off_date AS DATE) = r.risk_reporting_date
)

-- Step 5: Final output (net_loan removed, savings_value & insurance_company excluded)
SELECT 
    p.loannumber,
    p.loanpartnumber,
    p.cut_off_date,
    p.lp_rank,
    
    TRY_CAST(NULLIF(TRIM(REPLACE(p.balance::varchar, ',', '.')), '') AS NUMERIC) AS balance,
    
    -- Depots toegewezen aan 1e leningdeel
    CASE 
        WHEN p.lp_rank = 1 THEN COALESCE(ln.construction_deposit, 0)
        ELSE 0 
    END AS construction_deposit_allocated,
    
    CASE 
        WHEN p.lp_rank = 1 THEN COALESCE(ln.sustainability_deposit, 0)
        ELSE 0 
    END AS sustainability_deposit_allocated,

    -- Extra velden uit LN 310
    ln.guarantor_type_loan,
    ln.latest_loan_to_market_value_balance,
    ln.latest_loan_to_income_balance,
    ln.arrears_amount

FROM ranked_loan_parts p
LEFT JOIN clean_loan_level_data ln 
    ON TRIM(p.loannumber::varchar) = ln.loannumber
   AND CAST(p.cut_off_date AS DATE) = ln.cut_off_date
where p.loannumber = 2263216;



WITH latest_loan_part AS (
    SELECT nr_lnng, nr_lnngdl, bedr_hfdsm_lnngdl
    FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
),
latest_loan AS (
    SELECT nr_lnng, nr_klnt
    FROM bo_loan_management_loan
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan)
),
/*
latest_customer AS (
    SELECT nr_klnt, nr_pers
    FROM reference_crm_customer_person
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM reference_crm_customer_person)
      AND ind_hfd_geadrssrd = 'J' -- Filter added to ensure 1:1 mapping (Primary Applicant only)
),
*/
latest_pool AS (
    SELECT nr_lnng, nr_lnngdl, nr_pool
    FROM bo_account_management_pool_loan_part
    WHERE nr_pool IN (310, 316)
      AND etl_updated = (SELECT MAX(etl_updated) FROM bo_account_management_pool_loan_part)
),
latest_balance AS (
    SELECT nr_lnng, nr_lnngdl, bedr_schldrst_lnngdl
    FROM bo_loan_management_original_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_original_loan_part)
),
latest_interest AS (
    SELECT nr_lnng, nr_lnngdl, perc_akternte
    FROM bo_interest_specification_deed_interest_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_interest_specification_deed_interest_loan_part)
),
latest_collateral_link AS (
    SELECT nr_lnng, vlgnr_ondrpnd
    FROM bo_collateral_loan_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
),
latest_valuation AS (
    SELECT vlgnr_ondrpnd, bedr_vov
    FROM bo_collaterals_collateral_valuation
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
),
latest_deposit AS (
    SELECT nr_lnng, bedr_dept, kd_dept_oms
    FROM bo_construction_deposit_deposit
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_construction_deposit_deposit)
)

SELECT 
    lp.nr_lnng,
    lp.nr_lnngdl,
--    cp.nr_pers,
    pool.nr_pool,
    cl.vlgnr_ondrpnd AS collateral_identifier,
    lp.bedr_hfdsm_lnngdl AS original_loan_part_balance,
    bal.bedr_schldrst_lnngdl AS current_balance,
    intr.perc_akternte AS interest_rate,
    val.bedr_vov AS collateral_valuation,
    dep.kd_dept_oms AS deposit_type,
    dep.bedr_dept AS deposit_amount
FROM 
    latest_loan_part AS lp
INNER JOIN 
    latest_pool AS pool 
    ON lp.nr_lnng = pool.nr_lnng AND lp.nr_lnngdl = pool.nr_lnngdl
LEFT JOIN 
    latest_loan AS l 
    ON lp.nr_lnng = l.nr_lnng
/*
LEFT JOIN 
    latest_customer AS cp 
    ON l.nr_klnt = cp.nr_klnt
*/
LEFT JOIN 
    latest_balance AS bal 
    ON lp.nr_lnng = bal.nr_lnng AND lp.nr_lnngdl = bal.nr_lnngdl
LEFT JOIN 
    latest_interest AS intr 
    ON lp.nr_lnng = intr.nr_lnng AND lp.nr_lnngdl = intr.nr_lnngdl
LEFT JOIN 
    latest_collateral_link AS cl 
    ON lp.nr_lnng = cl.nr_lnng
LEFT JOIN 
    latest_valuation AS val 
    ON cl.vlgnr_ondrpnd = val.vlgnr_ondrpnd
LEFT JOIN 
    latest_deposit AS dep 
    ON lp.nr_lnng = dep.nr_lnng
	
where lp.nr_lnng = 2263216;



    SELECT nr_lnng, bedr_dept, kd_dept_oms
    FROM bo_construction_deposit_deposit
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_construction_deposit_deposit)
    and nr_lnng = 2263216;


select * from bo_loan_management_loan
where etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan)
and nr_lnng = 2263216
limit 100;

select count(nr_lnng) from bo_collateral_loan_collateral
where etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
limit 100;

select count(distinct nr_lnng) from bo_loan_management_loan_part
where etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
--and nr_lnng = 2263216
limit 100;

A 271 -cons -bridge
A 272
new financian 2 loans for same customer
bridge loan 2 collateral

nr_lnng - 
interest rate can have two parts
bridge loan




