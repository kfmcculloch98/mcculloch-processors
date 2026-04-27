import flopy
import os

def mf6_grid_export():
    """
    Exports a MODFLOW 6 model grid to shapefile.
    """
    print("""
================================================================
|           MODFLOW 6 GRID TO SHAPEFILE EXPORT                 |
|           Version 1.0 - March 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)
    
    # get simulation path
    sim_path = input("Enter the path to the MODFLOW 6 model folder: ").strip().replace('"', '')
    if not os.path.isdir(sim_path):
        print(f"Path does not exist!")
        return

    # get output path
    out_path = input("Enter the path to where the shapefile should be saved: ").strip().replace('"', '')
    if not os.path.exists(out_path):
        os.makedirs(out_path)
        print(f"Created new directory: {out_path}")

    # get coordinate info
    epsg_input = input("Enter EPSG code (e.g., 4326) or press Enter to skip: ").strip()

    try:
        # load model
        print("\nLoading model...")
        sim = flopy.mf6.MFSimulation.load(sim_ws=sim_path, verbosity_level=0)
        gwf = sim.get_model(list(sim.model_names)[0])
        
        ref_path = os.path.join(sim_path, "usgs.model.reference")
        if os.path.exists(ref_path):
            print(f"Applying spatial reference from: {ref_path}")
            d = {}
            with open(ref_path, 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        key = parts[0].lower()
                        val = parts[1]
                        if key == 'xll': d['xoff'] = float(val)
                        if key == 'yll': d['yoff'] = float(val)
                        if key == 'rotation': d['angrot'] = float(val)
                        if key == 'epsg': d['crs'] = int(val)
            gwf.modelgrid.set_coord_info(**d)

        # force EPSG if user entered one manually
        if epsg_input:
            gwf.modelgrid.crs = int(epsg_input)

        # verify grid origin
        print(f"\nGrid origin: xoff={gwf.modelgrid.xoffset}, yoff={gwf.modelgrid.yoffset}, rotation={gwf.modelgrid.angrot}")
        print(f"EPSG/CRS: {gwf.modelgrid.crs}")
        
        proceed = input("Proceed with export? (Y/N): ").strip().upper()
        if proceed != 'Y':
            print("Export cancelled.")
            return

        # define full export path
        output_filename = f"{gwf.name}_grid.shp"
        full_export_path = os.path.join(out_path, output_filename)
        
        print(f"Exporting to: {full_export_path}...")
        
        gdf = gwf.modelgrid.to_geodataframe()

        if epsg_input:
            gdf = gdf.set_crs(f"EPSG:{epsg_input}", allow_override=True)
        elif gwf.modelgrid.crs:
            gdf = gdf.set_crs(gwf.modelgrid.crs, allow_override=True)

        gdf.to_file(full_export_path)
        
        print("\nSuccess! Grid conversion complete.")


    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    mf6_grid_export()