DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_rabobank_esma_raw;

CREATE TABLE credit_risk_playground.stg_mrt_rabobank_esma_raw AS
WITH esma_loan_data AS (
    SELECT 
        *
    FROM treasury_vista_rrel
),
esma_customer_data AS (
    SELECT  
        *,
        etl_source_file AS etl_source_file1,
        etl_updated AS etl_updated1
    FROM treasury_vista_rrec
)
SELECT 
    -- 1. Extracts '202608', formats to '2026-08-28', then grabs the LAST_DAY (e.g., 2026-08-31)
    LAST_DAY(TO_DATE(SUBSTRING(rel.etl_source_file, 1, 4) || '-' || SUBSTRING(rel.etl_source_file, 5, 2) || '-28', 'YYYY-MM-DD')) AS pool_cut_off_date,
    
    -- 2. Extracts 'N26' from '202608_ESMA RREL_N26_U.csv'
    SUBSTRING(rel.etl_source_file, 18, 3) AS pool_identifier,
    
    rel.*, 
    rec.rrec2_underlying_exposure_identifier, 
    rec.rrec3_original_collateral_identifier, 
    rec.rrec4_new_collateral_identifier, 
    rec.rrec5_collateral_type, 
    rec.rrec6_geographic_region___collateral, 
    rec.rrec7_occupancy_type, 
    rec.rrec8_lien, 
    rec.rrec9_property_type, 
    rec.rrec10_energy_performance_certificate_value, 
    rec.rrec11_energy_performance_certificate_provider_name, 
    rec.rrec12_current_loan_to_value, 
    rec.rrec13_current_valuation_amount, 
    rec.rrec13_currency, 
    rec.rrec14_current_valuation_method, 
    rec.rrec15_current_valuation_date, 
    rec.rrec16_original_loan_to_value, 
    rec.rrec17_original_valuation_amount, 
    rec.rrec17_currency, 
    rec.rrec18_original_valuation_method, 
    rec.rrec19_original_valuation_date, 
    rec.rrec20_date_of_sale, 
    rec.rrec21_sale_price, 
    rec.rrec21_currency, 
    rec.rrec23_guarantor_type, 
    rec.etl_source_file1 AS "etl_source_file.1", 
    rec.etl_updated1 AS "etl_updated.1"
FROM esma_loan_data AS rel
INNER JOIN esma_customer_data AS rec 
    ON rel.rrel3_new_underlying_exposure_identifier = rec.rrec2_underlying_exposure_identifier 
    -- 3. Safely matches the YYYYMM (chars 1-6) and the pool identifier (chars 18-20)
    AND SUBSTRING(rel.etl_source_file, 1, 6) = SUBSTRING(rec.etl_source_file1, 1, 6)
    AND SUBSTRING(rel.etl_source_file, 18, 3) = SUBSTRING(rec.etl_source_file1, 18, 3);
    

DROP TABLE IF EXISTS credit_risk_playground.stg_mrt_rabobank_esma_to_ecb_raw_dbt;

