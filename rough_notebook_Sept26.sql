SELECT * FROM reference_crm_consumers
LIMIT 10;


select * from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
limit 100;

select kd_srt_tax_oms, count(*) 
from bo_collaterals_collateral_valuation
group by 1
limit 100;

select * from bo_collateral_loan_collateral
limit 100;

bedr_vov


select 



select borrower_identifier, 
count(distinct property_identifier), 
--loan_identifier, 
count(distinct loan_identifier) as vol from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
group by 1
having count(distinct property_identifier) > 1
--having count(*) > 1
--order by 3 DESC
limit 100;

select * from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
and borrower_identifier in (
'5547883',
'5483909',
'5612518',
'5549655',
'5459190',
'5443950',
'5692493',
'5407099',
'5571449',
'5571081',
'5603210',
'5646367'
)
order by borrower_identifier, property_identifier, loan_identifier

select vlgnr_ondrpnd, 
-- kd_srt_tax_oms, count(*) 
from bo_collaterals_collateral_valuation
--group by 1
limit 100;

select nr_lnng, vlgnr_ondrpnd, count(*) as vol
from bo_collateral_loan_collateral
where etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
group by 1,2
having count(*) > 1


WITH esma_data AS (
    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = '2026-07-31'
),
collateral_details AS (
    SELECT 
        a.vlgnr_ondrpnd,
        b.kd_srt_tax_oms
    FROM bo_collateral_loan_collateral a
    LEFT JOIN bo_collaterals_collateral_valuation b
        ON a.vlgnr_ondrpnd = b.vlgnr_ondrpnd
    WHERE a.etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
      AND b.etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
)
SELECT 
	e.borrower_identifier,
	e.property_identifier,
	c.kd_srt_tax_oms,
    count(*)
FROM esma_data e
LEFT JOIN collateral_details c
    ON e.property_identifier = c.vlgnr_ondrpnd::VARCHAR
WHERE c.kd_srt_tax_oms NOT IN ('Desktoptaxatie', 'Taxatierapport', 'Geen', 'WOZ Beschikking')
group by 1,2,3;



select count(*)
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
where pool_cut_off_date = '2026-07-31'
and payment_type = '6'
and original_balance > (0.98*valuation_amount)
limit 100;



select * from reference_crm_consumers_fiscal_residence_situation
limit 100;

select * from bo_arrear_notification_bkr
limit 100;



WITH loan_parts AS (
    SELECT *
    FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
),
bkr_arrears AS (
    SELECT *
    FROM bo_arrear_notification_bkr
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_arrear_notification_bkr)
)
SELECT 
    l.*,
    
	b.notification_id,     -- e.g., 7500000064585
    b.dtm_start,           -- e.g., 2025-05-08 00:00:00.000
    b.bkr_code_1,          -- e.g., 01
    b.bkr_type,            -- e.g., HY
    b.dtm_end,             -- e.g., 2025-05-08 00:00:00.000
    b.bkr_status_code,     -- e.g., 2
    b.bkr_status_desc,     -- e.g., 2 via LL 29042025
    b.contract_status,     -- e.g., Nieuw contract
    b.product_type,        -- e.g., Hypotheek
    b.etl_updated AS bkr_etl_updated
    
FROM loan_parts AS l
LEFT JOIN bkr_arrears AS b
    ON l.nr_lnng = b.nr_lnng

    limit 100;


SELECT *
FROM mo_collateral_collateral
limit 100;

select * from bo_loan_management_loan limit 100;

SELECT 
    neo_esme.loan_identifier, isavailablevaluationreport, col.constructionplan, col.constructionsite, col.buildtype
FROM 
    credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw AS neo_esme
JOIN 
    mo_collateral_collateral AS col
    ON neo_esme.property_identifier = col.collateralindexnumber
WHERE 
    neo_esme.pool_cut_off_date = {{pool_cut_off_date}}
    AND col.etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
    AND (
        col.isavailablevaluationreport IS NULL
        OR col.isavailablevaluationreport NOT IN ('Y', 'DesktopTaxation', 'N', 'WOZ Beschikking')
        OR (
            col.isavailablevaluationreport = 'N' 
            AND col.constructionplan IS NULL
            AND col.constructionsite IS NULL
            AND col.buildtype IS NULL
        )
        OR (
            col.isavailablevaluationreport = 'WOZ Beschikking'
            AND col.loannumber NOT IN (SELECT nr_lnng FROM bo_loan_management_loan)
        )
    );


