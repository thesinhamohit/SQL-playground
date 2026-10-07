

-------  A. Performance against KRIs -----------------

with temp_tbl as (

select pool_cut_off_date as calc_date, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*,
	case 
	 when segment = 'NHG' then 0
   	 when current_loan_to_value < 60 then 1
   	 when current_loan_to_value < 70 then 2
   	 when current_loan_to_value < 80 then 3
   	 when current_loan_to_value < 90 then 4
   	 when current_loan_to_value < 100 then 5
   	 else 6
   end  risk_class,
   case 
     when segment = 'NHG' then 'NHG'
   	 when current_loan_to_value < 60 then 'ltv<60'
   	 when current_loan_to_value < 70 then 'ltv<70'
   	 when current_loan_to_value < 80 then 'ltv<80'
   	 when current_loan_to_value < 90 then 'ltv<90'
   	 when current_loan_to_value < 100 then 'ltv<100'
   	 else 'ltv>=100'
   end risk_class_description
	
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

select 
	reportdate,
	sum(ead) as exposure,
	sum(ecl) as ecl_vol,
    sum(case when stage = 3 then ead else 0 end) npl_exposure,
	sum(case when segment = 'NHG' then ead else 0 end) as nhg_exposure,
	sum(case when current_loan_to_value > 80 and segment <> 'NHG' then ead else 0 end) as ltv_above_80_expsoure,

	100 * ecl_vol / exposure as ecl_pct,
	100 *  npl_exposure / exposure npl_pct,
	100 * nhg_exposure / exposure as nhg_pct,
	100 * ltv_above_80_expsoure / exposure as ltv_above_80_pct

from temp_tbl2
group by reportdate
order by reportdate




-----B.1 Exposure overview -------------

with temp_tbl as (

select pool_cut_off_date as calc_date, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*,
	case 
	 when segment = 'NHG' then 0
   	 when current_loan_to_value < 60 then 1
   	 when current_loan_to_value < 70 then 2
   	 when current_loan_to_value < 80 then 3
   	 when current_loan_to_value < 90 then 4
   	 when current_loan_to_value < 100 then 5
   	 else 6
   end  risk_class,
   case 
     when segment = 'NHG' then 'NHG'
   	 when current_loan_to_value < 60 then 'ltv<60'
   	 when current_loan_to_value < 70 then 'ltv<70'
   	 when current_loan_to_value < 80 then 'ltv<80'
   	 when current_loan_to_value < 90 then 'ltv<90'
   	 when current_loan_to_value < 100 then 'ltv<100'
   	 else 'ltv>=100'
   end risk_class_description
	
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

select 
    reportdate,
    business_line,
	risk_class,
	risk_class_description,
    sum(ead) / 1000 as total_exposure,
	sum(case when purpose = 'Brigding' then ead else 0 end) / 1000 as bridge_exposure,
	sum(off_balance_eod) / 1000 as off_balance_exposure
from temp_tbl2
where reportdate in ('2026-06-30')
group by  reportdate, business_line, risk_class, risk_class_description
order by  reportdate, business_line, risk_class, risk_class_description


--- B.2 bridge and undrawn amount ------------


with temp_tbl as (

select pool_cut_off_date as calc_date, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*,
	case 
	 when segment = 'NHG' then 0
   	 when current_loan_to_value < 60 then 1
   	 when current_loan_to_value < 70 then 2
   	 when current_loan_to_value < 80 then 3
   	 when current_loan_to_value < 90 then 4
   	 when current_loan_to_value < 100 then 5
   	 else 6
   end  risk_class,
   case 
     when segment = 'NHG' then 'NHG'
   	 when current_loan_to_value < 60 then 'ltv<60'
   	 when current_loan_to_value < 70 then 'ltv<70'
   	 when current_loan_to_value < 80 then 'ltv<80'
   	 when current_loan_to_value < 90 then 'ltv<90'
   	 when current_loan_to_value < 100 then 'ltv<100'
   	 else 'ltv>=100'
   end risk_class_description
	
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

select 
    reportdate,
    business_line,
    sum(ead) / 1000 as total_exposure,
	sum(case when purpose = 'Brigding' then ead else 0 end) / 1000 as bridge_exposure,
	sum(off_balance_eod) / 1000 as off_balance_exposure
from temp_tbl2
where reportdate in ('2026-06-30')
group by  reportdate, business_line
order by  reportdate, business_line




--- C. Portfolio & credit risk stats -------------

---Rabo
select 
	pool_cut_off_date,
	segment,
	largest_exposure /1000 as largest_exposure,
	customers,
	wa_reset_period_years,
	wa_cltv_pct,
	wa_dscr,
	wa_coupon_net_servicing_cost_pct,
	rwa_pct,
	roe_pct,
	wa_pd_pct,
	wa_lgd_pct
from credit_risk_playground.stg_mrt_rabobank_portfolio_stats 
where pool_cut_off_date in ('2026-08-31') and segment = 'total' 



-- Neo
select 
	pool_cut_off_date,
	segment,
	largest_exposure /1000 as largest_exposure,
	customers,
	wa_reset_period_years,
	wa_cltv_pct,
	wa_dscr,
	wa_coupon_net_servicing_cost_pct,
	rwa_pct,
	roe_pct,
	wa_pd_pct,
	wa_lgd_pct
from credit_risk_playground.stg_mrt_neo_portfolio_stats 
where pool_cut_off_date in ('2026-08-31') and segment = 'total' 


-------D.  LTI -----------------------

with temp_tbl as (

select pool_cut_off_date as calc_date, total_monthly_income, customer_level_current_balance, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, total_monthly_income, customer_level_current_balance, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*,
	customer_level_current_balance / (12 * total_monthly_income) as lti
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

--- select sum(ead * lti) / sum(ead) as avg_lti from temp_tbl2 
--- where reportdate in('2025-12-31')

select 
        reportdate,
        business_line,
		sum(ead * lti) / sum(ead) as avg_lti,
		max(lti) as max_lti

from temp_tbl2
where reportdate in('2026-03-31', '2026-06-30')
group by  reportdate, business_line
order by  reportdate,  business_line


------ E. ecl overviews ----------------
with temp_tbl as (

select pool_cut_off_date as calc_date, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

select 
    business_line,
    stage,
	sum(ead) / 1000000 as ead,
    sum(ecl) / 1000 as ecl
from temp_tbl2
where reportdate = '2026-09-30'
group by business_line, stage
order by business_line, stage



------- F. Volume development -------
with temp_tbl as (

select pool_cut_off_date as calc_date, loan_identifier as instrument_id , segment, purpose, current_loan_to_value, 'neo' as business_line from credit_risk_playground.stg_mrt_neo_credit_risk_calculations
union all (select pool_cut_off_date  as calc_date, loan_identifier as instrument_id, segment, purpose, current_loan_to_value, 'rabo' as  business_line   from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)

),

temp_tbl2 as (

select 
	*,
	case 
	 when segment = 'NHG' then 0
   	 when current_loan_to_value < 60 then 1
   	 when current_loan_to_value < 70 then 2
   	 when current_loan_to_value < 80 then 3
   	 when current_loan_to_value < 90 then 4
   	 when current_loan_to_value < 100 then 5
   	 else 6
   end  risk_class,
   case 
     when segment = 'NHG' then 'NHG'
   	 when current_loan_to_value < 60 then 'ltv<60'
   	 when current_loan_to_value < 70 then 'ltv<70'
   	 when current_loan_to_value < 80 then 'ltv<80'
   	 when current_loan_to_value < 90 then 'ltv<90'
   	 when current_loan_to_value < 100 then 'ltv<100'
   	 else 'ltv>=100'
   end risk_class_description
	
from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3 as v3
left join temp_tbl as tbl
using(instrument_id, calc_date)
) 

select 
    reportdate,
    business_line,
    sum(ead) / 1000 as total_exposure,
	sum(case when purpose = 'Brigding' then ead else 0 end) / 1000 as bridge_exposure,
	sum(off_balance_eod) / 1000 as off_balance_exposure
from temp_tbl2
where reportdate >= '2026-03-31'
group by  reportdate, business_line
order by  business_line, reportdate



/*-----------------------
Arrears code
-----------------------*/


/* Rabo arrears and default stats */
----------------------------------
with report_date as(

	select '2026-06-30'::date as reporting_date
),

arrears as(
select 
	arrList.* 
from credit_risk_playground.stg_mrt_rabobank_arrears_list as arrList
inner join report_date as rdate
on arrList.pool_cut_off_date::date  = rdate.reporting_date 
),

temp_tbl as (
	(select 
		pool_cut_off_date,
		months_in_arrears,
		'total' as segment,
		count(distinct borrower_identifier) as customers,
		round(sum(current_balance)) as principal_balance,
		round(sum(arrears_balance_loan_level)) as arrears_balance
	from arrears
	group by 1, 2
	order by 1, 2)
	union (
	select 
		pool_cut_off_date,
		months_in_arrears,
		segment,
		count(distinct borrower_identifier) as customers,
		round(sum(current_balance)) as principal_balance,
		round(sum(arrears_balance_loan_level)) as arrears_balance
	from arrears
	group by 1, 2, 3
	order by 1, 2, 3
	)
	order by pool_cut_off_date, months_in_arrears
	),

	temp_tbl1 as (
	select 
	  a.*,
	  b.pd_pit_mastered,
	  b.lgd
	 from arrears as a
	 left join (
	 	select 
	 		borrower_identifier,
	 		loan_identifier,
	 		pd_pit_mastered,
	 		lgd
		from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations 
		where pool_cut_off_date = (select max(pool_cut_off_date) from credit_risk_playground.stg_mrt_rabobank_credit_risk_calculations)
		and borrower_identifier in (select distinct borrower_identifier from arrears)
	) as b
	on a.borrower_identifier = b.borrower_identifier
	and a.loan_identifier = b.loan_identifier
),

temp_tbl2 as (

(
	select 
	  months_in_arrears,
	  segment,
	  round(sum(current_balance * pd_pit_mastered)/ sum(current_balance),2) as avg_pd,
	  round(sum(current_balance * lgd)/ sum(current_balance),2) as avg_lgd
	from temp_tbl1
	group by segment, months_in_arrears) 
union(
	select 
	  months_in_arrears,
	  'total' as segment,
	  round(sum(current_balance * pd_pit_mastered)/ sum(current_balance),2) as avg_pd,
	  round(sum(current_balance * lgd)/ sum(current_balance),2) as avg_lgd
	from temp_tbl1
	group by months_in_arrears)
)

select 
	tbl.*,	
	tbl2.avg_pd,
	tbl2.avg_lgd
from temp_tbl tbl
left join temp_tbl2 as tbl2
using(months_in_arrears,segment)
order by segment,months_in_arrears


/*
select * from credit_risk_playground.stg_mrt_rabobank_arrears_list 
where pool_cut_off_date in ('2025-03-31','2025-04-30', '2025-05-31', '2025-06-30')
order by borrower_identifier, pool_cut_off_date
*/

/* Neo arrears and default stats */
----------------------------------
with report_date as(

	select '2026-05-31'::date as reporting_date
),

arrears as(
select 
	arrList.* 
from credit_risk_playground.stg_mrt_neo_arrears_list as arrList
inner join report_date as rdate
on arrList.pool_cut_off_date::date  = rdate.reporting_date 
),

temp_tbl as (
	(select 
		pool_cut_off_date,
		months_in_arrears,
		'total' as segment,
		count(distinct borrower_identifier) as customers,
		round(sum(current_balance)) as principal_balance,
		round(sum(arrears_balance_loan_level)) as arrears_balance
	from arrears
	group by 1, 2
	order by 1, 2)
	union (
	select 
		pool_cut_off_date,
		months_in_arrears,
		segment,
		count(distinct borrower_identifier) as customers,
		round(sum(current_balance)) as principal_balance,
		round(sum(arrears_balance_loan_level)) as arrears_balance
	from arrears
	group by 1, 2, 3
	order by 1, 2, 3
	)
	order by pool_cut_off_date, months_in_arrears
	),

	temp_tbl1 as (
	select 
	  a.*,
	  b.pd_pit_mastered,
	  b.lgd
	 from arrears as a
	 left join (
	 	select 
	 		borrower_identifier,
	 		loan_identifier,
	 		pd_pit_mastered,
	 		lgd
		from credit_risk_playground.stg_mrt_neo_credit_risk_calculations 
		where pool_cut_off_date = (select max(pool_cut_off_date) from credit_risk_playground.stg_mrt_neo_credit_risk_calculations)
		and borrower_identifier in (select distinct borrower_identifier from arrears)
	) as b
	on a.borrower_identifier = b.borrower_identifier
	and a.loan_identifier = b.loan_identifier
),

temp_tbl2 as (

(
	select 
	  months_in_arrears,
	  segment,
	  round(sum(current_balance * pd_pit_mastered)/ sum(current_balance),2) as avg_pd,
	  round(sum(current_balance * lgd)/ sum(current_balance),2) as avg_lgd
	from temp_tbl1
	group by segment, months_in_arrears) 
union(
	select 
	  months_in_arrears,
	  'total' as segment,
	  round(sum(current_balance * pd_pit_mastered)/ sum(current_balance),2) as avg_pd,
	  round(sum(current_balance * lgd)/ sum(current_balance),2) as avg_lgd
	from temp_tbl1
	group by months_in_arrears)
)

select 
	tbl.*,	
	tbl2.avg_pd,
	tbl2.avg_lgd
from temp_tbl tbl
left join temp_tbl2 as tbl2
using(months_in_arrears,segment)
order by segment,months_in_arrears


--------------------
select 
 pool_cut_off_date,
 borrower_identifier,
 months_in_arrears
 
from credit_risk_playground.stg_mrt_neo_arrears_list 
where pool_cut_off_date in ('2026-03-31')  --- , '2025-06-30'
group by 1,2
order by borrower_identifier, pool_cut_off_date

select * from credit_risk_playground.stg_mrt_neo_arrears_list
where pool_cut_off_date in ('2026-03-31') and months_in_arrears = 'default'
order by consecutive_months_in_arrears desc, borrower_identifier, loan_identifier 




select * from credit_risk_playground.stg_mrt_neo_esme_raw
where account_status = 'DTCR' and pool_cut_off_date = '2026-03-31'