CREATE TABLE credit_risk_playground.stg_mrt_rabobank_esma_to_ecb_raw_dbt AS
WITH esma_source_data AS (
    SELECT
        pool_cut_off_date,
        pool_identifier,
        rrel3_new_underlying_exposure_identifier AS loan_identifier, 
        NULL AS regulated_loan, 
        rrel79_original_lender_name AS originator, 
        'Rabobank' AS servicer_identifier, 
        rrel5_new_obligor_identifier AS borrower_identifier, 
        rrec4_new_collateral_identifier AS property_identifier, 
        NULL::SMALLINT AS borrower_type, 
        NULL AS foreign_national, 
        NULL AS borrower_credit_quality, 
        NULL AS borrower_year_of_birth, 
        NULL::SMALLINT AS number_of_debtors, 
        NULL AS second_applicant_year_of_birth,
        
        (CASE
            WHEN rrel13_employment_status = 'EMRS' THEN '1' 
            WHEN rrel13_employment_status = 'EMBL' THEN '2' 
            WHEN rrel13_employment_status = 'EMUK' THEN '3' 
            WHEN rrel13_employment_status = 'UNEM' THEN '4' 
            WHEN rrel13_employment_status = 'SFEM' THEN '5' 
            WHEN rrel13_employment_status = 'NOEM' THEN '6' 
            WHEN rrel13_employment_status = 'STNT' THEN '7' 
            WHEN rrel13_employment_status = 'PNNR' THEN '8' 
            WHEN rrel13_employment_status = 'OTHR' THEN '9' 
            WHEN rrel13_employment_status LIKE 'ND%' THEN NULL
        END)::SMALLINT AS borrowers_employment_status,
        
        NULL AS first_time_buyer, 
        NULL AS right_to_buy, 
        NULL::FLOAT AS right_to_buy_price, 
        NULL AS class_of_borrower, 
        
        CASE WHEN rrel16_primary_income LIKE 'ND%' THEN NULL ELSE rrel16_primary_income::FLOAT END AS primary_income,
        
        CASE
            WHEN rrel19_primary_income_verification = 'SCRT' THEN '1' 
            WHEN rrel19_primary_income_verification = 'SCNF' THEN '2' 
            WHEN rrel19_primary_income_verification = 'VRFD' THEN '3' 
            WHEN rrel19_primary_income_verification = 'NVRF' THEN '4' 
            WHEN rrel19_primary_income_verification = 'SCRG' THEN '6' 
            WHEN rrel19_primary_income_verification = 'OTHR' THEN '5' 
            WHEN rrel19_primary_income_verification LIKE 'ND%' THEN NULL
        END AS income_verification_for_primary_income,
        
        CASE WHEN rrel20_secondary_income LIKE 'ND%' THEN NULL ELSE rrel20_secondary_income::FLOAT END AS secondary_income,
        
        CASE
            WHEN rrel21_secondary_income_verification = 'SCRT' THEN '1' 
            WHEN rrel21_secondary_income_verification = 'SCNF' THEN '2' 
            WHEN rrel21_secondary_income_verification = 'VRFD' THEN '3' 
            WHEN rrel21_secondary_income_verification = 'NVRF' THEN '4' 
            WHEN rrel21_secondary_income_verification = 'SCRG' THEN '6' 
            WHEN rrel21_secondary_income_verification = 'OTHR' THEN '5' 
            WHEN rrel21_secondary_income_verification LIKE 'ND%' THEN NULL
        END AS income_verification_for_secondary_income,
        
        NULL::SMALLINT AS resident, 
        NULL::INT AS number_of_county_court_judgements_or_equivalent_satisfied, 
        NULL::FLOAT AS value_of_county_court_judgements_or_equivalent_satisfied, 
        NULL::INT AS number_of_county_court_judgements_or_equivalent_unsatisfied, 
        NULL::FLOAT AS value_of_county_court_judgements_or_equivalent_unsatisfied, 
        NULL AS last_county_court_judgements_or_equivalent_year, 
        NULL AS bankruptcy_or_individual_voluntary_arrangement_flag, 
        NULL AS prior_repossessions, 
        NULL::SMALLINT AS previous_mortgage_arrears_6_months, 
        NULL::SMALLINT AS previous_mortgage_arrears_over_6_months,
        
        CASE WHEN rrel23_origination_date LIKE 'ND%' THEN NULL ELSE TO_DATE(rrel23_origination_date, 'DD-MM-YYYY')::DATE END AS loan_origination_date,
        CASE WHEN rrel24_maturity_date LIKE 'ND%' THEN NULL ELSE TO_DATE(rrel24_maturity_date, 'DD-MM-YYYY')::DATE END AS date_of_loan_maturity,
        
        NULL::DATE AS account_status_date,
        
        (CASE
            WHEN rrel26_origination_channel = 'BRAN' THEN '1' 
            WHEN rrel26_origination_channel = 'DRCT' THEN '2' 
            WHEN rrel26_origination_channel = 'BROK' THEN '3' 
            WHEN rrel26_origination_channel = 'WEBI' THEN '4' 
            WHEN rrel26_origination_channel = 'TPAC' THEN '5' 
            WHEN rrel26_origination_channel = 'TPTC' THEN '6' 
            WHEN rrel26_origination_channel = 'OTHR' THEN '7' 
            WHEN rrel26_origination_channel LIKE 'ND%' THEN NULL
        END)::SMALLINT AS origination_channel_arranging_cank_or_division,
        
        (CASE
            WHEN rrel27_purpose = 'PURC' THEN '1' WHEN rrel27_purpose = 'RMRT' THEN '2' WHEN rrel27_purpose = 'RENV' THEN '3' 
            WHEN rrel27_purpose = 'EQRE' THEN '4' WHEN rrel27_purpose = 'CNST' THEN '5' WHEN rrel27_purpose = 'DCON' THEN '6' 
            WHEN rrel27_purpose = 'OTHR' THEN '7' WHEN rrel27_purpose = 'RMEQ' THEN '8' WHEN rrel27_purpose = 'CMRT' THEN '10' 
            WHEN rrel27_purpose = 'IMRT' THEN '11' WHEN rrel27_purpose = 'RGBY' THEN '12' WHEN rrel27_purpose = 'GSPL' THEN '13' 
            WHEN rrel27_purpose LIKE 'ND%' THEN NULL
        END)::SMALLINT AS purpose,
        
        NULL::SMALLINT AS shared_ownership, 
        CASE WHEN rrel25_original_term LIKE 'ND%' THEN NULL ELSE CAST(CAST(rrel25_original_term AS NUMERIC(20,2)) AS INTEGER) END AS loan_term, 
        NULL::INT AS principal_grace_period, 
        NULL::FLOAT AS amount_guaranteed, 
        NULL AS subsidy, 
        'EUR' AS loan_currency_denomination, 
        
        CASE WHEN rrel29_original_principal_balance LIKE 'ND%' THEN 0 ELSE rrel29_original_principal_balance::FLOAT END AS original_balance,
        
        -- FLOAT ARTIFACT FIX: Math done in EXACT Numeric, then cast back to FLOAT for perfect CSV export
        ((CASE WHEN rrel30_current_principal_balance LIKE 'ND%' THEN 0 ELSE rrel30_current_principal_balance::NUMERIC(20,2) END) - 
        (CASE WHEN rrel77_deposit_amount LIKE 'ND%' THEN 0 ELSE rrel77_deposit_amount::NUMERIC(20,2) END))::FLOAT AS current_balance,
        
        NULL AS fractioned_subrogated_loans, 
        (CASE WHEN rrel35_amortisation_type = 'BLLT' THEN '1' ELSE '2' END)::SMALLINT AS repayment_method,
        
        (CASE
            WHEN rrel37_scheduled_principal_payment_frequency = 'MNTH' THEN '1' 
            WHEN rrel37_scheduled_principal_payment_frequency = 'QUTR' THEN '2' 
            WHEN rrel37_scheduled_principal_payment_frequency = 'SEMI' THEN '3' 
            WHEN rrel37_scheduled_principal_payment_frequency = 'YEAR' THEN '4' 
            WHEN rrel37_scheduled_principal_payment_frequency = 'OTHR' THEN '6' 
            WHEN rrel37_scheduled_principal_payment_frequency LIKE 'ND%' THEN NULL
        END)::SMALLINT AS payment_frequency,
        
        CASE WHEN rrel39_payment_due LIKE 'ND%' THEN NULL ELSE rrel39_payment_due::FLOAT END AS payment_due,
        
        (CASE 
            WHEN rrel35_amortisation_type = 'FRXX' THEN '1' 
            WHEN rrel35_amortisation_type = 'FIXE' THEN '2' 
            WHEN rrel35_amortisation_type = 'BLLT' THEN '6' 
            ELSE NULL 
        END)::SMALLINT AS payment_type,
        
        CASE WHEN rrel40_debt_to_income_ratio LIKE 'ND%' THEN NULL ELSE rrel40_debt_to_income_ratio::FLOAT END AS debt_to_income,
        
        (CASE
            WHEN rrec23_guarantor_type = 'NGUA' THEN '1' WHEN rrec23_guarantor_type = 'FAML' THEN '2' WHEN rrec23_guarantor_type = 'IOTH' THEN '3' 
            WHEN rrec23_guarantor_type = 'GOVE' THEN '4' WHEN rrec23_guarantor_type = 'BANK' THEN '5' WHEN rrec23_guarantor_type = 'INSU' THEN '6' 
            WHEN rrec23_guarantor_type = 'NHGX' THEN '7' WHEN rrec23_guarantor_type = 'FGAS' THEN '8' WHEN rrec23_guarantor_type = 'CATN' THEN '9' 
            WHEN rrec23_guarantor_type = 'OTHR' THEN '10' WHEN rrec23_guarantor_type LIKE 'ND%' THEN NULL
        END)::SMALLINT AS type_of_guarantee_provider,
        
        NULL::SMALLINT AS guarantee_provider, 
        NULL::FLOAT AS guarantor_income, 
        
        CASE 
            WHEN rrel22_special_scheme LIKE 'ND%' THEN NULL 
            WHEN rrel22_special_scheme ~* '[A-Za-z]' THEN NULL 
            ELSE rrel22_special_scheme::FLOAT 
        END AS subsidy_received, 
        
        NULL AS mortgage_indemnity_guarantee_provider, 
        NULL::FLOAT AS mortgage_indemnity_guarantee_attachment_point, 
        NULL::FLOAT AS prior_balances, 
        NULL::FLOAT AS other_prior_balances, 
        NULL::FLOAT AS pari_passu_loans, 
        NULL::FLOAT AS subordinated_claims, 
        NULL::SMALLINT AS lien, 
        
        CASE 
            WHEN rrel77_deposit_amount LIKE 'ND%' THEN NULL 
            WHEN rrel77_deposit_amount::FLOAT = 0 THEN NULL 
            ELSE rrel77_deposit_amount::FLOAT 
        END AS retained_amount, 
        
        NULL::DATE AS retained_amount_date, 
        
        NULL::FLOAT AS maximum_balance, 
        NULL::FLOAT AS further_loan_advance, 
        NULL::FLOAT AS flexible_loan_amount, 
        NULL AS further_advances, 
        NULL::INT AS length_of_payment_holiday, 
        NULL::INT AS subsidy_period, 
        NULL::FLOAT AS mortgage_inscription, 
        NULL AS deed_of_postponement, 
        NULL::FLOAT AS pre_payment_amount, 
        NULL::FLOAT AS pre_payment_penalties, 
        
        CASE WHEN rrel64_cumulative_prepayments LIKE 'ND%' THEN NULL ELSE rrel64_cumulative_prepayments::FLOAT END AS cumulative_pre_payments, 
        CASE WHEN rrel59_percentage_of_prepayments_allowed_per_year LIKE 'ND%' THEN NULL ELSE rrel59_percentage_of_prepayments_allowed_per_year::FLOAT END AS percentage_of_pre_payments_allowed_per_year,
        
        (CASE
            WHEN rrel42_interest_rate_type = 'FLIF' THEN '1' WHEN rrel42_interest_rate_type = 'FINX' THEN '2' WHEN rrel42_interest_rate_type = 'FXRL' THEN '3' 
            WHEN rrel42_interest_rate_type = 'FXPR' THEN '4' WHEN rrel42_interest_rate_type = 'FLCF' THEN '5' WHEN rrel42_interest_rate_type = 'CAPP' THEN '6' 
            WHEN rrel42_interest_rate_type = 'OTHR' THEN '8' WHEN rrel42_interest_rate_type = 'FLFL' THEN '9' WHEN rrel42_interest_rate_type = 'FLCA' THEN '10' 
            WHEN rrel42_interest_rate_type LIKE 'ND%' THEN NULL
        END)::SMALLINT AS interest_rate_type,
        
        '12'::SMALLINT AS current_interest_rate_index, 
        CASE WHEN rrel43_current_interest_rate LIKE 'ND%' THEN NULL ELSE rrel43_current_interest_rate::FLOAT END AS current_interest_rate,
        
        CASE
            WHEN rrel42_interest_rate_type IN ('FXRL', 'FXPR', 'FLCF') AND rrel43_current_interest_rate NOT LIKE 'ND%' THEN rrel43_current_interest_rate::FLOAT 
            WHEN rrel42_interest_rate_type IN ('FXRL', 'FXPR', 'FLCF') AND rrel43_current_interest_rate LIKE 'ND%' THEN 0::FLOAT 
            WHEN rrel42_interest_rate_type IN ('FLIF', 'FINX', 'CAPP', 'FLFL', 'FLCA') AND rrel46_current_interest_rate_margin NOT LIKE 'ND%' THEN rrel46_current_interest_rate_margin::FLOAT 
            WHEN rrel46_current_interest_rate_margin LIKE 'ND%' THEN NULL
        END AS current_interest_rate_margin,
        
        CASE WHEN rrel47_interest_rate_reset_interval LIKE 'ND%' THEN NULL ELSE CAST(CAST(rrel47_interest_rate_reset_interval AS NUMERIC(20,2)) AS INTEGER) END AS interest_rate_reset_interval, 
        NULL::FLOAT AS interest_cap_rate, 
        NULL::FLOAT AS revision_margin_1, 
        CASE WHEN rrel51_interest_revision_date_1 LIKE 'ND%' THEN NULL ELSE TO_CHAR(TO_DATE(rrel51_interest_revision_date_1, 'DD-MM-YYYY'), 'YYYY-MM') END AS interest_revision_date_1, 
        NULL::FLOAT AS revision_margin_2, NULL AS interest_revision_date_2, NULL::FLOAT AS revision_margin_3, NULL AS interest_revision_date_3, 
        NULL::SMALLINT AS revised_interest_rate_index, NULL::FLOAT AS final_margin, NULL AS restructuring_arrangement, 'NLZZZ' AS geographic_region_list, NULL::INT AS property_postcode,
        
        (CASE WHEN rrec7_occupancy_type = 'FOWN' THEN '1' WHEN rrec7_occupancy_type = 'POWN' THEN '2' WHEN rrec7_occupancy_type = 'TLET' THEN '3' 
             WHEN rrec7_occupancy_type = 'HOLD' THEN '4' WHEN rrec7_occupancy_type = 'OTHR' THEN '5' WHEN rrec7_occupancy_type = 'CAPP' THEN '6' 
             WHEN rrec7_occupancy_type LIKE 'ND%' THEN NULL END)::SMALLINT AS occupancy_type,
             
        (CASE WHEN rrec9_property_type = 'RHOS' THEN '1' WHEN rrec9_property_type = 'RFLT' THEN '2' WHEN rrec9_property_type = 'RBGL' THEN '3' 
             WHEN rrec9_property_type = 'RTHS' THEN '4' WHEN rrec9_property_type = 'MULF' THEN '5' WHEN rrec9_property_type = 'PCMM' THEN '7' 
             WHEN rrec9_property_type = 'BIZZ' THEN '8' WHEN rrec9_property_type = 'LAND' THEN '10' WHEN rrec9_property_type = 'OTHR' THEN '11' 
             WHEN rrec9_property_type LIKE 'ND%' THEN NULL END)::SMALLINT AS property_type,
             
        NULL::SMALLINT AS new_property, NULL AS construction_year, NULL AS property_rating, 
        
        -- FLOAT ARTIFACT FIX: LTV calculation
        CASE WHEN rrec16_original_loan_to_value LIKE 'ND%' THEN NULL ELSE (rrec16_original_loan_to_value::NUMERIC(10,4) * 100)::FLOAT END AS original_loan_to_value, 
        CASE WHEN rrec17_original_valuation_amount LIKE 'ND%' THEN NULL ELSE rrec17_original_valuation_amount::FLOAT END AS valuation_amount,
        
        (CASE WHEN rrec18_original_valuation_method = 'FIEI' THEN '1' WHEN rrec18_original_valuation_method = 'FOEI' THEN '2' 
             WHEN rrec18_original_valuation_method = 'DRVB' THEN '3' WHEN rrec18_original_valuation_method = 'AUVM' THEN '4' 
             WHEN rrec18_original_valuation_method = 'IDXD' THEN '5' WHEN rrec18_original_valuation_method = 'DKTP' THEN '6' 
             WHEN rrec18_original_valuation_method = 'MAEA' THEN '7' WHEN rrec18_original_valuation_method = 'TXAT' THEN '8' 
             WHEN rrec18_original_valuation_method = 'OTHR' THEN '9' WHEN rrec18_original_valuation_method LIKE 'ND%' THEN NULL END)::INT AS original_valuation_type,
             
        CASE WHEN rrec19_original_valuation_date LIKE 'ND%' THEN NULL::DATE ELSE TO_DATE(rrec19_original_valuation_date, 'DD-MM-YYYY')::DATE END AS valuation_date, 
        
        NULL::NUMERIC AS confidence_interval_for_original_automated_valuation_model_valuation, 
        NULL AS provider_of_original_automated_valuation_model_valuation, 
        
        -- FLOAT ARTIFACT FIX: LTV calculation
        CASE WHEN rrec12_current_loan_to_value LIKE 'ND%' THEN NULL ELSE (rrec12_current_loan_to_value::NUMERIC(10,4) * 100)::FLOAT END AS current_loan_to_value, 
        NULL::FLOAT AS purchase_price_lower_limit, 
        CASE WHEN rrec13_current_valuation_amount LIKE 'ND%' THEN NULL ELSE rrec13_current_valuation_amount::FLOAT END AS current_valuation_amount,
        
        (CASE WHEN rrec14_current_valuation_method = 'FIEI' THEN '1' WHEN rrec14_current_valuation_method = 'FOEI' THEN '2' 
             WHEN rrec14_current_valuation_method = 'DRVB' THEN '3' WHEN rrec14_current_valuation_method = 'AUVM' THEN '4' 
             WHEN rrec14_current_valuation_method = 'IDXD' THEN '5' WHEN rrec14_current_valuation_method = 'DKTP' THEN '6' 
             WHEN rrec14_current_valuation_method = 'MAEA' THEN '7' WHEN rrec14_current_valuation_method = 'TXAT' THEN '8' 
             WHEN rrec14_current_valuation_method = 'OTHR' THEN '9' WHEN rrec14_current_valuation_method LIKE 'ND%' THEN NULL END)::SMALLINT AS current_valuation_type,
             
        CASE WHEN rrec15_current_valuation_date LIKE 'ND%' THEN NULL::DATE ELSE TO_DATE(rrec15_current_valuation_date, 'DD-MM-YYYY')::DATE END AS current_valuation_date, 
        
        NULL::NUMERIC AS confidence_interval_for_current_automated_valuation_model_valuation, 
        NULL AS provider_of_current_automated_valuation_model_valuation, 
        NULL::FLOAT AS property_value_at_time_of_latest_loan_advance, NULL::FLOAT AS indexed_foreclosure_value, NULL::FLOAT AS ipoteca, NULL::SMALLINT AS additional_collateral, NULL AS additional_collateral_provider, 
        NULL::FLOAT AS gross_annual_rental_income, NULL::INT AS number_of_buy_to_let_properties, NULL::FLOAT AS debt_service_coverage_ratio, NULL::FLOAT AS additional_collateral_value, 
        NULL AS real_estate_owned, NULL AS is_property_transferability_limited, NULL::NUMERIC AS time_until_declassification,
        
        (CASE WHEN rrel69_account_status IN ('PERF','RNAR') THEN '1' WHEN rrel69_account_status IN ('ARRE','RARR') THEN '2' 
             WHEN rrel69_account_status IN ('DFLT','NDFT','DTCR','DADB') THEN '3' WHEN rrel69_account_status = 'RDMD' THEN '4' 
             WHEN rrel69_account_status IN ('REBR','REDF', 'RERE', 'RESS', 'REOT') THEN '5' WHEN rrel69_account_status = 'OTHR' THEN '6' 
             WHEN rrel69_account_status LIKE 'ND%' THEN NULL END)::SMALLINT AS account_status,
             
        NULL::DATE AS date_last_current, 
        CASE WHEN rrel66_date_last_in_arrears LIKE 'ND%' THEN NULL::DATE ELSE TO_DATE(rrel66_date_last_in_arrears, 'DD-MM-YYYY')::DATE END AS date_last_in_arrears, 
        CASE WHEN rrel67_arrears_balance LIKE 'ND%' THEN NULL ELSE rrel67_arrears_balance::FLOAT END AS arrears_balance, 
        
        CASE 
            WHEN rrel68_number_of_days_in_arrears LIKE 'ND%' THEN NULL 
            WHEN rrel67_arrears_balance::FLOAT <= 5 THEN NULL 
            ELSE CAST(CAST(rrel68_number_of_days_in_arrears AS NUMERIC(20,2)) / 30 AS INTEGER) 
        END AS number_months_in_arrears,
        
        LAG(CASE WHEN rrel67_arrears_balance LIKE 'ND%' THEN NULL ELSE rrel67_arrears_balance::FLOAT END, 1) OVER (PARTITION BY rrel3_new_underlying_exposure_identifier ORDER BY etl_source_file) AS arrears_1_month_ago, 
        LAG(CASE WHEN rrel67_arrears_balance LIKE 'ND%' THEN NULL ELSE rrel67_arrears_balance::FLOAT END, 2) OVER (PARTITION BY rrel3_new_underlying_exposure_identifier ORDER BY etl_source_file) AS arrears_2_months_ago, 
        NULL AS performance_arrangement, 
        NULL AS litigation,
        
        CASE WHEN rrel9_redemption_date LIKE 'ND%' THEN NULL ELSE TO_DATE(rrel9_redemption_date, 'DD-MM-YYYY')::DATE END AS redemption_date,
        
        NULL::FLOAT AS months_in_arrears_prior, 
        NULL::FLOAT AS default_or_foreclosure, 
        NULL::FLOAT AS sale_price_lower_limit, 
        NULL::FLOAT AS loss_on_sale, 
        NULL::FLOAT AS cumulative_recoveries, 
        NULL::FLOAT AS professional_negligence_recoveries, 
        NULL AS loan_flagged_as_contencioso
    FROM credit_risk_playground.stg_mrt_rabobank_esma_raw
    WHERE 1=1 AND rrel7_pool_addition_date NOT LIKE 'ND%'
)
SELECT 
    a.*,
    GETDATE() AS etl_updated,
    CURRENT_USER::VARCHAR AS created_by