bo_loan_management_loan_part
bo_collaterals_collateral_valuation


select * from bo_collateral_loan_collateral
limit 100;

select * from bo_collaterals_collateral_valuation
limit 100;


select * from bo_loan_management_loan_part
limit 100;


WITH esma_data AS (
    SELECT 
        loan_identifier, 
        property_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
collateral_details AS (
    SELECT 
        a.vlgnr_ondrpnd,
        a.kd_ondrpnd_stat_oms,
        b.bedr_vov
    FROM bo_collateral_loan_collateral a
    left JOIN bo_collaterals_collateral_valuation b
        ON a.vlgnr_ondrpnd = b.vlgnr_ondrpnd
    WHERE a.etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
      AND b.etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
  --    AND a.kd_ondrpnd_stat_oms = 'Overbrugging'
)
select kd_ondrpnd_stat_oms, count(*)
from collateral_details
group by 1


where vlgnr_ondrpnd = 3857860
select * from esma_data
where property_identifier = '3857860'


select e.loan_identifier, e.property_identifier, col.vlgnr_ondrpnd
from esma_data e left join collateral_details col
on e.property_identifier = col.vlgnr_ondrpnd::VARCHAR

limit 100;

select count(distinct vlgnr_ondrpnd)
--vlgnr_ondrpnd, kd_ondrpnd_stat_oms 
from bo_collateral_loan_collateral
WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
and kd_ondrpnd_stat_oms = 'Overbrugging'
limit 100;


select count(distinct vlgnr_ondrpnd)
FROM bo_collaterals_collateral_valuation
where etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
and vlgnr_ondrpnd = 3871041



loan_part_details AS (
    SELECT 
        CONCAT(nr_lnng::VARCHAR, nr_lnngdl::VARCHAR) AS loan_part_id,
        bedr_hfdsm_lnngdl
    FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
      AND aantl_mnd_rntevst = 30
)
SELECT 
    e.loan_identifier,
    e.property_identifier,
    c.kd_ondrpnd_stat_oms,
    c.bedr_vov,
    l.bedr_hfdsm_lnngdl
FROM esma_data e
JOIN collateral_details c
    ON e.property_identifier = c.vlgnr_ondrpnd::VARCHAR
JOIN loan_part_details l
    ON e.loan_identifier = l.loan_part_id;
	
select count(distinct (CONCAT(nr_lnng::VARCHAR, nr_lnngdl::VARCHAR)))
FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
      AND aantl_mnd_rntevst = 30
      
 select count (distinct loan_identifier)
 FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    and loan_term <=30
    
    
WITH esma_loans AS (
    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
loan_parts AS (
    SELECT 
        nr_lnng,
        nr_lnngdl,
        aantl_mnd_rntevst
    FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
)
SELECT 
    a.*,
    CASE 
        WHEN b.aantl_mnd_rntevst = 30 THEN TRUE 
        ELSE FALSE 
    END AS is_bridge

FROM esma_loans AS a
LEFT JOIN loan_parts AS b
    -- Uses the exact CONCAT logic from your count query
    ON a.loan_identifier = CONCAT(b.nr_lnng::VARCHAR, b.nr_lnngdl::VARCHAR)
where b.aantl_mnd_rntevst = 30;


    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
and borrower_identifier = 5621741;

select *
FROM bo_collaterals_collateral_valuation
where etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
and vlgnr_ondrpnd = 3866688

select *
from bo_collateral_loan_collateral
WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
and 1=1
--kd_ondrpnd_stat_oms = 'Overbrugging'
--and vlgnr_ondrpnd = 3875949
and nr_lnng = 2264423



    SELECT 
        *
    FROM bo_loan_management_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan_part)
    and 1=1
    -- and nr_lnng = 2189413
    and aantl_mnd_rntevst = 30

    bo_loan_management_loan
    
        SELECT 
        *
    FROM bo_loan_management_loan
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan)
    and 1=1
    and nr_lnng = 2189413
    --and aantl_mnd_rntevst = 30

2189413

