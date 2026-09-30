
select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
where Instrument_Id like ('2267969%')
and calc_date in ('2026-05-31', '2026-06-30')


SELECT *,  LEFT(Instrument_Id, 7)
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
WHERE LEFT(Instrument_Id, 7) IN (
    '2154012', 
    '2179154', 
    '2197596', 
    '2202157', 
    '2236870', 
    '2239212', 
    '2240948', 
    '2250773', 
    '2252928', 
    '2253441', 
    '2256591', 
    '2271466', 
    '2277458', 
    '2280532'
)
AND calc_date IN ('2026-05-31', '2026-06-30');


select * from credit_risk_playground.stg_mrt_neo_credit_risk_calculations_with_scenarios
where pool_cut_off_date = '2026-07-31'
and pd_pit_down_scen <> pd_pit_up_scen 
limit 100;

select * from credit_risk_playground.stg_mrt_ifrs9_ecl_reporting_with_scenarios limit 100;






SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE borrower_identifier = '5470102'
    order by pool_cut_off_date desc
    -- pool_cut_off_date = '2026-07-31'
    --and account_status = 3
    
5470102
5700774


5446136
5476850

SELECT DISTINCT borrower_identifier
    FROM credit_risk_playground.stg_mrt_neo_arrears_list
    WHERE pool_cut_off_date = '2026-07-31'
    and account_status = 3



Arrear:
5622437 -
5638173 -
5446136 -
5485708 -
5665490 -
5480026 -
5476850 -


Neo:
5622437
5446136
5485708
5480026
5665490
5638173
5476850


with temp_tbl as (
select 
    borrower_identifier,
    loan_identifier,
    min(pool_cut_off_date) as def_date
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where account_status = 3
group by  borrower_identifier, loan_identifier
)

select * from temp_tbl
where def_date between  '2026-06-25' and '2026-09-15'     ----25.06.2026 to 15.07.2026
order by def_date,  borrower_identifier, loan_identifier



select *
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
WHERE pool_cut_off_date = '2026-07-31'
AND LEFT(loan_identifier, 7) = '2250773'


select * from credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
where LEFT(Instrument_Id, 7) ='2250773'
and calc_date IN ('2026-07-31')