FROM esma_source_data AS a;



WITH aligned_legacy AS (
    -- 1. Clean and deduplicate the legacy source to the Loan level
    SELECT DISTINCT
        loan_identifier,
        -- Protected Date Cast
        CASE 
            WHEN LENGTH(TRIM(pool_cut_off_date)) > 10 THEN NULL 
            ELSE TO_DATE(TRIM(REPLACE(REPLACE(pool_cut_off_date, '.', '-'), '-', '/')), 'DD/MM/YYYY')::DATE 
        END AS reporting_date,
        borrowers_employment_status,
        primary_income,
        secondary_income
    FROM etl_reporting.rabobank_mortgages
    WHERE (current_balance > 0 OR retained_amount > 0)
      -- CRITICAL FIX: Ignore massive malformed CSV strings before date conversion
      AND LENGTH(TRIM(pool_cut_off_date)) <= 10
),

aligned_esma AS (
    -- 2. Extract ESMA raw and parse the reporting date from the file name
    SELECT 
        rrel3_new_underlying_exposure_identifier AS loan_identifier,
        -- Safely extracts exactly 10 characters so this will never trigger a length error
        LAST_DAY(TO_DATE(SUBSTRING(etl_source_file, 1, 4) || '-' || SUBSTRING(etl_source_file, 5, 2) || '-28', 'YYYY-MM-DD')) AS reporting_date,
        rrel13_employment_status,
        rrel16_primary_income,
        rrel20_secondary_income
    FROM treasury_vista_rrel
)