3693069



 select *
 FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    --and loan_term <=30
    --and property_identifier = '3875949'
    
 WITH esma_loans AS (
    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
collateral_valuations AS (
    SELECT 
        a.nr_lnng,
        b.vlgnr_ondrpnd,
        b.bedr_vov,
        -- Ranks valuations per loan: oldest etl_updated first, then lowest vlgnr_ondrpnd as tie-breaker
        ROW_NUMBER() OVER(
            PARTITION BY a.nr_lnng 
            ORDER BY b.etl_updated ASC, b.vlgnr_ondrpnd ASC
        ) as rn
    FROM bo_collateral_loan_collateral a
    INNER JOIN bo_collaterals_collateral_valuation b
        ON a.vlgnr_ondrpnd = b.vlgnr_ondrpnd
    -- Keep the latest mapping between loan and collateral, but get historical valuation
    WHERE a.etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
)
SELECT 
	e.loan_identifier,
	e.borrower_identifier,
    e.original_balance,
    e.payment_type,
    c.bedr_vov AS earliest_valuation_amount
FROM esma_loans AS e
LEFT JOIN collateral_valuations AS c
    -- Matches the first 7 characters of loan_identifier to nr_lnng
    ON SUBSTRING(e.loan_identifier, 1, 7) = c.nr_lnng::VARCHAR
    AND c.rn = 1
    and e.original_balance > (0.98*c.bedr_vov);
    
 

SELECT collateralstatus, marketvalue
FROM mo_collateral_collateral
WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
group by 1
limit 100;

substring(a.loan_identifier,1,7)::numeric = b.loannumber::numeric




select * from mo_loan_application_in_process_loan_part
limit 100;


WITH esma_loans AS (
    SELECT 
        loan_identifier,
        borrower_identifier,
        original_balance,
        valuation_amount,
        loan_term,
        payment_type
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
collaterals AS (
    SELECT 
        loannumber,
        collateralstatus,
        marketvalue,
        ROW_NUMBER() OVER(PARTITION BY loannumber ORDER BY marketvalue DESC) as rn
    FROM mo_collateral_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
),
loan_parts AS (
    SELECT 
        loannumber,
        creditamount,
        ROW_NUMBER() OVER(PARTITION BY loannumber ORDER BY creditamount DESC) as rn
    FROM mo_loan_application_in_process_loan_part
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_loan_application_in_process_loan_part)
)
SELECT 
    a.loan_identifier,
    a.borrower_identifier,
    a.original_balance,
    a.valuation_amount,
    a.loan_term,
    a.payment_type,
    b.collateralstatus,
    b.marketvalue,
    c.creditamount
FROM esma_loans AS a
LEFT JOIN collaterals AS b
    ON SUBSTRING(a.loan_identifier, 1, 7)::NUMERIC = b.loannumber::NUMERIC
    AND b.rn = 1
LEFT JOIN loan_parts AS c
    ON SUBSTRING(a.loan_identifier, 1, 7)::NUMERIC = c.loannumber::NUMERIC
    AND c.rn = 1
-- Applied in the overall query here:
WHERE b.collateralstatus = 'BridgingCollateral'
and c.creditamount > (0.98*b.marketvalue);

select * from credit_risk_playground.mrt_insurance_flag



select * from dbt.macro_economic_scenarios 
where tnc_country = 'NLD'
order by reference_date desc
limit 100;

WITH esma_loans AS (
    SELECT 
        loan_identifier,
        borrower_identifier,
        original_balance,
        valuation_amount,
        loan_term,
        payment_type
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
collaterals AS (
    SELECT 
        loannumber,
        collateralstatus,
        marketvalue,
        ROW_NUMBER() OVER(PARTITION BY loannumber ORDER BY marketvalue DESC) as rn
    FROM mo_collateral_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
)
SELECT 
    a.loan_identifier,
    a.borrower_identifier,
    a.original_balance,
    a.valuation_amount,
    a.loan_term,
    a.payment_type,
    b.collateralstatus,
    b.marketvalue
FROM esma_loans AS a
LEFT JOIN collaterals AS b
    ON SUBSTRING(a.loan_identifier, 1, 7)::NUMERIC = b.loannumber::NUMERIC
    AND b.rn = 1
WHERE a.borrower_identifier = '5673507'


 WITH esma_loans AS (
    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
collateral_valuations AS (
    SELECT 
        a.nr_lnng,
        b.vlgnr_ondrpnd,
        b.bedr_vov,
        -- Ranks valuations per loan: oldest etl_updated first, then lowest vlgnr_ondrpnd as tie-breaker
        ROW_NUMBER() OVER(
            PARTITION BY a.nr_lnng 
            ORDER BY b.etl_updated ASC, b.vlgnr_ondrpnd ASC
        ) as rn
    FROM bo_collateral_loan_collateral a
    INNER JOIN bo_collaterals_collateral_valuation b
        ON a.vlgnr_ondrpnd = b.vlgnr_ondrpnd
    -- Keep the latest mapping between loan and collateral, but get historical valuation
    WHERE a.etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
)
SELECT 
	e.loan_identifier,
	e.borrower_identifier,
    e.original_balance,
    e.payment_type,
    c.bedr_vov AS earliest_valuation_amount
FROM esma_loans AS e
LEFT JOIN collateral_valuations AS c
    -- Matches the first 7 characters of loan_identifier to nr_lnng
    ON SUBSTRING(e.loan_identifier, 1, 7) = c.nr_lnng::VARCHAR
    AND c.rn = 1
    and e.borrower_identifier = '5673507';
 
 
 select * from 
 credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    and borrower_identifier = '5673507';
 
 
 select * from bo_collaterals_collateral_valuation
 where vlgnr_ondrpnd = 3933479
 order by etl_updated desc
 
select collateralindexnumber, marketvalue from mo_collateral_collateral 
where etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
and collateralindexnumber = 3933479
limit 100;
 
WITH esma_loans AS (
    -- Step 1: Calculate the qualifying loan balance per borrower
    SELECT 
        borrower_identifier,
        SUM(CASE 
            WHEN payment_type = '6' AND loan_term > 30 THEN original_balance 
            ELSE 0 
        END) AS sum_qualifying_balance
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    GROUP BY borrower_identifier
),
unique_borrower_properties AS (
    -- Step 2: Get a distinct list of properties per borrower to avoid double-counting
    SELECT DISTINCT 
        borrower_identifier,
        property_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
      AND property_identifier IS NOT NULL
),
latest_collateral AS (
    -- Step 3: Get the latest market values (with ROW_NUMBER to prevent any internal fan-out)
    SELECT 
        collateralindexnumber,
        marketvalue,
        ROW_NUMBER() OVER(PARTITION BY collateralindexnumber ORDER BY marketvalue DESC) as rn
    FROM mo_collateral_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
),
borrower_valuations AS (
    -- Step 4: Map properties to collaterals and sum the market values per borrower
    SELECT 
        bp.borrower_identifier,
        CEIL(SUM(c.marketvalue)) AS total_valuation
    FROM unique_borrower_properties bp
    INNER JOIN latest_collateral c
        -- Cast the INT to VARCHAR to match the ESMA property_identifier type
        ON bp.property_identifier = c.collateralindexnumber::VARCHAR 
        AND c.rn = 1
    GROUP BY bp.borrower_identifier
)
-- Step 5: Join the loan sums and valuation sums, then count
SELECT 
    *
FROM esma_loans l
INNER JOIN borrower_valuations v
    ON l.borrower_identifier = v.borrower_identifier
WHERE l.sum_qualifying_balance > (0.5 * v.total_valuation);


select * from bo_loan_management_loan 
where etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan)


WITH esma_loans AS (
    SELECT 
        borrower_identifier,
        SUBSTRING(loan_identifier, 1, 7) as loan_identifier_number,
        SUM(CASE 
            WHEN payment_type = '6' AND loan_term > 30 THEN original_balance 
            ELSE 0 
        END) AS sum_qualifying_balance
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    GROUP BY 1,2
),
unique_borrower_properties AS (
    SELECT DISTINCT 
        borrower_identifier,
        SUBSTRING(loan_identifier, 1, 7) as loan_identifier_number,
        property_identifier
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
      AND property_identifier IS NOT NULL
),
latest_collateral AS (
    SELECT 
        collateralindexnumber,
        marketvalue,
        ROW_NUMBER() OVER(PARTITION BY collateralindexnumber ORDER BY marketvalue DESC) as rn
    FROM mo_collateral_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
),
borrower_valuations AS (
    SELECT 
        bp.borrower_identifier,
        bp.loan_identifier_number,
        CEIL(SUM(c.marketvalue)) AS total_valuation
    FROM unique_borrower_properties bp
    INNER JOIN latest_collateral c
        ON bp.property_identifier = c.collateralindexnumber::VARCHAR 
        AND c.rn = 1
    GROUP BY 1,2
)
SELECT 
    v.borrower_identifier, v.loan_identifier_number, l.sum_qualifying_balance, v.total_valuation
FROM esma_loans l
INNER JOIN borrower_valuations v
    ON l.borrower_identifier = v.borrower_identifier
WHERE l.sum_qualifying_balance > (0.5 * v.total_valuation);
 


SELECT *
FROM pooldownload_ln_310
WHERE cut_off_date = (
    SELECT MAX(cut_off_date) 
    FROM pooldownload_ln_310
    
    
    
    
--- query to select loans for purchase_date
with rep_date as (

	select '2026-07-31'::date as pool_cut_off_date

),

selected_loans as (
select * from credit_risk_playground.stg_neo_loan_purchases
inner join rep_date 
using(pool_cut_off_date)
)


select 
    sum(original_balance) as total_original_balance,
    sum(net_current_balance) as total_current_balance,
	sum(retained_amount) as retained_balance,
	count(distinct borrower_identifier) as borrowers,
	count(distinct loan_identifier) as loans,
	count(*) as datapoints,
	avg(current_loan_to_value) as ltv,
    100* avg(pd) as avg_pd,
	100* avg(lgd) as avg_lgd,
	100 * sum(ecl) / total_current_balance as ecl
from selected_loans;



select * from selected_loans order by borrower_identifier, loan_identifier;
);


select * from dbt.macro_economic_scenarios 
where tnc_country = 'NLD'
order by reference_date desc
limit 100;

select * from credit_risk_playground.macroeconomic_scenarios_v3
where tnc_country = 'NLD'
--and scenario_date = '2025-07-31'
order by scenario_date desc, reference_date desc
limit 10;


select * from dbt_snapshots.macro_economic_scenarios_snapshot
limit 100;

select * from dev_dbt.spaces_users_day limit 10;

select * 
    FROM credit_risk_playground.stg_mrt_neo_esme_raw
WHERE 1=1
--and pool_cut_off_date = '2026-07-31' 
and loan_identifier_number = '2185742'
order by pool_cut_off_date desc



select * from mo_mortgage_application_and_offer_application
where 1=1
--and loannumber = 2190557
and etl_updated = (SELECT MAX(etl_updated) FROM mo_mortgage_application_and_offer_application)
and purpose = 'Consumptive'
limit 100;


select * from mo_mortgage_application_and_offer_application
where 1=1
--and loannumber = 2190557
and etl_updated = (SELECT MAX(etl_updated) FROM mo_mortgage_application_and_offer_application)
limit 100;


WITH esma_base AS (
    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
),
latest_loan AS (
    SELECT 
        nr_lnng, 
        bedr_cnsmptf
    FROM bo_loan_management_loan
    WHERE bedr_cnsmptf > 0
      AND etl_updated = (SELECT MAX(etl_updated) FROM bo_loan_management_loan)
),
latest_collateral AS (
    SELECT 
        nr_lnng, 
        vlgnr_ondrpnd
    FROM bo_collateral_loan_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collateral_loan_collateral)
),
latest_valuation AS (
    SELECT 
        vlgnr_ondrpnd, 
        bedr_vov
    FROM bo_collaterals_collateral_valuation
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM bo_collaterals_collateral_valuation)
),
latest_application AS (
    SELECT 
        loannumber,
        purpose
    FROM mo_mortgage_application_and_offer_application
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_mortgage_application_and_offer_application)
      AND purpose = 'Consumptive'
)
SELECT 
	distinct l.nr_lnng,
