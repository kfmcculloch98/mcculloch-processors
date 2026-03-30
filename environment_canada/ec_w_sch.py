import requests
import pandas as pd

def search_stations():
    # base URL for the collection
    url = "https://api.weather.gc.ca/collections/climate-stations/items"
    
    print("""
================================================================
|           ENVIRONMENT CANADA STATION SEARCH UTILITY          |
|           Version 1.0 - March 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    prov_input = input("Enter Province Code (e.g., BC, ON): ").upper().strip()
    name_query = input("Station name contains: ").upper().strip()

    all_stations = []
    # small limit per page to avoid server timeouts
    params = {
        "lang": "en",
        "PROV_STATE_TERR_CODE": prov_input,
        "limit": 100,
        "f": "json"
    }

    print(f"Fetching stations for {prov_input}...")
    current_url = url

    try:
        while current_url:
            response = requests.get(current_url, params=params if current_url == url else None, timeout=30)
            
            if response.status_code != 200:
                print(f"Server Error {response.status_code}. Stopping fetch.")
                break

            data = response.json()
            features = data.get('features', [])
            if not features:
                break

            all_stations.extend([f['properties'] for f in features])
            print(f"  > Total loaded: {len(all_stations)}", end="\r")

            # look for the 'next' link in the API response
            links = data.get('links', [])
            next_link = next((link['href'] for link in links if link.get('rel') == 'next'), None)
            current_url = next_link

    except Exception as e:
        print(f"\nError: {e}")

    if not all_stations:
        print(f"\nNo records found for province '{prov_input}'.")
        return

    # convert to DataFrame and filter locally
    df = pd.DataFrame(all_stations)
    matches = df[df['STATION_NAME'].str.contains(name_query, case=False, na=False)].copy()

    if matches.empty:
        print(f"\nNo stations in {prov_input} contain the name '{name_query}'.")
        return

    # format year ranges from DLY_FIRST_DATE, etc.
    def format_yr(date_str):
        return str(date_str)[:4] if date_str and str(date_str).strip() not in ['0', '', 'None'] else "None"

    matches['HOURLY'] = matches.apply(lambda r: f"{format_yr(r.get('HLY_FIRST_DATE'))}-{format_yr(r.get('HLY_LAST_DATE')) or 'Pres'}" if format_yr(r.get('HLY_FIRST_DATE')) != "None" else "None", axis=1)
    matches['DAILY'] = matches.apply(lambda r: f"{format_yr(r.get('DLY_FIRST_DATE'))}-{format_yr(r.get('DLY_LAST_DATE')) or 'Pres'}" if format_yr(r.get('DLY_FIRST_DATE')) != "None" else "None", axis=1)
    matches['MONTHLY'] = matches.apply(lambda r: f"{format_yr(r.get('MLY_FIRST_DATE'))}-{format_yr(r.get('MLY_LAST_DATE')) or 'Pres'}" if format_yr(r.get('MLY_FIRST_DATE')) != "None" else "None", axis=1)

    # add location columns
    matches['LAT'] = matches['LATITUDE'].astype(float).map('{:.2f}'.format)
    matches['LON'] = matches['LONGITUDE'].astype(float).map('{:.2f}'.format)
    matches['ELEV (m)'] = matches['ELEVATION'].astype(float).map('{:.2f}'.format)

    # reordering columns to include location data
    cols = ['STATION_NAME', 'CLIMATE_IDENTIFIER', 'LAT', 'LON', 'ELEV (m)', 'HOURLY', 'DAILY', 'MONTHLY']
    
    print(f"\n\nResults for {prov_input} (Matches: {len(matches)}):")
    # Display the updated table
    print(matches[cols].sort_values('DAILY', ascending=False).to_string(index=False))

if __name__ == "__main__":
    search_stations()
    # keep the window open
    input("\nExecution complete. Press Enter to close...")