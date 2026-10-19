

SELECT reportdate, sum(on_balance_ead), sum(ead), sum(ecl), sum(ecl_on)
FROM credit_risk_playground.stg_mrt_ifrs9_ecl_regReporting_V3
group by 1
ORDER BY reportdate DESC;