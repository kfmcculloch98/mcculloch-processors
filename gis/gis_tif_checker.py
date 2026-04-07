import pandas as pd
import rasterio
from pathlib import Path

def run_scanner():

    print("""
================================================================
|           TIF CHECKER                                        |
|           Version 1.0 - March 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    # user input for paths
    raw_tif_dir = input(r"Enter the TIF (e.g., DEM, satellite imagery) folder path (e.g. h:\RemoteSensing\2025): ").strip('"').strip("'")
    raw_csv_path = input(r"Enter the CSV containing point data (e.g., well collars, VWP sensors) file path: ").strip('"').strip("'")

    tif_folder = Path(raw_tif_dir)
    csv_path = Path(raw_csv_path)

    # validate paths
    if not tif_folder.is_dir():
        print(f"Error: TIF folder not found at {tif_folder}")
        return
    if not csv_path.is_file():
        print(f"Error: CSV file not found at {csv_path}")
        return

    # load point data
    try:
        df = pd.read_csv(csv_path)
        # auto-detect coordinate columns
        x_col = next((c for c in df.columns if c.lower() in ['x', 'easting', 'longitude', 'long']), None)
        y_col = next((c for c in df.columns if c.lower() in ['y', 'northing', 'latitude', 'lat']), None)

        if not x_col or not y_col:
            print(f"Error: Could not find X/Y columns in CSV. Columns found: {list(df.columns)}")
            return
    except Exception as e:
        print(f"Failed to read CSV: {e}")
        return

    # scan tif files and check for point containment
    tif_files = [f for f in tif_folder.iterdir() if f.suffix.lower() in ['.tif', '.tiff']]
    
    if not tif_files:
        print("No .tif files found in that directory.")
        return

    print(f"\nChecking {len(tif_files)} files against {len(df)} points...\n")

    for tif in tif_files:
        try:
            with rasterio.open(tif) as src:
                b = src.bounds # (left, bottom, right, top)
                
                # check which points fall inside
                mask = (
                    (df[x_col] >= b.left) & (df[x_col] <= b.right) &
                    (df[y_col] >= b.bottom) & (df[y_col] <= b.top)
                )
                
                hits = df[mask]
                if not hits.empty:
                    print(f"MATCH: [{tif.name}] contains {len(hits)} points.")
                    # print the first 5 matching point names/IDs if they exist
                    label_col = df.columns[0] # assume first column is a label/ID
                    print(f"      IDs: {hits[label_col].head().tolist()}")
                else:
                    print(f"empty: [{tif.name}]")

        except Exception as e:
            print(f"Error reading {tif.name}: {e}")

if __name__ == "__main__":
    run_scanner()