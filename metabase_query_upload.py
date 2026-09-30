import requests
import uuid

# --- Configuration ---
METABASE_URL = "https://metabase-critical.tech26.de"
SESSION_TOKEN = "2f1d5b73-a7ff-48da-b294-2be19d7da506"
DATABASE_ID = 2
COLLECTION_ID = 438 # Folder ID

QUERY_1 = """SELECT neo_base.loan_identifier
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw neo_base
left join mo_collateral_collateral coll
ON SUBSTRING(neo_base.loan_identifier, 1, 7)::NUMERIC = coll.loannumber::NUMERIC
WHERE 1=1
AND pool_cut_off_date = {{pool_cut_off_date}}
and coll.country NOT IN ('NL')
limit 5;"""

QUERY_2 = """SELECT neo_base.loan_identifier
from credit_risk_playground.stg_mrt_neo_esma_to_ecb_raw neo_base
left join mo_collateral_collateral coll
ON SUBSTRING(neo_base.loan_identifier, 1, 7)::NUMERIC = coll.loannumber::NUMERIC
WHERE 1=1
AND pool_cut_off_date = {{pool_cut_off_date}}
and coll.country NOT IN ('NL')"""

headers = {
    "X-Metabase-Session": SESSION_TOKEN,
    "Content-Type": "application/json"
}

def create_question(name, query_string):
    tag_id = str(uuid.uuid4())
    payload = {
        "name": name,
        "dataset_query": {
            "type": "native",
            "native": {
                "query": query_string,
                "template-tags": {
                    "pool_cut_off_date": {
                        "id": tag_id,
                        "name": "pool_cut_off_date",
                        "display-name": "Pool Cut Off Date",
                        "type": "date",
                        "default": "2026-06-30",
                        "required": True
                    }
                }
            },
            "database": DATABASE_ID
        },
        "display": "table",
        "visualization_settings": {},
        "collection_id": COLLECTION_ID
    }
    
    response = requests.post(f"{METABASE_URL}/api/card", headers=headers, json=payload)
    if response.status_code == 200:
        print(f"Created: {name}")
    else:
        print(f"Failed {name}: {response.status_code} - {response.text}")

# --- EXECUTION ---
control_names = [
    "Age Control",
    "Nationality Control",
    "Residence Control",
    "Income Country Control",
    "Arrear Control",
    "Recent arrear BKR Control",
    "Risk BKR Control"
]

for name in control_names:
    create_question(name, QUERY_1)

for name in control_names:
    create_question(f"{name} Samples", QUERY_2)