import sys
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.interpolate import griddata
from openpyxl import load_workbook


def main():
    if len(sys.argv) < 2:
        print("Usage: python grid_contour_from_excel.py workbook_path", file=sys.stderr)
        sys.exit(1)

    workbook_path = Path(sys.argv[1])

    if not workbook_path.exists():
        print(f"Workbook not found: {workbook_path}", file=sys.stderr)
        sys.exit(2)

    # Read workbook metadata from Excel
    wb = load_workbook(workbook_path, data_only=True)
    ws = wb["INPUT"]

    rootname = ws["A2"].value
    if rootname is None or str(rootname).strip() == "":
        rootname = workbook_path.stem
    else:
        rootname = str(rootname).strip()

    outdir = ws["A3"].value
    if outdir is None or str(outdir).strip() == "":
        outdir = workbook_path.parent
    else:
        outdir = Path(str(outdir).strip())

    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # Read the whole sheet data into pandas
    # Start at row 8, columns A:J
    df = pd.read_excel(
        workbook_path,
        sheet_name="INPUT",
        header=None,
        usecols="A:J",
        skiprows=7,
        engine="openpyxl"
    )

    # Assign column names by Excel position
    df.columns = [f"col{i}" for i in range(1, 11)]

    # Filter rows until first blank in col1, and include_flag == 1
    df = df[df["col1"].notna()]
    df = df[df["col10"] == 1]

    if df.empty:
        print("No rows selected for processing.", file=sys.stderr)
        sys.exit(3)

    # Pull x, y, z
    x = pd.to_numeric(df["col3"], errors="coerce").to_numpy()
    y = pd.to_numeric(df["col4"], errors="coerce").to_numpy()
    z = pd.to_numeric(df["col6"], errors="coerce").to_numpy()

    mask = np.isfinite(x) & np.isfinite(y) & np.isfinite(z)
    x = x[mask]
    y = y[mask]
    z = z[mask]

    if len(x) < 3:
        print("Not enough valid points to grid.", file=sys.stderr)
        sys.exit(4)

    # Create grid
    grid_res = 200
    xi = np.linspace(x.min(), x.max(), grid_res)
    yi = np.linspace(y.min(), y.max(), grid_res)
    Xi, Yi = np.meshgrid(xi, yi)

    # Interpolate
    Zi = griddata((x, y), z, (Xi, Yi), method="linear")
    Zi_nn = griddata((x, y), z, (Xi, Yi), method="nearest")
    Zi = np.where(np.isnan(Zi), Zi_nn, Zi)

    # Save grid
    grid_out = outdir / f"{rootname}_grid.csv"
    grid_df = pd.DataFrame({
        "x": Xi.ravel(),
        "y": Yi.ravel(),
        "z": Zi.ravel()
    })
    grid_df.to_csv(grid_out, index=False)

    # Contour plot
    zmin = np.nanmin(Zi)
    zmax = np.nanmax(Zi)
    levels = np.linspace(zmin, zmax, 15)

    fig, ax = plt.subplots(figsize=(10, 8))
    cf = ax.contourf(Xi, Yi, Zi, levels=levels, cmap="viridis")
    cs = ax.contour(Xi, Yi, Zi, levels=levels, colors="k", linewidths=0.5)
    ax.clabel(cs, inline=True, fontsize=8, fmt="%.2f")

    ax.scatter(x, y, c="red", s=10, label="Points")
    ax.set_title(rootname)
    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_aspect("equal", adjustable="box")
    fig.colorbar(cf, ax=ax, label="Z")
    ax.legend(loc="best")

    png_out = outdir / f"{rootname}_contours.png"
    plt.tight_layout()
    plt.savefig(png_out, dpi=300)
    plt.close(fig)

    print(f"Saved grid: {grid_out}")
    print(f"Saved contour plot: {png_out}")


if __name__ == "__main__":
    main()