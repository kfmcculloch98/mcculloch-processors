import requests
import pandas as pd
import io
from urllib.parse import urljoin

def download_and_combine():
    print("""
================================================================
|           ENVIRONMENT CANADA DATA DOWNLOAD UTILITY           |
|           Version 1.0 - March 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    prov = input("Enter Province Code (e.g., BC, ON): ").upper().strip()
    station_id = input("Enter CLIMATE_IDENTIFIER (7 digits): ").strip()
    timeframe = input("Choose timeframe (hourly, daily, monthly): ").lower().strip()
    start_year = int(input("Start Year: "))
    end_year = int(input("End Year: "))

    # map timeframe to the suffix used in filenames
    time_suffix = {"hourly": "P1H", "daily": "P1D", "monthly": "P1M"}
    suffix = time_suffix.get(timeframe, "P1D")

    # build url for the folder containing the data
    base_parts = ["https://dd.weather.gc.ca", "today", "climate", "observations", timeframe, "csv", prov]
    base_folder_url = "/".join(base_parts)
    
    all_dfs = []

    for year in range(start_year, end_year + 1):
        filename = f"climate_{timeframe}_{prov}_{station_id}_{year}_{suffix}.csv"
        # combine folder and filename with a single slash
        full_url = f"{base_folder_url}/{filename}"
        
        print(f"\n--- Requesting {year} ---")
        print(f"URL: {full_url}")
        
        try:
            response = requests.get(full_url, timeout=30)
            
            if response.status_code == 200:
                df = pd.read_csv(io.StringIO(response.text))
                
                if not df.empty:
                    # save a local backup of each year
                    local_backup = f"{station_id}_{year}_{timeframe}.csv"
                    df.to_csv(local_backup, index=False)
                    all_dfs.append(df)
                    print(f"  > Successfully saved {local_backup}")
                else:
                    print(f"  > Warning: File for {year} was empty.")
            elif response.status_code == 404:
                print(f"  > Not Found: {year} is not available on this server.")
            else:
                print(f"  > Server Error: {response.status_code}")
                
        except Exception as e:
            print(f"  > Connection Error: {e}")

    if all_dfs:
        combined_df = pd.concat(all_dfs, ignore_index=True)
        
        # sort chronologically if a date column is detected
        date_cols = ['Date/Time', 'LOCAL_DATE', 'Date (LST)', 'Date/Time (LST)']
        for col in date_cols:
            if col in combined_df.columns:
                combined_df[col] = pd.to_datetime(combined_df[col])
                combined_df = combined_df.sort_values(col)
                break

        output_file = f"{station_id}_COMBINED_{start_year}_{end_year}.csv"
        combined_df.to_csv(output_file, index=False)
        print(f"\nSUCCESS: Combined {len(all_dfs)} years into '{output_file}'.")
    else:
        print("\nNo data was collected. Check your Station ID and Year Range.")

    input("\nExecution complete. Press Enter to close...")

if __name__ == "__main__":
    download_and_combine()