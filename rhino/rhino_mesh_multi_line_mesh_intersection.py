import rhinoscriptsyntax as rs
import Rhino.Geometry as rg
import Rhino
import System
import clr  
import os

def get_mesh_multiple_lines_intersection():
    # Show the informational startup message box
    info_msg = (
        "Drillhole / Mesh Intersection Tool.\n"
        "Contact Kaden McCulloch for support.\n\n"
        "Note: Each drillhole must be on its own layer!"
    )
    rs.MessageBox(info_msg, buttons=0, title="Tool Info")

    # Pre-select support enabled to bypass selection lock
    line_ids = rs.GetObjects("Select the intersection lines and press ENTER", filter=4, preselect=True)
    if not line_ids: 
        print("Selection cancelled or no curves selected.")
        return
    
    # Select the target mesh
    mesh_id = rs.GetObject("Select the target mesh", filter=32)
    if not mesh_id: return
    
    # Get the full path string using native RhinoCommon for the mesh
    mesh_obj = rs.coercerhinoobject(mesh_id)
    mesh_layer_index = mesh_obj.Attributes.LayerIndex
    mesh_layer_raw = Rhino.RhinoDoc.ActiveDoc.Layers[mesh_layer_index].FullPath
    mesh_layer_full = mesh_layer_raw.replace("::", ", ")
    
    mesh_geom = rs.coercemesh(mesh_id)
    
    csv_rows = []
    # FIX: Rearranged layout header to standard X, Y, Z coordinates-first protocol
    csv_rows.append("X Coordinate,Y Coordinate,Elevation (Z),Line Index,Line Layer,Mesh Layer")
    
    print("\n--- Intersection Results ---")
    total_intersections = 0
    
    # Loop through each selected line
    for idx, line_id in enumerate(line_ids):
        line_obj_rh = rs.coercerhinoobject(line_id)
        line_layer_index = line_obj_rh.Attributes.LayerIndex
        line_layer_raw = Rhino.RhinoDoc.ActiveDoc.Layers[line_layer_index].FullPath
        line_layer_full = line_layer_raw.replace("::", ", ")
        
        line_geom = rs.coercecurve(line_id)
        if not line_geom: continue
        
        start_pt = line_geom.PointAtStart
        end_pt = line_geom.PointAtEnd
        line_obj = rg.Line(start_pt, end_pt)
            
        face_indices_box = clr.StrongBox[System.Array[System.Int32]]()
        int_pts = rg.Intersect.Intersection.MeshLine(mesh_geom, line_obj, face_indices_box)
        
        if int_pts:
            print("\nLine {} [Layer Path: {}]:".format(idx + 1, line_layer_full))
            for pt in int_pts:
                total_intersections += 1
                # Format to 4 decimal places
                z_str = "{:.4f}".format(pt.Z)
                x_str = "{:.4f}".format(pt.X)
                y_str = "{:.4f}".format(pt.Y)
                
                # Print to Rhino Console
                print("  - Mesh Layer Path: {}".format(mesh_layer_full))
                print("  - Elevation (Z):   {}".format(z_str))
                print("  - Full Coordinate: {}, {}, {}".format(x_str, y_str, z_str))
                
                # FIX: Injected variables mapping directly to X,Y,Z index positions first
                csv_rows.append("{},{},{},{},\"{}\",\"{}\"".format(
                    x_str, y_str, z_str, idx + 1, line_layer_full, mesh_layer_full
                ))
                
    if total_intersections == 0:
        print("\nNo intersections found between any of the selected lines and the mesh.")
        return

    # Prompt user for the filename and destination path
    csv_filename = rs.SaveFileName(
        title="Save Intersection Data As",
        filter="CSV Files (*.csv)|*.csv||",
        filename="drillhole_intersections.csv"
    )
    
    if not csv_filename:
        print("\nCSV export cancelled by user. Data printed above.")
        return

    # Write data out to the user's specified path
    try:
        with open(csv_filename, 'w') as csv_file:
            for row in csv_rows:
                csv_file.write(row + '\n')
                
        print("\n>>> Success! Results successfully saved to: {}".format(csv_filename))
        rs.MessageBox("CSV successfully exported!", 0, "Export Complete")
    except Exception as e:
        print("\nError writing CSV file: {}".format(str(e)))

if __name__ == "__main__":
    get_mesh_multiple_lines_intersection()