import flopy
import rasterio
import os
import sys

def mf6_grid_georef():
    """
    Interrogates a Surfer/GIS .grd file and applies its spatial reference to a MODFLOW 6 model.
    """
    print("""
================================================================
|           MODFLOW 6 GRID GEOREFERENCE UTILITY                |
|           Version 1.0 - April 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    # user inputs
    model_dir = input("Enter the path to the MODFLOW 6 model folder: ").strip().replace('"', '')
    grd_path = input("Enter the path to the .grd file: ").strip().replace('"', '')

    if not os.path.exists(model_dir) or not os.path.exists(grd_path):
        print("\nOne or both paths do not exist!")
        return

    print(f"\nProcessing: {os.path.basename(grd_path)}")
    
    # extract metadata from the .grd file
    try:
        with rasterio.open(grd_path) as src:
            # MF6 uses lower-left for xoff, yoff
            xoff = src.bounds.left
            yoff = src.bounds.bottom
            grd_res = src.res[0]
            print(f"Grid origin: {xoff}, {yoff}")
            print(f"Grid resolution: {grd_res}m")
    except Exception as e:
        print(f"\nRasterio could not read the .grd file: {e}")
        return

    # load the mf6 model and sync its coordinates to the .grd file
    try:
        # load simulation
        sim = flopy.mf6.MFSimulation.load(sim_ws=model_dir, verbosity_level=0)
        gwf = sim.get_model()
        
        # apply the shift
        gwf.modelgrid.set_coord_info(xoff=xoff, yoff=yoff, angrot=0.0)
        gwf.write_grid_specs()
        
        # calculate scale ratio
        ratio = gwf.modelgrid.delr[0] / grd_res

        print(f"\nModel successfuly georeferenced!")
        print(f"  - New origin: {gwf.modelgrid.xoffset}, {gwf.modelgrid.yoffset}")
        print(f"  - Model resolution: {gwf.modelgrid.delr[0]}m")
        print(f"  - Scale ratio: 1:{ratio:.1f} (Model cells are {ratio:.1f}x larger than .grd)")
        
        # save updated metadata to simulation files
        sim.write_simulation()
        print("\nSimulation metadata updated and saved to disk.")

        # write the spatial reference metadata to a file FloPy can find later
        ref_path = os.path.join(model_dir, "usgs.model.reference")
        with open(ref_path, "w") as f:
            f.write(f"xll {gwf.modelgrid.xoffset}\n")
            f.write(f"yll {gwf.modelgrid.yoffset}\n")
            f.write(f"rotation {gwf.modelgrid.angrot}\n")
            if gwf.modelgrid.crs:
                f.write(f"epsg {gwf.modelgrid.crs.to_epsg()}\n")
        
        print(f"Spatial reference saved to: {ref_path}")

    except Exception as e:
        print(f"\nFailed to update MODFLOW model: {e}")

if __name__ == "__main__":
    mf6_grid_georef()