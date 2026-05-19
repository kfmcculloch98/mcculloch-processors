import os
import numpy as np
import geopandas as gpd
from shapely.affinity import rotate, translate

def calculate_rotation_and_shift(src_pts, tgt_pts):
    """
    Compute best-fit 2D rotation + translation using XY only.
    """
    src_xy = np.asarray(src_pts[:, :2], dtype=float)
    tgt_xy = np.asarray(tgt_pts[:, :2], dtype=float)

    src_centroid = src_xy.mean(axis=0)
    tgt_centroid = tgt_xy.mean(axis=0)

    X = src_xy - src_centroid
    Y = tgt_xy - tgt_centroid

    # 2D Kabsch/Procrustes rotation
    H = X.T @ Y
    U, S, Vt = np.linalg.svd(H)
    R = Vt.T @ U.T

    # prevent reflection
    if np.linalg.det(R) < 0:
        Vt[-1, :] *= -1
        R = Vt.T @ U.T

    # rotation angle in degrees
    angle_rad = np.arctan2(R[1, 0], R[0, 0])
    angle_deg = np.degrees(angle_rad)

    return angle_deg, src_centroid, tgt_centroid

def compute_z_offset(src_pts, tgt_pts):
    """
    Use the average Z difference as a simple vertical offset.
    """
    src_z = np.asarray(src_pts[:, 2], dtype=float)
    tgt_z = np.asarray(tgt_pts[:, 2], dtype=float)
    return float(np.mean(tgt_z - src_z))

def main():

    input_path = input("Enter the path to the input shapefile (.shp): ").strip()

    if (input_path.startswith('"') and input_path.endswith('"')) or \
       (input_path.startswith("'") and input_path.endswith("'")):
        input_path = input_path[1:-1]

    base_file, ext = os.path.splitext(input_path)
    if ext.lower() in ['.cpg', '.dbf', '.shx', '.prj', '.sbx', '.sbn']:
        input_path = f"{base_file}.shp"

    if not os.path.exists(input_path):
        print(f"Error: File '{input_path}' does not exist.")
        return

    base, ext = os.path.splitext(input_path)
    output_path = f"{base}_utm10n{ext}"

    # control points
    # source = mine grid (x', y', z')
    # target = UTM (x, y, z)
    src_pts = np.array([
        [4032.401, 2986.913, 5670.866],
        [4739.67,  1922.529, 5676.906],
        [4203.408,   723.565, 5749.221]
    ], dtype=float)

    tgt_pts = np.array([
        [674977.5,    5615763.0,   671.0097],
        [676247.3293, 5615620.591, 677.0603],
        [676821.1321, 5614439.308, 749.3871]
    ], dtype=float)

    # calculate best-fit XY rigid transform
    angle_deg, src_centroid, tgt_centroid = calculate_rotation_and_shift(src_pts, tgt_pts)
    z_off = compute_z_offset(src_pts, tgt_pts)

    # use the first control point as an anchor
    src_x, src_y = src_pts[0, 0], src_pts[0, 1]
    tgt_x, tgt_y = tgt_pts[0, 0], tgt_pts[0, 1]

    print("\nCalculated transform:")
    print(f"  XY rotation angle: {angle_deg:.2f} degrees")
    print(f"  Z offset: {z_off:.2f} m")
    print(f"  Anchor source point: ({src_x:.2f}, {src_y:.2f})")
    print(f"  Anchor target point: ({tgt_x:.2f}, {tgt_y:.2f})")

    # load shapefile
    print(f"\nLoading shapefile: {input_path}")
    gdf = gpd.read_file(input_path)

    # apply 2D rigid transform in XY
    # rotate about the source anchor, then shift the anchor to target
    print("Applying transformation...")

    def transform_geom(geom):
        if geom is None:
            return None

        g = rotate(geom, angle_deg, origin=(src_x, src_y))
        g = translate(g, xoff=(tgt_x - src_x), yoff=(tgt_y - src_y))
        return g

    gdf["geometry"] = gdf["geometry"].apply(transform_geom)

    # set CRS metadata for NAD 83 UTM Zone 10N
    gdf = gdf.set_crs("EPSG:26910", allow_override=True)

    # save output
    print(f"Saving transformed shapefile: {output_path}")
    gdf.to_file(output_path)

    print("\nTransformation successfully completed!")

    # check residuals for each control point
    print("\nControl point residual check:")
    th = np.radians(angle_deg)
    R = np.array([
        [np.cos(th), -np.sin(th)],
        [np.sin(th),  np.cos(th)]
    ])

    pred_xy = (src_pts[:, :2] - np.array([src_x, src_y])) @ R.T + np.array([tgt_x, tgt_y])
    pred_z = src_pts[:, 2] + z_off

    for i in range(len(src_pts)):
        dx = pred_xy[i, 0] - tgt_pts[i, 0]
        dy = pred_xy[i, 1] - tgt_pts[i, 1]
        dz = pred_z[i] - tgt_pts[i, 2]
        err = np.sqrt(dx*dx + dy*dy + dz*dz)
        print(
            f"  Point {i+1}: "
            f"dx={dx:+.4f}, dy={dy:+.4f}, dz={dz:+.4f}, "
            f"3D error={err:.4f} m"
        )

if __name__ == "__main__":
    main()