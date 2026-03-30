import flopy
import os

def export_grid_interactive():

    print("""
================================================================
|           MODFLOW 6 GRID TO SHAPEFILE CONVERTER              |
|           Version 1.0 - March 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    
    # 1. get simulation path
    sim_path = input("1. Paste the path to your MF6 simulation folder: ").strip().replace('"', '')
    if not os.path.isdir(sim_path):
        print(f"Error: '{sim_path}' is not a valid directory.")
        return

    # 2. get output path
    out_path = input("2. Enter the folder path where you want to save the shapefile: ").strip().replace('"', '')
    if not os.path.exists(out_path):
        os.makedirs(out_path)
        print(f"Created new directory: {out_path}")

    # 3. get coordinate info
    epsg_input = input("3. Enter EPSG code (e.g., 4326) or press Enter to skip: ").strip()
    xoff = input("   Enter X offset (default 0.0): ").strip() or 0.0
    yoff = input("   Enter Y offset (default 0.0): ").strip() or 0.0
    rotation = input("   Enter rotation (default 0.0): ").strip() or 0.0

    try:
        # 4. load model
        print("\nLoading model...")
        sim = flopy.mf6.MFSimulation.load(sim_ws=sim_path, verbosity_level=0)
        gwf = sim.get_model(list(sim.model_names)[0])
        
        # 5. set georeferencing
        gwf.modelgrid.set_coord_info(
            xoff=float(xoff), 
            yoff=float(yoff), 
            angrot=float(rotation), 
            crs=int(epsg_input) if epsg_input else None
        )

        # 6. define full export path
        output_filename = f"{gwf.name}_grid.shp"
        full_export_path = os.path.join(out_path, output_filename)
        
        print(f"Exporting to: {full_export_path}...")
        gwf.export(full_export_path)
        
        print("\nSuccess! Grid conversion complete.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    export_grid_interactive()