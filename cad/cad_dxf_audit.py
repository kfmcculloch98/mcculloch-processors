# import packages 
import os
import ezdxf
from ezdxf import bbox
from ezdxf.render import MeshBuilder

# define function to audit dxf
def dxf_audit():

    print("""
================================================================
|           DXF AUDIT UTILITY                                  |
|           Version 1.0 - April 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)
        
    file_path = input("Enter the full path to your DXF file: ").strip().strip('"')
    
    if not os.path.isfile(file_path):
        print(f"Error: The file '{file_path}' does not exist.")
        return

    try:
        doc = ezdxf.readfile(file_path)
        msp = doc.modelspace()
        
        # scan the dxf for common errors
        auditor = doc.audit()
        print(f"Audit Status: {'Errors detected' if auditor.has_errors else 'No errors'}")

        # scan the dxf to identify its structure
        print("\nIdentifying DXF structure (3DFACE, MESH, POLYFACE MESH, POLYGON MESH)...")
        total_faces = 0
        counts = {"3DFACE": 0, "MESH": 0, "POLYFACE MESH": 0, "POLYGON MESH": 0}
        
        for e in msp:
            dtype = e.dxftype()
            
            if dtype == '3DFACE':
                counts["3DFACE"] += 1
                total_faces += 1 # each 3D face is one face
            
            elif dtype == 'MESH':
                counts["MESH"] += 1
                # access face data directly from the MESH entity
                total_faces += len(e.faces)
            
            elif dtype == 'POLYLINE':
                if e.is_poly_face_mesh:
                    counts["POLYFACE MESH"] += 1
                    # use MeshBuilder to safely extract faces from complex Polyface structures
                    builder = MeshBuilder.from_polyface(e)
                    total_faces += len(builder.faces)
                
                elif e.is_polygon_mesh:
                    counts["POLYGON MESH"] += 1
                    # polygon meshes are M x N grids where faces = (M-1) * (N-1)
                    m = e.dxf.m_count
                    n = e.dxf.n_count
                    total_faces += (max(0, m-1) * max(0, n-1))

        for label, count in counts.items():
            if count > 0:
                print(f"{label} entities: {count}")
        
        print(f"Total calculated faces: {total_faces}")

        # evaluate bounding box
        extents = bbox.extents(msp)
        if not extents.is_empty:
            min_pt, max_pt = extents.extmin, extents.extmax
            print(f"\nIdentifying bounding box of DXF...")
            print(f"Size: {max_pt.x-min_pt.x:.2f} x {max_pt.y-min_pt.y:.2f} x {max_pt.z-min_pt.z:.2f}")

    except Exception as e:
        print(f"Error analyzing file: {e}")

if __name__ == "__main__":
    dxf_audit()