-- 3. Perform the 1-to-1 Join
SELECT 
    esma.loan_identifier,
    
    -- Legacy Values (Expected/Truth)
    legacy.borrowers_employment_status AS legacy_employment_status,
    legacy.secondary_income AS legacy_secondary_income,
    legacy.primary_income AS legacy_primary_income,
    
    -- ESMA Values (Defective Outputs)
    esma.rrel13_employment_status AS esma_employment_status,
    esma.rrel20_secondary_income AS esma_secondary_income,
    esma.rrel16_primary_income AS esma_primary_income
    
FROM aligned_esma esma
INNER JOIN aligned_legacy legacy
    ON esma.loan_identifier = legacy.loan_identifier
    AND esma.reporting_date = legacy.reporting_date
    
WHERE esma.reporting_date = '2026-07-31'
  AND esma.loan_identifier IN (
    '3219865-32198650101', '3219865-32198650108', '3219865-32198650102', '3219865-32198650107', '3219865-32198650103',
    '3219865-32198650104', '3219865-32198650106', '3190589-31905890301', '3190589-31905890106', '3190589-31905890101',
    '3190589-31905890105', '3190589-31905890302', '3190589-31905890103', '3190589-31905890102', '3190589-31905890104',
    '3138460-31384600106', '3138460-31384600101', '3138460-31384600108', '3138460-31384600401', '3138460-31384600103',
    '3138460-31384600105', '3138460-31384600107', '3138460-31384600102', '3138460-31384600104', '3481571-34815710111',
    '3481571-34815710118', '3481571-34815710108', '3481571-34815710117', '3481571-34815710107', '3481571-34815710112',
    '3481571-34815710113', '3481571-34815710110', '3580505-35805050110', '3580505-35805050115', '3580505-35805050112',
    '3580505-35805050114', '3580505-35805050109', '3580505-35805050111', '3494424-34944240111', '3494424-34944240109',
    '3494424-34944240115', '3494424-34944240116', '3494424-34944240110', '3494424-34944240114', '3494424-34944240112',
    '3494424-34944240113', '3200253-32002530101', '3200253-32002530301', '3200253-32002530110', '3200253-32002530102',
    '3200253-32002530103', '3200253-32002530105', '3200253-32002530104', '3200253-32002530106', '3144089-31440890102',
    '3144089-31440890103', '3144089-31440890104', '3144089-31440890105', '3144089-31440890101', '3197968-31979680104',
    '3197968-31979680107', '3197968-31979680106', '3197968-31979680102', '3197968-31979680105', '3197968-31979680101',
    '3197968-31979680103', '3598958-35989580303', '3598958-35989580302', '3598958-35989580305', '3598958-35989580304',
    '3201578-32015780107', '3201578-32015780105', '3201578-32015780108', '3201578-32015780106', '3201578-32015780103',
    '3201578-32015780101', '3201578-32015780102', '3201578-32015780104', '3141420-31414200101', '3141420-31414200103',
    '3141420-31414200108', '3141420-31414200109', '3141420-31414200107', '3141420-31414200105', '3141420-31414200102',
    '3141420-31414200104', '3205784-32057840107', '3205784-32057840103', '3205784-32057840106', '3205784-32057840102',
    '3205784-32057840105', '3205784-32057840104', '3205784-32057840101', '3205784-32057840109', '3205784-32057840111',
    '3349284-33492840110', '3349284-33492840113', '3349284-33492840108', '3349284-33492840111', '3349284-33492840114'
  );



