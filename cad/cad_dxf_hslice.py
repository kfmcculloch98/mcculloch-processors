import ezdxf
import os  # Required for os.path.isfile
from ezdxf.math import Vec3
from collections import defaultdict

def dxf_hslice():

    print("""
================================================================
|           DXF HORIZONTAL SLICE UTILITY                       |
|           Version 1.0 - April 2026                           |
|           Contact Kaden McCulloch for support                |
| https://github.com/kfmcculloch98/mcculloch-processors/issues |          
================================================================
    """)

    # prompt user for input file path
    file_path = input("Enter the full path to your DXF file: ").strip().strip('"')

    if not os.path.isfile(file_path):
        print(f"Error: The file '{file_path}' does not exist.")
        return
    
    # load the dxf file
    try:
        doc = ezdxf.readfile(file_path)
        msp = doc.modelspace()
    except Exception as e:
        print(f"Error reading DXF: {e}")
        return
    
    # prompt user for output file path 
    output_dir = input("Enter output folder path (press Enter for current folder): ").strip().strip('"')
    if output_dir and not os.path.exists(output_dir):
        print(f"Error: Directory '{output_dir}' not found.")
        return

    try:
        z_slice = float(input("Enter elevation (Z) for the slice: "))
    except ValueError:
        print("Invalid elevation input.")
        return

    segments = []
    print("Calculating intersections...")
    
    # collect all valid intersection segments
    for face in msp.query("3DFACE"):
        v = [face.dxf.vtx0, face.dxf.vtx1, face.dxf.vtx2, face.dxf.vtx3]
        pts = []
        # Check edges: 0-1, 1-2, 2-3, 3-0
        edges = [(v[0], v[1]), (v[1], v[2]), (v[2], v[3]), (v[3], v[0])]
        
        for p1, p2 in edges:
            if (p1.z <= z_slice <= p2.z) or (p2.z <= z_slice <= p1.z):
                if p1.z != p2.z:
                    t = (z_slice - p1.z) / (p2.z - p1.z)
                    itp = Vec3(p1.x + t*(p2.x-p1.x), p1.y + t*(p2.y-p1.y), z_slice)
                    if not any(itp.isclose(existing) for existing in pts):
                        pts.append(itp)
        
        if len(pts) == 2:
            segments.append((pts[0], pts[1]))

    # join segments into polylines
    print(f"Joining {len(segments)} segments into chains...")
    chains = []
    lookup = defaultdict(list)
    for s1, s2 in segments:
        lookup[s1.round(4)].append([s1, s2])
        lookup[s2.round(4)].append([s2, s1])

    used_segments = set()
    for i, (start_pt, end_pt) in enumerate(segments):
        seg_id = tuple(sorted((start_pt.round(4), end_pt.round(4))))
        if seg_id in used_segments: continue
        
        current_chain = [start_pt, end_pt]
        used_segments.add(seg_id)
        
        for direction in [1, -1]:
            while True:
                tip = current_chain[-1].round(4) if direction == 1 else current_chain[0].round(4)
                found_next = False
                for candidate in lookup[tip]:
                    c_id = tuple(sorted((candidate[0].round(4), candidate[1].round(4))))
                    if c_id not in used_segments:
                        if direction == 1:
                            current_chain.append(candidate[1])
                        else:
                            current_chain.insert(0, candidate[1])
                        used_segments.add(c_id)
                        found_next = True
                        break
                if not found_next: break
        chains.append(current_chain)

    # save output
    out_doc = ezdxf.new()
    out_msp = out_doc.modelspace()
    for chain in chains:
        points_2d = [(p.x, p.y) for p in chain]
        out_msp.add_lwpolyline(points_2d, dxfattribs={'elevation': z_slice})

    filename = f"slice_joined_{z_slice}.dxf"
    output_path = os.path.join(output_dir, filename) if output_dir else filename
    
    out_doc.saveas(output_path)
    print(f"Saved {len(chains)} polylines to {output_path}")

if __name__ == "__main__":
    dxf_hslice()
