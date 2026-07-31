import rhinoscriptsyntax as rs
import Rhino

def mesh_area(mesh_id):

    mesh = rs.coercemesh(mesh_id)

    if not mesh:
        return 0.0

    amp = Rhino.Geometry.AreaMassProperties.Compute(mesh)

    if not amp:
        return 0.0

    return amp.Area


def main():

    meshes = rs.GetObjects(
        "Select meshes",
        rs.filter.mesh,
        preselect=True
    )

    if not meshes:
        return

    processed = 0

    for mesh_id in meshes:

        try:

            before = set(rs.AllObjects())

            rs.UnselectAllObjects()
            rs.SelectObject(mesh_id)

            rs.Command("_Explode", False)

            after = set(rs.AllObjects())

            new_objects = list(after - before)

            pieces = []

            for obj in new_objects:

                if rs.IsMesh(obj):
                    pieces.append(obj)

            if len(pieces) < 2:

                print "Skipping mesh:", mesh_id
                print "Pieces found:", len(pieces)
                continue

            areas = []

            for piece in pieces:

                area = mesh_area(piece)

                areas.append(
                    (area, piece)
                )

            areas.sort(reverse=True)

            # Keep second largest piece
            keep_piece = areas[1][1]

            for area, piece in areas:

                if piece != keep_piece:

                    rs.DeleteObject(piece)

            # Delete original mesh if still exists
            if rs.IsObject(mesh_id):

                rs.DeleteObject(mesh_id)

            processed += 1

        except Exception as e:

            print str(e)

    rs.Redraw()

    print "Processed %d meshes" % processed

if __name__ == "__main__":
    main()