select * FROM etl_reporting.rabobank_mortgages
    WHERE (current_balance > 0 OR retained_amount > 0)
--and loan_identifier = '3138460-31384600106'
and pool_cut_off_date = '31-07-2026';

select * FROM treasury_vista_rrel
where rrel3_new_underlying_exposure_identifier = '3138460-31384600106'
and etl_source_file = '202607_ESMA RREL_N26_U.csv'


SELECT * FROM credit_risk_playground.stg_mrt_rabobank_raw_temp
WHERE pool_cut_off_date = '2026-08-31'

SELECT 
    -- IDENTIFIERS
    legacy.loan_identifier AS ecb_loan_identifier,
    rrel.rrel3_new_underlying_exposure_identifier AS esma_loan_identifier,

    -- CATEGORY 1: UPSTREAM ESMA GENERATION BUGS
    legacy.borrowers_employment_status AS ecb_borrowers_employment_status,
    rrel.rrel13_employment_status AS esma_rrel13_employment_status,

    legacy.secondary_income AS ecb_secondary_income,
    rrel.rrel20_secondary_income AS esma_rrel20_secondary_income,

    legacy.percentage_of_pre_payments_allowed_per_year AS ecb_percentage_of_pre_payments_allowed_per_year,
    rrel.rrel59_percentage_of_prepayments_allowed_per_year AS esma_rrel59_percentage_of_prepayments_allowed_per_year,

    legacy.debt_to_income AS ecb_debt_to_income,
    rrel.rrel40_debt_to_income_ratio AS esma_rrel40_debt_to_income_ratio,

    -- CATEGORY 2: SYSTEMATIC DATE ERASURES
    legacy.loan_origination_date AS ecb_loan_origination_date,
    rrel.rrel23_origination_date AS esma_rrel23_origination_date,

    legacy.valuation_date AS ecb_valuation_date,
    rrec.rrec19_original_valuation_date AS esma_rrec19_original_valuation_date

FROM etl_reporting.rabobank_mortgages legacy

FULL OUTER JOIN treasury_vista_rrel rrel
    ON legacy.loan_identifier = rrel.rrel3_new_underlying_exposure_identifier
    AND rrel.etl_source_file = '202607_ESMA RREL_N26_U.csv'

LEFT JOIN treasury_vista_rrec rrec
    ON rrel.rrel3_new_underlying_exposure_identifier = rrec.rrec2_underlying_exposure_identifier
    -- Assumes collateral file matches the month
    AND rrec.etl_source_file = '202607_ESMA RREC_N26_U.csv'

WHERE legacy.pool_cut_off_date = '31-07-2026'
  AND (legacy.current_balance > 0 OR legacy.retained_amount > 0);
  
  -- Leave uncommented to test the specific loan, or comment out to run for the full July pool
--  AND COALESCE(legacy.loan_identifier, rrel.rrel3_new_underlying_exposure_identifier) = '3138460-31384600106';
     