--	e.original_balance,
	l.bedr_cnsmptf,
	v.bedr_vov
FROM esma_base AS e
LEFT JOIN latest_loan AS l
    ON SUBSTRING(e.loan_identifier, 1, 7) = l.nr_lnng::VARCHAR
LEFT JOIN latest_collateral AS c
    ON l.nr_lnng = c.nr_lnng
LEFT JOIN latest_valuation AS v
    ON c.vlgnr_ondrpnd = v.vlgnr_ondrpnd
LEFT JOIN latest_application AS a
    ON c.nr_lnng = a.loannumber::VARCHAR
WHERE 1=1
and l.bedr_cnsmptf > (0.5 * v.bedr_vov) 
         AND a.loannumber IS NOT NULL ;




WITH esma_loans AS (
    SELECT 
        SUBSTRING(loan_identifier, 1, 7) as loan_identifier_number,
        SUM(CASE 
            WHEN payment_type = '6' AND loan_term > 30 THEN original_balance 
            ELSE 0 
        END) AS sum_qualifying_balance
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
    GROUP BY 1
),
latest_collateral AS (
    SELECT 
        loannumber,
    	collateralindexnumber,
        appliedmarketvalue,
        ROW_NUMBER() OVER(PARTITION BY collateralindexnumber ORDER BY applicationindexnumber DESC) as rn
    FROM mo_collateral_collateral
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
),
borrower_valuations AS (
    SELECT 
        e.loan_identifier_number,
        CEIL(SUM(c.appliedmarketvalue)) AS total_valuation
    FROM esma_loans e
    LEFT JOIN latest_collateral c
        ON e.loan_identifier_number  = c.loannumber::VARCHAR 
        AND c.rn = 1
    GROUP BY 1
)
SELECT 
    e.loan_identifier_number, e.sum_qualifying_balance, v.total_valuation
