import os
import pandas as pd
import redshift_connector
from dotenv import load_dotenv

# ---------------------------------------------------------
# 1. Extract and Clean Data from Excel
# ---------------------------------------------------------
excel_file = "/Users/mohitsinha/Downloads/Copy of Building insurance samples (1).xlsx"
xls = pd.ExcelFile(excel_file)
master_list = []

for tab in xls.sheet_names:
    df = pd.read_excel(xls, sheet_name=tab)
    
    # Standardize column headers to lowercase for reliable matching
    df.columns = [str(c).strip().lower() for c in df.columns]
    
    # Locate the target columns regardless of their position
    nr_pers_col = next((c for c in df.columns if 'nr_pers' in c), None)
    provided_col = next((c for c in df.columns if 'provided' in c), None)
    
    if nr_pers_col and provided_col:
        # Isolate the required columns and standardize their names for the database
        df_clean = df[[nr_pers_col, provided_col]].copy()
        df_clean = df_clean.rename(columns={nr_pers_col: 'nr_pers', provided_col: 'provided'})
        
        # Inject the tab name as the date column
        df_clean['as_of_date'] = tab
        master_list.append(df_clean)

# Combine all extracted tabs into a single master DataFrame
final_df = pd.concat(master_list, ignore_index=True)

# --- NEW: Regex Date Parsing Logic ---
# 1. Search for Month name followed by 2 digits (e.g., "April 26") inside the string
pattern = r'(?i)(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{2})'
extracted = final_df['as_of_date'].str.extract(pattern)

# 2. Combine the extracted groups into a clean string (e.g., "April 26")
clean_date_strs = extracted[0].str.title() + " " + extracted[1]

# 3. Parse strings to datetimes
parsed_dates = pd.to_datetime(clean_date_strs, format='%B %y', errors='coerce')

# 4. Shift to the end of the month and format as YYYY-MM-DD
eom_dates = parsed_dates.dt.to_period('M').dt.to_timestamp(how='end').dt.strftime('%Y-%m-%d')

# 5. Overwrite the column (if no date was found in the tab name, it will keep the original text)
final_df['as_of_date'] = eom_dates.fillna(final_df['as_of_date'])

# --- Column Reordering ---
final_df = final_df[['as_of_date', 'nr_pers', 'provided']]

# Ensure all columns are strings to prevent Redshift schema type clashes during bulk insert
final_df = final_df.astype(str)

# --- Clean German thousand separators from nr_pers ---
# 1. Remove trailing ".0" in case pandas read normal numbers as floats (e.g. "1000.0" -> "1000")
final_df['nr_pers'] = final_df['nr_pers'].str.replace(r'\.0$', '', regex=True)
# 2. Remove the German thousand separator dots (e.g. "1.500" -> "1500")
final_df['nr_pers'] = final_df['nr_pers'].str.replace('.', '', regex=False)

# ---------------------------------------------------------
# 2. Connect to Redshift
# ---------------------------------------------------------
load_dotenv("db.env")

conn = redshift_connector.connect(
    host=os.getenv("REDSHIFT_HOST"),
    port=int(os.getenv("REDSHIFT_PORT", "5439")),
    database=os.getenv("REDSHIFT_DB"),
    user=os.getenv("REDSHIFT_USER"),
    password=os.getenv("REDSHIFT_PASSWORD")
)
conn.autocommit = True  
cursor = conn.cursor()

# ---------------------------------------------------------
# 3. Create Table and Load Data
# ---------------------------------------------------------
target_table = "credit_risk_playground.mrt_insurance_flag"

cursor.execute(f"DROP TABLE IF EXISTS {target_table}")

cursor.execute(f"""
CREATE TABLE {target_table} (
    as_of_date VARCHAR(50),
    nr_pers VARCHAR(255),
    provided VARCHAR(255)
)
""")

# Use redshift_connector's native bulk writing method for high performance
cursor.write_dataframe(final_df, target_table)

print(f"✅ Successfully extracted, cleaned, and loaded {len(final_df)} rows into {target_table}.")