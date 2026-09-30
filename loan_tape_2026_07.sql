
-- Mortgage Loan Tape

--drop table if exists credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_07_31;
create table credit_risk_playground.stg_mrt_Mortgage_loan_tape_2026_07_31 as 
with temp_tbl as (
select 
    reportdate,
    calc_date,
    instrument_id,
    itemno as user_id,
    legalentity,
    country,
    on_balance_ead as onbalance_ead,
    off_balance_eod as  offbalance_ead,
	ead,
    maturitydate,
    initial_pd as initialpd,
    currentrating,
    pd,
    lgd,
    null as limit,
    stage,
    ecl_on,
    ecl_off,
    ecl,
    dpd,
    ccf,
    row_number() over(partition by instrument_id, user_id) as dups
    from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
where reportdate = '2026-07-31'
),

temp_tbl1 as(
select 
    reportdate,
    calc_date,
    instrument_id,
    user_id,
    legalentity,
	--business_line,
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
from temp_tbl 
where dups = 1
),

------
neo_extended as (
select 
    borrower_identifier,
    loan_identifier,
    'Neo' AS business_line,
    purpose,
    segment,
    loan_origination_date,
    original_balance,
    current_balance,
    undrawn_loanpart,
    current_balance + undrawn_loanpart AS total_committment, 
    current_valuation_amount,
    collateral_value,
    interest_rate_reset_interval,
    current_interest_rate,
    payment_type,
    current_loan_to_value,
    payment_type AS amortization_type,
    original_loan_to_value,
    debt_service_coverage_ratio,
    arrears_balance,
    months_to_revision_date,
    remaining_term,
    fitch_dti,
    fitch_ltv_class,
    fitch_term_class,
    fitch_dti_class,
    fitch_cltv_class,
    fitch_cltv_term_class,
    
    --- fitch adjustments ---
    income_adjustment,
    final_baseline_ff,
    final_io_adjustment,
    final_ff_floor,
    ----
    
    adjusted_fitch_base_ff / 100 AS adjusted_fitch_base_ff,
    annualised_ff / 100 AS annualised_ff,
    cure_rate,
    pd_factor,
    indexed_vlaue_scalar,
    fitch_foreclosure_value,
    pd_ttc / 100 AS pd_ttc,
    pd_pit / 100 AS pd_pit,
    pd_pit_mastered / 100 AS pd_pit_mastered,
    pd_pit_class,
    lgd AS lgd_new,
    ROW_NUMBER() OVER(
        PARTITION BY borrower_identifier, loan_identifier 
        ORDER BY borrower_identifier, loan_identifier
    ) AS reps
from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
where pool_cut_off_date = '2026-06-30' -- calc_date in final loan tape
order by borrower_identifier, loan_identifier
),

rabo_extended as (
select 
    borrower_identifier,
    loan_identifier,
    'Rabo' AS business_line,
    purpose,
    segment,
    loan_origination_date,
    original_balance,
    current_balance,
    undrawn_loanpart,
    current_balance + undrawn_loanpart AS total_committment, 
    current_valuation_amount,
    collateral_value,
    interest_rate_reset_interval,
    current_interest_rate,
    payment_type,
    current_loan_to_value,
    payment_type AS amortization_type,
    original_loan_to_value,
    debt_service_coverage_ratio,
    arrears_balance,
    months_to_revision_date,
    remaining_term,
    fitch_dti,
    fitch_ltv_class,
    fitch_term_class,
    fitch_dti_class,
    fitch_cltv_class,
    fitch_cltv_term_class,
    
    --- fitch adjustments ---
    income_adjustment,
    final_baseline_ff,
    final_io_adjustment,
    final_ff_floor,
    ----
    
    adjusted_fitch_base_ff / 100 AS adjusted_fitch_base_ff,
    annualised_ff / 100 AS annualised_ff,
    cure_rate,
    pd_factor,
    indexed_vlaue_scalar,
    fitch_foreclosure_value,
    pd_ttc / 100 AS pd_ttc,
    pd_pit / 100 AS pd_pit,
    pd_pit_mastered / 100 AS pd_pit_mastered,
    pd_pit_class,
    lgd AS lgd_new,
    ROW_NUMBER() OVER(
        PARTITION BY borrower_identifier, loan_identifier 
        ORDER BY borrower_identifier, loan_identifier
    ) AS reps
from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations
where pool_cut_off_date = '2026-06-30' -- calc_date in final loan tape
order by borrower_identifier, loan_identifier
),

extensions as (

    (select * from neo_extended where reps = 1)
    union all (select * from rabo_extended where reps = 1)
),

extension_1 as (

select 
   *
from temp_tbl1 as x
left join extensions as y
on x.instrument_id = y.loan_identifier
order by user_id, instrument_id
),

new_loans as (
select 
	borrower_identifier,
	loan_identifier,
    loan_origination_date,
    original_balance as total_commitment
from extension_1
)

required_data as (
select 
    -- report dates ---
    reportdate,
	calc_date,
	-- borrower and business lines
	instrument_id,
	user_id,
	legalentity,
	business_line,
	country,
	-- loan characteristics ---
	purpose,
	segment,
	loan_origination_date,
	maturitydate,
	---original_balance,
	current_balance,
	arrears_balance,
	undrawn_loanpart,
	total_committment,
	collateral_value,
	interest_rate_reset_interval,
	current_interest_rate,
	case when  payment_type = 6 then 'bullet' else 'non-bullet' end as repayment_type,
	current_loan_to_value,
	--original_loan_to_value,
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
	reportdate as rating_date,
	case 
		when stage = 3 then 'problem loan'
		when stage = 2 and dpd >= 60 then 'intensified mgmnt'
		else 'ordinary'
	end as loan_mananment_stage,
	' ' as foreberance_flag

from extension_1 
order by user_id, instrument_id)

select *
from new_loans
where loan_origination_date >= '2026-01-01';

select 
     * 
from required_data
order by user_id, instrument_id;