FROM esma_loans e
left join borrower_valuations v
on e.loan_identifier_number = v.loan_identifier_number
WHERE sum_qualifying_balance > (0.5 * total_valuation)
LIMIT 10;

/* Repayment Method Description:
Type of principal repayment: 
 Interest Only (1)
 Repayment (2)
 Endowment (3)
 Pension (4)
 ISA/PEP (5)
 Index-Linked (6)
 Part & Part (7)
 Savings Mortgage (8)
 Other (9)
 No Data (ND)
 */

latest_collateral AS (
    SELECT 
        collateralindexnumber,
        appliedmarketvalue,
        ROW_NUMBER() OVER(PARTITION BY collateralindexnumber ORDER BY applicationindexnumber) as rn
    FROM mo_collateral_collateral
    WHERE 1=1
    and etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
   -- and collateralindexnumber = 3689098
   and rn > 1;


    SELECT 
    	loannumber,
--        collateralindexnumber, 
--        applicationindexnumber
        count(*) as vol
        --appliedmarketvalue,
        --ROW_NUMBER() OVER(PARTITION BY collateralindexnumber ORDER BY applicationindexnumber) as rn
    FROM mo_collateral_collateral
    where etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
    group by 1
    having count(*) > 1

select loannumber, isavailablevaluationreport, constructionplan, constructionsite, buildtype
from mo_collateral_collateral
where etl_updated = (SELECT MAX(etl_updated) FROM mo_collateral_collateral)
and loannumber = 2251151


WITH esma_borrowers AS (
    SELECT DISTINCT 
        borrower_identifier,
        loan_origination_date
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
	AND loan_origination_date > '2025-10-31'
),
crm_consumers AS (
    SELECT 
        nr_pers,
        kd_ntnltt
    FROM etl_reporting.reference_crm_consumers 
    WHERE etl_updated = (SELECT MAX(etl_updated) FROM etl_reporting.reference_crm_consumers)
)
SELECT 
--    count(a.borrower_identifier) as control_num
loan_origination_date, count(*) AS vol
FROM esma_borrowers AS a
LEFT JOIN crm_consumers AS b
    ON a.borrower_identifier = b.nr_pers
WHERE UPPER(b.kd_ntnltt) NOT IN 
(-- EFTA (4 countries)
    'IS', 'LI', 'NO', 'CH',
    
    -- EU (27 countries)
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 
    'GR', 'EL', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 
    'PT', 'RO', 'SK', 'SI', 'ES', 'SE'
)
GROUP BY 1;



    SELECT *
    FROM credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw
    WHERE pool_cut_off_date = {{pool_cut_off_date}}
	AND loan_origination_date::date > '2025-11-01'::date
	AND borrower_identifier in ('5698671', '5711152', '5709800', '5708323')

SELECT 

