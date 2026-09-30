import os
import json
import datetime
import pandas as pd
import numpy as np
import redshift_connector
from dotenv import load_dotenv
from decimal import Decimal

# 1. Load credentials
load_dotenv("db.env")

# 2. Custom JSON encoder to handle Redshift Date, Datetime, and Decimal objects gracefully
class RedshiftEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime.date, datetime.datetime)):
            return obj.isoformat()
        if isinstance(obj, Decimal):
            return float(obj)
        if pd.isna(obj):
            return None
        return super().default(obj)

target_loan = "2173981"
target_date = "2026-07-31"

# Target Directory Configuration
output_dir = "/Users/mohitsinha/Projects/"
os.makedirs(output_dir, exist_ok=True)
output_filename = os.path.join(output_dir, f"loan_{target_loan}_{target_date}_dwh_extract.json")

# 3. Define the tables by their identifying column
bo_tables = [
    "bo_loan_management_loan",
    "bo_loan_management_loan_part",
    "bo_loan_management_original_loan_part",
    "bo_interest_specification_deed_interest_loan_part",
    "bo_account_management_pool_loan_part",
    "bo_collateral_loan_collateral",
    "bo_loan_mutation_loan",
    "bo_loan_mutation_loan_part",
    "bo_loan_management_intermediary",
    "bo_arrears_payment_arrangement",
    "bo_arrears_over_booking_period",
    "bo_arrear_notification_bkr",
    "bo_arrears_letters_stop",
    "bo_loan_arrears",
    "bo_arrears_status_arrears",
    "bo_arrear_measure",
    "bo_account_management_booking_period",
    "bo_account_management_booking",
    "bo_construction_deposit_deposit",
    "bo_construction_deposit_available_credit",
    "bo_construction_deposit_provisionally_available_credit",
    "bo_construction_deposit_available_credit_payout",
    "bo_construction_deposit_deposit_term",
    "bo_construction_deposits_deposit_payment",
    "bo_other_loan_securities",
    "bo_interest_specification_top_surcharge_loanpart",
    "bo_other_securities_investment_account",
    "bo_interest_specification_agreement_pvr_loan_part",
    "bo_loan_management_loan_part_term_schedule"
]

mo_tables = [
    "mo_collateral_collateral",
    "mo_loan_application_in_process",
    "mo_loan_application_in_process_loan_part",
    "mo_mortgage_application_and_offer_status",
    "mo_credit_check_bkr_application",
    "mo_credit_check_bkr_credit",
    "mo_credit_check_bkr_person",
    "mo_credit_check_credit_score",
    "mo_acceptance_piece",
    "mo_collateral_other_contract",
    "mo_collateral_other_security",
    "mo_collateral_housing_cost_insurance",
    "mo_loaninapplication_for_construction_deposit",
    "mo_policy_savings_account_premium",
    "mo_policy_account_holder",
    "mo_policy_premium_deposit",
    "mo_income_data_collectively",
    "mo_policy_endowment_insurance",
    "mo_policy_insured",
    "mo_collateral_deed_registration",
    "mo_collateral_deed",
    "mo_collateral_security",
    "mo_policy_premium"
]

# Dynamically build the query dictionary
queries = {}
for table in bo_tables:
    queries[table] = f"SELECT * FROM {table} WHERE nr_lnng = {target_loan} AND etl_updated::DATE = '{target_date}'::DATE"

for table in mo_tables:
    queries[table] = f"SELECT * FROM {table} WHERE loannumber = {target_loan} AND etl_updated::DATE = '{target_date}'::DATE"

# Add the special join query for BO Collateral Valuation
queries["bo_collaterals_collateral_valuation"] = f"""
    SELECT val.* FROM bo_collaterals_collateral_valuation val
    JOIN bo_collateral_loan_collateral col ON val.vlgnr_ondrpnd = col.vlgnr_ondrpnd
    WHERE col.nr_lnng = {target_loan} 
      AND col.etl_updated::DATE = '{target_date}'::DATE
      AND val.etl_updated::DATE = '{target_date}'::DATE
"""

loan_data = {}

print("🔌 Connecting to Redshift...")
conn = redshift_connector.connect(
    host=os.getenv("REDSHIFT_HOST"),
    port=int(os.getenv("REDSHIFT_PORT", "5439")),
    database=os.getenv("REDSHIFT_DB"),
    user=os.getenv("REDSHIFT_USER"),
    password=os.getenv("REDSHIFT_PASSWORD")
)
cursor = conn.cursor()
print("✅ Connected!\n")

# 4. Execute queries and build the payload
for table_name, query in queries.items():
    try:
        cursor.execute(query)
        df = cursor.fetch_dataframe()
        
        if not df.empty:
            # Replace NaNs with None for valid JSON serialization
            df = df.replace({np.nan: None})
            loan_data[table_name] = df.to_dict(orient='records')
            print(f"✅ {table_name}: Found {len(df)} rows.")
        else:
            loan_data[table_name] = []
            print(f"➖ {table_name}: 0 rows found.")
            
    except Exception as e:
        print(f"❌ {table_name}: Failed -> {str(e)}")
        loan_data[table_name] = {"error": str(e)}

conn.close()

# 5. Export to JSON using the new RedshiftEncoder
with open(output_filename, "w", encoding="utf-8") as f:
    json.dump(loan_data, f, indent=4, cls=RedshiftEncoder)

print(f"\n🎉 Success! Extract saved to: {output_filename}")