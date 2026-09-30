import pandas as pd
import glob
import json
import os
import numpy as np
import re

# 1. Define paths
csv_directory = "/Users/mohitsinha/Downloads/N26_DDS2_full_20260901/" 

mapping_file = "/Users/mohitsinha/Downloads/Dutch_Mortgage_table_name_mappings.xlsx - Mapping DDS files & tables.csv"
output_file = "llm_bridge_catalog_v3.json"

# 2. Load and prep the Mapping File
mapping_df = pd.read_csv(mapping_file)

# Build a dictionary to match base file names (stripping the YYYYMMDD date suffix)
table_mapping = {}
for _, row in mapping_df.iterrows():
    if pd.notna(row['filename']):
        # Extract base name by removing the _YYYYMMDD.csv part
        base_name = re.sub(r'_\d{8}\.csv$', '', str(row['filename']).strip())
        table_mapping[base_name] = {
            "dwh_table_name": row['dwh_table_name'],
            "english_name": row['eng_name']
        }

bridge_catalog = {}

# 3. Iterate through your actual 106 CSVs
for filepath in glob.glob(os.path.join(csv_directory, "*.csv")):
    filename = os.path.basename(filepath)
    
    # Identify the base name to match with the mapping file
    base_name_actual = re.sub(r'_\d{8}\.csv$', '', filename)
    
    # Get mapping data (default to Unknown if it cannot find a match)
    mapping_data = table_mapping.get(base_name_actual, {
        "dwh_table_name": "Unknown / Unmapped",
        "english_name": "Unknown"
    })
    
    try:
        # Load sample data with semicolon delimiter and UTF-8 encoding
        df = pd.read_csv(filepath, sep=';', nrows=10, encoding='utf-8', on_bad_lines='skip')
        df = df.replace({np.nan: None})
        
        bridge_catalog[filename] = {
            "dwh_table_name": mapping_data["dwh_table_name"],
            "english_name": mapping_data["english_name"],
            "columns": df.columns.tolist(),
            "data_types": df.dtypes.astype(str).to_dict(),
            "sample_rows": df.to_dict(orient="records")
        }
        print(f"Mapped: {filename} -> {mapping_data['dwh_table_name']}")
        
    except UnicodeDecodeError:
        # Fallback for Latin-1 encoding common in Dutch legacy systems
        try:
            df = pd.read_csv(filepath, sep=';', nrows=10, encoding='latin-1', on_bad_lines='skip')
            df = df.replace({np.nan: None})
            
            bridge_catalog[filename] = {
                "dwh_table_name": mapping_data["dwh_table_name"],
                "english_name": mapping_data["english_name"],
                "columns": df.columns.tolist(),
                "data_types": df.dtypes.astype(str).to_dict(),
                "sample_rows": df.to_dict(orient="records")
            }
            print(f"Mapped (Latin-1): {filename} -> {mapping_data['dwh_table_name']}")
            
        except Exception as e:
            bridge_catalog[filename] = {"error": str(e)}
            
    except Exception as e:
        bridge_catalog[filename] = {"error": str(e)}

# 4. Save the ultimate Master JSON
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(bridge_catalog, f, indent=4)

print(f"\nSuccess! Upload '{output_file}' to our chat.")