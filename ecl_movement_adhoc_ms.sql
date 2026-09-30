(select 
	case when stage::text in (1,2) then '1&2' else '3' end as ifrs9_stage,
	sum(ead) / 1000000 as ead,
	sum(current_balance)  / 1000000 as current_balance,
	sum(undrawn_loanpart)  / 1000000 as deposit_amount,
    sum(ecl_on)/1000000 as ecl
	
from credit_risk_playground.stg_mrt_Mortgage_loan_tape_2025_12_31 
group by 1)
union all (

select 
	'total' as ifrs9_stage,
	sum(ead) / 1000000 as ead,
	sum(current_balance)  / 1000000 as current_balance,
	sum(undrawn_loanpart)  / 1000000 as deposit_amount,
    sum(ecl_on)/1000000 as ecl
	-- sum(ecl_on)
	
from credit_risk_playground.stg_mrt_Mortgage_loan_tape_2025_12_31
)
order by 1


------- table 3
select 
	reportdate,
	sum(onbalance_ead) / 1000000 as ead,
	sum(ecl_on) / 1000000 as ecl,
	sum(ecl_on) ecl1,
	100 * ecl / ead as coverage_pct
	
from credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios 
where reportdate in ('2024-12-31', '2025-12-31', '2026-06-30', '2026-03-31')
group by reportdate
order by reportdate
-- 341,627.73

--- table 2------------ecl movement and impact --------

with clean_ecl_table as (
select * from (
select 
		*,
		row_number() over(partition by reportdate, instrument_id order by reportdate, instrument_id) as dups
		from credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios 
		)
where dups = 1
and reportdate::date between '2025-12-31'::date and '2026-06-30'::date
),

instruments_set as (
select distinct instrument_id 
from clean_ecl_table
where reportdate::date between '2025-12-31'::date and '2026-06-30'::date
), 

max_ecl as (
select 
  instrument_id, 
  max(ecl_on) as ecl_max,
  max(stage) as stage_max
from clean_ecl_table
where reportdate::date between '2025-12-31'::date and '2026-06-30'::date 
group by 1 
), 

test_tb as (

  select 
  	  a.reportdate, 
	  a.instrument_id, 
	  a.ecl_on, 
	  ecl_max,
	  ecl_max - a.ecl_on as diff,
	  stage_max
  from clean_ecl_table as a left join max_ecl as b
  using (instrument_id)
  order by reportdate
),

elc_overview as (
 
      select  
	   reportdate,
	   sum(ecl_on) as ecl, 
	   sum(ecl_max) as ecl_max 
	   from test_tb 
	   group by 1
	   order by 1
 )
 ,

write_offs as (
select
user_id,
instrument_id,
0 as write_off_amount
from clean_ecl_table
), 

total as (
select distinct i.instrument_id 
, p.onbalance_ead as onbalance_ead_start 
, c.onbalance_ead as onbalance_ead_end
, coalesce(p.ecl_on,0) as ecl_start
, coalesce(m.ecl_max,0) as ecl_max
, coalesce(c.ecl_on,0) as ecl_end
, ecl_end - ecl_start as ecl_change
, coalesce(w.write_off_amount,0) as write_off
,  greatest(0,ecl_max - ecl_start) as zuführung_old
,  greatest(0, ecl_end - ecl_start) as zuführung

, greatest(ecl_max - ecl_end - write_off, 0) as auflösung_old
, greatest(ecl_start - ecl_end - write_off, 0) as auflösung
, least(write_off,ecl_start) as verbrauch
, ecl_end - ecl_start - zuführung + auflösung + verbrauch as Check_Endbestand
, least(write_off, ecl_max) as direktabschreibungen
, greatest(write_off - ecl_start,0) as nicht_gedeckte_direktabschreibungen
from instruments_set i 
left join clean_ecl_table  p on i.instrument_id = p.instrument_id and p.reportdate::date = '2025-12-31'::date
left join clean_ecl_table  c on i.instrument_id = c.instrument_id and c.reportdate::date = '2026-06-30'::date
left join write_offs w on w.instrument_id = i.instrument_id
left join max_ecl m on m.instrument_id = i.instrument_id
),

final_totals as (

select 
--segment
sum(onbalance_ead_start) as onbalance_ead_start
, sum(onbalance_ead_end) as onbalance_ead_end
, sum(ecl_start) as ecl_start
, sum(ecl_max) as ecl_max
, sum(ecl_end) as ecl_end
, sum(ecl_change) as ecl_change
, sum(write_off) as write_off
, sum(zuführung_old) as zuführung_old
, sum(zuführung) as zuführung
, sum(auflösung_old) as auflösung_old
, sum(auflösung) as auflösung
, sum(direktabschreibungen) as direktabschreibungen
, sum(nicht_gedeckte_direktabschreibungen) as nicht_gedeckte_direktabschreibungen
from total 
)

-- select * from total order by  instrument_id -----= '2195114105' 
select * from final_totals
-- select * from elc_overview
-- select  (auflösung - zuführung -  nicht_gedeckte_direktabschreibungen + 0) / 1000000 from final_totals

select reportdate,
sum(ecl) as ecl,
sum(ecl_on) as ecl_on,
sum(on_balance_ead) as obead,
sum(ead) as ead,
sum(off_balance_eod) as ofbad

from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
group by 1
order by 1;


select reportdate,
sum(ecl_on) as ecl_on,
sum(ecl_off) as ecl_off,
sum(ecl_on+ecl_off) as ecl_tot,
sum(onbalance_ead) as obead,
sum(offbalance_ead) as ofbad,
sum(onbalance_ead+offbalance_ead) as ead_tot

from credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios
group by 1
order by 1;





