Attribute VB_Name = "SurfaceOperations"
Sub III_Surface_face3d_from_BLN()
'Convert BLN file from surfer to 3D Face file
    'When I_MakeSrfGRD() is executed using the Triangulation with Lin. interpolation option
    'the macro generates a triangulated face .bln file with all nodes used for interpolation.
    'This subroutine converts the .bln file to a 3D .dxf face file
    
'BLN file must be exported from Tri-Linear interpolation file using Surfer
Set wksSurface = Sheets("SURFACE")
Set wksScript = Sheets("Script")
Set wksData = Sheets("Input")

wksScript.Activate
wksSurface.Activate

'initialize variables needed for the parse_string_by_comma_v2 subroutine
Dim fullstring As String
Dim arrLong() As Long
Dim arrDbl() As Double
Dim arrStr() As String
Dim strType As String

delim = ","
strType = "string"

'Populate Array with Node Data
Application.StatusBar = "Creating Array of Data Points..."

numpoints = WorksheetFunction.Sum(wksData.Columns("J:J"))
ReDim data_arr(numpoints, 4)
jrow = 8
i = 1
While wksData.Cells(jrow, 1) <> ""
    If wksData.Cells(jrow, 10) = 1 Then
        data_arr(i, 1) = wksData.Cells(jrow, 1) 'Pt ID
        data_arr(i, 2) = Round(wksData.Cells(jrow, 3), 4) 'X
        data_arr(i, 3) = Round(wksData.Cells(jrow, 4), 4) 'Y
        data_arr(i, 4) = Round(wksData.Cells(jrow, 6), 4) 'Z
        
        i = i + 1
    End If
    
    jrow = jrow + 1
Wend

'Write nodes in BLN file to array
blnFile = Application.GetOpenFilename("BLN Triangle File *.bln, *.bln", , "Select " & ".bln File", , True)

For ifile = 1 To UBound(blnFile)
    Const ForReading = 1, ForWriting = 2, ForAppending = 3
    Dim fs
    
    Application.StatusBar = "Reading/writing BLN file points..."
    
    wksSurface.Columns.Range("G:M").Clear
    wksSurface.Cells(1, 7) = "BLN Triangle File X,Y,Z"
    wksSurface.Cells(2, 7) = "Point_ID"
    wksSurface.Cells(2, 8) = "X"
    wksSurface.Cells(2, 9) = "Y"
    wksSurface.Cells(2, 10) = "Z"
    irow = 3
    filenumber = FreeFile
    
    'Establish the filepath, filename
    slash = ""
    filepath = blnFile(ifile) 'filepath
    temp = Len(filepath)
    i = 0
    
    While slash <> "\"
        slash = Mid(filepath, temp - i, 1)
        i = i + 1
    Wend
    file_name = Replace(Mid(filepath, temp - i + 2, temp - i + 1), ".bln", "")
    file_folder = Mid(filepath, 1, temp - i + 1)
    
    icount = 0
    
    Open blnFile(ifile) For Input As #filenumber
    FileLength = LOF(filenumber)
    
    Do While Not EOF(filenumber)
        Line Input #filenumber, fullstring
        If fullstring = "4,0" Then
            icount = icount + 1
            
            'Next three lines are the triangle vertices in 2D
            For i = 1 To 3
                Line Input #filenumber, fullstring
                Call parse_string_by_comma(fullstring, arrLong, arrDbl, arrStr, strType)
                
                wksSurface.Cells(irow, 8) = Val(Round(arrStr(0), 4))    'BLN X value
                wksSurface.Cells(irow, 9) = Val(Round(arrStr(1), 4))    'BLN Y value
                irow = irow + 1
            Next i
        End If
    Loop
    
    Close #filenumber
    
    irow = 3
    
    'Populate elevation data
    error_flag = False
    
    Do Until wksSurface.Cells(irow, 8) = ""
        x1 = wksSurface.Cells(irow, 8)
        y1 = wksSurface.Cells(irow, 9)
        ID_flag = False
        
        For i = 1 To numpoints
            If data_arr(i, 2) = x1 And data_arr(i, 3) = y1 Then
                wksSurface.Cells(irow, 7) = data_arr(i, 1)
                wksSurface.Cells(irow, 10) = data_arr(i, 4)
                ID_flag = True
                Exit For
            End If
        Next i
        
        If ID_flag = False Then
            error_flag = True
            wksSurface.Cells(irow, 7) = "-"
            wksSurface.Cells(irow, 10) = "-"
        End If
        
        irow = irow + 1
    Loop
    
    If error_flag = True Then
        myflag = MsgBox("Point(s) in BLN file not found in Input Data point file", vbOKOnly, "Missing Point Data")
        Exit Sub
    End If
    
    'Write script file
    Application.StatusBar = "Creating 3D Face .SCR file"
    
    wksScript.Activate
    Columns("A:A").Select
    Selection.ClearContents
    wksSurface.Activate
    
    irow = 3
    f = 1
    
    wksScript.Cells(f, 1) = "layer"
    f = f + 1
    wksScript.Cells(f, 1) = "new"
    f = f + 1
    wksScript.Cells(f, 1) = uselayer
    f = f + 1
    wksScript.Cells(f, 1) = "Color"
    f = f + 1
    wksScript.Cells(f, 1) = "white"
    f = f + 1
    wksScript.Cells(f, 1) = uselayer
    f = f + 1
    wksScript.Cells(f, 1) = "make"
    f = f + 1
    wksScript.Cells(f, 1) = file_name
    f = f + 2
    
    While wksSurface.Cells(irow, 7) <> ""
        wksScript.Cells(f, 1) = "face"
        f = f + 1
        For i = 0 To 2
            wksScript.Cells(f + i, 1) = "'" & wksSurface.Cells(irow + i, 8) & delim & wksSurface.Cells(irow + i, 9) & delim & wksSurface.Cells(irow + i, 10)
        Next i
        
        f = f + 5
        irow = irow + 3
    Wend
        
    fileSaveName = file_folder & file_name & ".scr"
    wksScript.Copy
    
    If Not fileSaveName = False Then
     ActiveWorkbook.SaveAs Filename:=fileSaveName, _
            FileFormat:=xlTextPrinter, CreateBackup:=False
    End If
    
    ActiveWorkbook.Close savechanges:=False 'close the script file
Next ifile


End Sub

Sub IIIa_pts_from_surface_contours()
'Macro extracts and compiles all vertices from a polyline .DXF drawing file
'User is prompted if they would like to append vertex data to the Input Data worksheet
    'Option to add a vertical offset value to all points.

'Declarations
Dim fs, f
Dim distFlag As Boolean     'Use for excluding points
Dim distFilter As Long      'Distance criteria for excluding points
Dim zOffset As Long         'Increase/decrease point elevations by this amount

Set fs = CreateObject("Scripting.FileSystemObject")
Set wksSurface = Sheets("SURFACE")
Set wksData = Sheets("Input")

Const ForReading = 1, ForWriting = 2, ForAppending = 3

'ZOffset value
zOffset = wksSurface.Cells(7, 1)

'Distance filter
distFilter = wksSurface.Cells(8, 1)

If distFilter = 0 Then
    distFlag = False
Else
    distFlag = True
End If

varCheck = MsgBox("Distance filter: " & distFilter & vbLf & vbLf & _
            "Vertical offset applied to points: " & zOffset, _
            vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM Parameters")
If varCheck = vbNo Then Exit Sub

'Open .DXF file
file_poly = Application.GetOpenFilename("DXF Files (*.dxf), *.dxf", , "Select Polyline DXF Files", , True)

For ifile = 1 To UBound(file_poly)
    filenumber = FreeFile
    
    Application.StatusBar = "Extracting Vertex data from .dxf contour file..."
    wksSurface.Columns.Range("G:M").Clear
    wksSurface.Cells(1, 7) = "Vertices from Surface contour"
    wksSurface.Cells(2, 7) = "X"
    wksSurface.Cells(2, 8) = "Y"
    wksSurface.Cells(2, 9) = "Z"
    wksSurface.Cells(2, 10) = "Z Offset"
    wksSurface.Cells(2, 11) = "Plot_Flag"
    irow = 3
    
    'Establish the filepath, filename
    slash = ""
    filepath = file_poly(ifile) 'filepath
    temp = Len(filepath)
    i = 0
    
    While slash <> "\"
        slash = Mid(filepath, temp - i, 1)
        i = i + 1
    Wend
    file_name = Replace(Mid(filepath, temp - i + 2, temp - i + 1), ".dxf", "")
    file_folder = Mid(filepath, 1, temp - i + 1)

    Open file_poly(ifile) For Input As #filenumber
    FileLength = LOF(filenumber)
        
    Do While Not EOF(filenumber)
        Line Input #filenumber, fullstring
        If fullstring = "POLYLINE" Then
            'First row with vertex data
            srow = irow
            'Extract vertex data
            x1 = ""
            y1 = ""
            z1 = ""
            
            'Extract Layer Name and copy to Targets worksheet
            Line Input #filenumber, fullstring '5
            Line Input #filenumber, fullstring
            Line Input #filenumber, fullstring '8
            Line Input #filenumber, fullstring 'Layer name
            
            'Extract polyline vertices for layer
            While fullstring <> "VERTEX"
                Line Input #filenumber, fullstring
                If fullstring = "EOF" Then GoTo endoffile
            Wend
            
            While fullstring <> "SEQEND"
                While fullstring <> " 10"
                    Line Input #filenumber, fullstring
                    If fullstring = "SEQEND" Then GoTo NextLayer
                Wend
                
                Line Input #filenumber, fullstring
                x1 = Val(fullstring)
                Line Input #filenumber, fullstring '20
                Line Input #filenumber, fullstring
                y1 = Val(fullstring)
                Line Input #filenumber, fullstring '30
                Line Input #filenumber, fullstring
                z1 = Val(fullstring)
                
                wksSurface.Cells(irow, 7) = x1
                wksSurface.Cells(irow, 8) = y1
                wksSurface.Cells(irow, 9) = z1
                wksSurface.Cells(irow, 10) = z1 + zOffset
                irow = irow + 1
            Wend
            
            
            
NextLayer:
        'Flag points to exclude
            Application.StatusBar = "Processing vertex data..."
            If distFlag = True Then
                'First data point in polyline is included
                wksSurface.Cells(srow, 11) = 1
                x1 = wksSurface.Cells(srow, 7)
                y1 = wksSurface.Cells(srow, 8)
                z1 = wksSurface.Cells(srow, 10)
                
                'Loop through polyline vertices and flag using distFilter criteria
                For i = srow + 1 To irow - 1
                    x2 = wksSurface.Cells(i, 7)
                    y2 = wksSurface.Cells(i, 8)
                    z2 = wksSurface.Cells(i, 10)
                    
                    dist = Sqr((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
                    If dist < distFilter Then
                        wksSurface.Cells(i, 11) = 0
                    Else
                        wksSurface.Cells(i, 11) = 1      'Flag for contouring
                        x1 = x2
                        y1 = y2
                        z1 = z2
                    End If
                Next i
            End If
        End If
    Loop
            
endoffile:
    Close #filenumber

'Remove duplicate values
    With wksSurface.Sort
        .SortFields.Clear
        .SortFields.Add Key:=wksSurface.Cells(3, 11), Order:=xlDescending
        .SortFields.Add Key:=wksSurface.Cells(7, 11), Order:=xlAscending
        .SortFields.Add Key:=wksSurface.Cells(8, 11), Order:=xlAscending
        .SortFields.Add Key:=wksSurface.Cells(9, 11), Order:=xlAscending
        .SetRange wksSurface.Range(wksSurface.Cells(3, 7), wksSurface.Cells(irow - 1, 11))
        .Header = xlNo
        .Apply
    End With

    srow = 3
    x1 = Round(wksSurface.Cells(srow, 7), 2)
    y1 = Round(wksSurface.Cells(srow, 8), 2)
    z1 = Round(wksSurface.Cells(srow, 10), 2)
    srow = srow + 1
    
    While wksSurface.Cells(srow, 11) = 1
        x2 = Round(wksSurface.Cells(srow, 7), 2)
        y2 = Round(wksSurface.Cells(srow, 8), 2)
        z2 = Round(wksSurface.Cells(srow, 10), 2)
        
        If x1 = x2 And y1 = y2 And z1 = z2 Then
            wksSurface.Cells(srow, 11) = 0
        End If
        
        x1 = x2
        y1 = y2
        z1 = z2
        srow = srow + 1
    Wend
    
    With wksSurface.Sort
        .SortFields.Clear
        .SortFields.Add Key:=wksSurface.Cells(3, 11), Order:=xlDescending
        .SortFields.Add Key:=wksSurface.Cells(7, 11), Order:=xlAscending
        .SortFields.Add Key:=wksSurface.Cells(8, 11), Order:=xlAscending
        .SortFields.Add Key:=wksSurface.Cells(9, 11), Order:=xlAscending
        .SetRange wksSurface.Range(wksSurface.Cells(3, 7), wksSurface.Cells(irow - 1, 11))
        .Header = xlNo
        .Apply
    End With
    
    Application.StatusBar = "Appending data to Input worksheet..."
    numpoints = WorksheetFunction.Sum(wksSurface.Columns("K:K"))
    appendCheck = MsgBox("Do you want to append data to Master list?" & vbLf & vbLf _
                    & "Number of points to append: " & numpoints, vbQuestion + vbYesNo + vbDefaultButton2, "APPEND DATA TO MASTER?")
    
    If appendCheck = vbNo Then Exit Sub
    
    'Append Data to Master worksheet
    'Prompt user for Date, Category and Plot_Flag fields
    sdate = InputBox("Enter contour plan date" & vbLf & vbLf & "Enter date as: DD/MM/YYYY" & vbLf & "(Field can be left blank)", _
                    "Watertable profile date", "DD/MM/YYYY")
    
    If sdate = "" Then
        sdate = "-"
    Else
        sdate = DateValue(sdate)
    End If
            
    cat_field = InputBox("Enter Category Name: " & vbLf & vbLf, _
                "CATEGORY NAME FOR SECTION POINTS", "Surface")
            
    'Populate array with all section points
    ReDim sec_array(numpoints, 4)
    
    For i = 3 To numpoints + 2
        sec_array(i - 2, 1) = wksSurface.Cells(i, 7)        'Real X
        sec_array(i - 2, 2) = wksSurface.Cells(i, 8)        'Real Y
        sec_array(i - 2, 3) = wksSurface.Cells(i, 10)       'Elevation
        sec_array(i - 2, 4) = file_name                     'SurfaceName
    Next i
    
    'Copy section points to end of Master list
    wksData.Activate
    
    'Find first empty row in Master list
    jrow = 8
    Do Until wksData.Cells(jrow, 1) = ""
        jrow = jrow + 1
    Loop
    
    id_count = 1    'Point ID counter
    For i = 1 To numpoints
        wksData.Cells(jrow, 1) = sec_array(i, 4) & "-" & id_count         'Point_ID
        wksData.Cells(jrow, 2) = sec_array(i, 4)                          'Section Name
        wksData.Cells(jrow, 3) = sec_array(i, 1)                          'Real X
        wksData.Cells(jrow, 4) = sec_array(i, 2)                          'Real Y
        wksData.Cells(jrow, 5) = "-"
        wksData.Cells(jrow, 6) = sec_array(i, 3)                          'Elevation
        wksData.Cells(jrow, 7) = "-"
        wksData.Cells(jrow, 8) = sdate                                    'Date
        wksData.Cells(jrow, 9) = cat_field                                'Category
        wksData.Cells(jrow, 10) = 1                                       'Plot Flag
        
        id_count = id_count + 1
        jrow = jrow + 1
    Next i
Next ifile

End Sub

Sub IIIb_SrfGrd_from_polylineDXF()
'Create surfer grid file from PolylineDXF contours

'Declarations
Dim fs, f
Dim colCount As Integer
Dim filetyp As String
Dim rootname As String
Dim delim As String
Dim strDirOut As String

Set wksSurface = Sheets("SURFACE")
Set wksSurfer = Sheets("SURFER")
Set wksData = Sheets("Input")
Set wksScript = Sheets("Script")

'Assign variables for output files
filetyp = ".csv"
rootname = wksSurface.Cells(5, 1)
delim = ","
strDirOut = wksSurface.Cells(6, 1)
If Right(strDirOut, 1) <> "\" Then strDirOut = strDirOut & "\"

'Reset vertical offset value (ZOffset) to zero
wksSurface.Cells(7, 1) = 0

'Extract vertices from polylineDXF contours
Call IIIa_pts_from_surface_contours

'Check Surfer version
surfCheck = MsgBox("Are you running Surfer V12 or older?", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM SURFER VERSION")
If surfCheck = vbYes Then
    'Surfer 12 or older
    surfType = 12
Else
    'Surfer 13 or later
    surfType = 13
End If

'Create .csv file of .DXF vertices
wksScript.Cells.Clear
irow = 3       'First row of point data to check
colCount = 9    'Number of columns to write to .csv file

sdate = InputBox("Enter contour plan date" & vbLf & vbLf & "Enter date as: DD/MM/YYYY" & vbLf & "(Field can be left blank)", _
            "Watertable profile date", "DD/MM/YYYY")

If sdate = "" Then
    sdate = "-"
Else
    sdate = DateValue(sdate)
End If
        
cat_field = InputBox("Enter Category Name: " & vbLf & vbLf, _
            "CATEGORY NAME FOR SECTION POINTS", "Surface")

Application.StatusBar = "Writing .csv point file..."
'Write Header
wksScript.Cells(1, 1) = wksData.Cells(7, 1) & delim & _
    wksData.Cells(7, 2) & delim & _
    wksData.Cells(7, 3) & delim & _
    wksData.Cells(7, 4) & delim & _
    wksData.Cells(7, 5) & delim & _
    wksData.Cells(7, 6) & delim & _
    wksData.Cells(7, 7) & delim & _
    wksData.Cells(7, 8) & delim & _
    wksData.Cells(7, 9)
    
srow = 2
icount = 1

'Write .CSV point file
While wksSurface.Cells(irow, 11) = 1
    wksScript.Cells(srow, 1) = rootname & "-" & icount & delim & _
    rootname & delim & _
    wksSurface.Cells(irow, 7) & delim & _
    wksSurface.Cells(irow, 8) & delim & _
    "-" & delim & _
    wksSurface.Cells(irow, 9) & delim & _
    "-" & delim & _
    sdate & delim & _
    cat_field
    
    srow = srow + 1
    irow = irow + 1
Wend

fileSaveName = strDirOut & rootname & filetyp
wksScript.Copy

If Not fileSaveName = False Then
 ActiveWorkbook.SaveAs Filename:=fileSaveName, _
        FileFormat:=xlTextPrinter, CreateBackup:=False
End If

ActiveWorkbook.Close savechanges:=False 'close the script file

'Open Surfer
Dim SurferApp As Object
Dim outfile4 As String
Set wksSurfer = Sheets("SURFER")
Set SurferApp = CreateObject("Surfer.Application")

'Surfer Variables
infile1 = strDirOut & rootname & filetyp                '.csv filepath
outfile1 = strDirOut & rootname & ".grd"                'name of output file (.grd)
outfile2 = strDirOut & rootname & ".shp"                'name of output file (.shp)
outfile4 = strDirOut & rootname & "_Grid_XYZ" & ".dat"  'name of output file (.dat)
x_default = Val(wksSurfer.Cells(11, 1))                 'initial grid size, x-axis (taken from surfer wksheet)
y_default = Val(wksSurfer.Cells(12, 1))                 'initial grid size, y-axis (taken from surfer wksheet)

'Headers for Surfer settings (write to columns L:M in SURFACE worksheet)
wksSurface.Cells(1, 12) = "SURFER OUTPUT REPORT"
wksSurface.Cells(3, 12) = "Grid Geometry"
wksSurface.Cells(4, 12) = "X min."
wksSurface.Cells(5, 12) = "X max."
wksSurface.Cells(6, 12) = "Cell Size (x)"

wksSurface.Cells(7, 12) = "Y min."
wksSurface.Cells(8, 12) = "Y max."
wksSurface.Cells(9, 12) = "Cell Size (y)"

wksSurface.Cells(11, 12) = "Interpolation Method"
wksSurface.Cells(12, 12) = "Blanking Value"
wksSurface.Cells(13, 12) = "Contour Level"

wksSurface.Cells(15, 12) = ".GRD file (Surfer)"
wksSurface.Cells(17, 12) = ".SHP file"
'wksSurface.Cells(18, 12) = ".DXF Contour file"

Application.StatusBar = "Opening Surfer..."

'Opens data file in worksheet
Set Wks = SurferApp.Documents.Open(infile1)

'Prompt user to confirm max/min x-dimensions of grid
mycheck = 7
x_spacing = x_default
x_buffer = x_default * 2


x_minSurf = Round(WorksheetFunction.Min(wksSurface.Columns("G:G")), 2)
x_maxSurf = Round(WorksheetFunction.Max(wksSurface.Columns("G:G")), 2)
x_minGRD = WorksheetFunction.Floor(x_minSurf, x_spacing) - x_buffer
x_maxGRD = WorksheetFunction.Ceiling(x_maxSurf, x_spacing) + x_buffer

x_diffGRD = x_maxGRD - x_minGRD

Do Until mycheck = 6
    x_spacing = Val(InputBox("Default grid dimensions (x-direction): " & x_default & vbLf _
            & "Min. X = " & x_minSurf & vbLf _
            & "Max. X = " & x_maxSurf & vbLf & vbLf _
            & "Grid Min. X = " & x_minGRD & vbLf _
            & "Grid Max. X = " & x_maxGRD, _
            "Size of grid cells (x-direction)", x_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    x_buffer = x_spacing * 2
    x_minGRD = WorksheetFunction.Floor(x_minSurf, x_spacing) - x_buffer
    x_maxGRD = WorksheetFunction.Ceiling(x_maxSurf, x_spacing) + x_buffer
    x_diffGRD = x_maxGRD - x_minGRD
    
    mycheck = MsgBox("Range of point data (x-direction)" & vbLf _
            & "Min. X (actual)= " & x_minSurf & vbLf _
            & "Max. X (actual)= " & x_maxSurf & vbLf & vbLf _
            & "Grid Min. X = " & x_minGRD & vbLf _
            & "Grid Max. X = " & x_maxGRD & vbLf _
            & "Grid cell size (x-direction) = " & x_spacing & vbLf _
            & "Number of columns = " & x_diffGRD / x_spacing & vbLf _
            , vbYesNoCancel, "Confirm grid dimensions (x-direction)")
    If mycheck = 2 Then Exit Sub
Loop

'Prompt user to confirm max/min y-dimensions of grid
mycheck = 7
y_spacing = y_default
y_buffer = y_default * 2

y_minSurf = Round(WorksheetFunction.Min(wksSurface.Columns("H:H")), 2)
y_maxSurf = Round(WorksheetFunction.Max(wksSurface.Columns("H:H")), 2)
y_minGRD = WorksheetFunction.Floor(y_minSurf, y_spacing) - y_buffer
y_maxGRD = WorksheetFunction.Ceiling(y_maxSurf, y_spacing) + y_buffer

y_diffGRD = y_maxGRD - y_minGRD

Do Until mycheck = 6
    y_spacing = Val(InputBox("Default grid dimensions (y-direction): " & y_default & vbLf _
            & "Min. Y = " & y_minSurf & vbLf _
            & "Max. Y = " & y_maxSurf & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD, _
            "Size of grid cells (y-direction)", y_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    y_buffer = y_spacing * 2
    y_minGRD = WorksheetFunction.Floor(y_minSurf, y_spacing) - y_buffer
    y_maxGRD = WorksheetFunction.Ceiling(y_maxSurf, y_spacing) + y_buffer
    y_diffGRD = y_maxGRD - y_minGRD
    
    mycheck = MsgBox("Range of point data (y-direction)" & vbLf _
            & "Min. Y (actual)= " & y_minSurf & vbLf _
            & "Max. Y (actual)= " & y_maxSurf & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD & vbLf _
            & "Grid cell size (y-direction) = " & y_spacing & vbLf _
            & "Number of rows = " & y_diffGRD / y_spacing & vbLf _
            , vbYesNoCancel, "Confirm grid dimensions (y-direction)")
    If mycheck = 2 Then Exit Sub
Loop

'write grid geometry
wksSurface.Cells(4, 13) = x_minGRD
wksSurface.Cells(5, 13) = x_maxGRD
wksSurface.Cells(6, 13) = x_spacing

wksSurface.Cells(7, 13) = y_minGRD
wksSurface.Cells(8, 13) = y_maxGRD
wksSurface.Cells(9, 13) = y_spacing

'Creates a plot document window
Set plot = SurferApp.Documents.Add

jcols = (x_diffGRD / x_spacing) + 1
jrows = (y_diffGRD / y_spacing) + 1

'Assign Gridding Algorithm variable
gridAlgorithm = InputBox("Enter interpolation method number" & vbLf & _
            "2 = Krigging" & vbLf & _
            "9 = Triangulation with Linear Interpolation" & vbLf & vbLf, _
            "Interpolation Method", 9)

If gridAlgorithm = 2 Then wksSurface.Cells(11, 13) = "Kriging"
If gridAlgorithm = 9 Then
    wksSurface.Cells(11, 13) = "Triangulation with Lin. Interp."
    'blnFilename = strDirOut & rootname & ".bln"
End If

'Assign Blanking value variable
'gridBlankVal = wksSurfer.Cells(16, 1)
'wksSurfer.Cells(12, 5) = gridBlankVal

Application.StatusBar = "Creating Surfer Grid..."
Set srfGrid = SurferApp.NewGrid

'Create Surfer .GRD file.
If surfType = 12 Then
    If gridAlgorithm <> 9 Then
        srfGrid = SurferApp.GridData2(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
                xmin:=x_minGRD, xmax:=x_maxGRD, _
                ymin:=y_minGRD, ymax:=y_maxGRD, _
                numCols:=jcols, NumRows:=jrows, _
                Algorithm:=gridAlgorithm, _
                outGrid:=outfile1)
    Else
        srfGrid = SurferApp.GridData(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
                xmin:=x_minGRD, xmax:=x_maxGRD, _
                ymin:=y_minGRD, ymax:=y_maxGRD, _
                numCols:=jcols, NumRows:=jrows, _
                Algorithm:=gridAlgorithm, _
                TriangleFileName:=blnFilename, _
                outGrid:=outfile1)
    End If
    
ElseIf surfType = 13 Then
    'Prompt user for Convex Hull option
    HullCheck = MsgBox("Blank grid values outside convex hull of data?", vbQuestion + vbYesNo + vbDefaultButton1, "EXTENT OF GRID")
    
    If HullCheck = vbYes Then
        hullFlag = 1
    Else
         hullFlag = 0
    End If
    
    If gridAlgorithm <> 9 Then
        srfGrid = SurferApp.GridData4(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
                xmin:=x_minGRD, xmax:=x_maxGRD, _
                ymin:=y_minGRD, ymax:=y_maxGRD, _
                numCols:=jcols, NumRows:=jrows, _
                Algorithm:=gridAlgorithm, _
                BlankOutsideHull:=hullFlag, _
                outGrid:=outfile1)
    Else
        srfGrid = SurferApp.GridData4(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
                xmin:=x_minGRD, xmax:=x_maxGRD, _
                ymin:=y_minGRD, ymax:=y_maxGRD, _
                numCols:=jcols, NumRows:=jrows, _
                Algorithm:=gridAlgorithm, _
                BlankOutsideHull:=hullFlag, _
                TriangleFileName:=blnFilename, _
                outGrid:=outfile1)
    End If
End If
         
wksSurface.Cells(15, 13) = outfile1   'Surfer .GRD filepath
    
'Create X Y Z .dat file of grid nodes
srfgrid_xyz = SurferApp.GridConvert2(inGrid:=outfile1, outGrid:=outfile4, _
        OutFmt:=4, _
        OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=4")

Application.StatusBar = "Creating Contours..."
'Creates a contour map from the grid file
clvl = wksSurface.Cells(9, 1)
minZ = WorksheetFunction.Floor(WorksheetFunction.Min(wksSurface.Columns("J:J")), clvl)
maxZ = WorksheetFunction.Ceiling(WorksheetFunction.Max(wksSurface.Columns("J:J")), clvl)

Dim map As Object
Set map = plot.Shapes.AddContourMap(outfile1)

Dim ContourMap As Object
Set ContourMap = plot.Shapes.Item(1).overlays.Item(1)

Dim ContourLevels As Object
Set ContourLevels = ContourMap.Levels
mycontours = ContourLevels.AutoGenerate(MinLevel:=minZ, MaxLevel:=maxZ, Interval:=clvl)
    
wksSurface.Cells(13, 13) = clvl   'Contour interval
    
'Create .shp, .dxf files of contours and exports
Application.StatusBar = "Exporting .SHP file of contours..."
ContourMap.ExportContours(Filename:=outfile2, Format:=3) = myexport           'SHP filepath
wksSurface.Cells(17, 13) = outfile2

'Application.StatusBar = "Exporting .DXF file of contours..."
'ContourMap.ExportContours(Filename:=outfile3, Format:=1) = myexport           'DXF filepath
'wksSurface.Cells(18, 13) = outfile3
Wks.Close

'Convert grid_xyz.dat file to csv with header row
Application.StatusBar = "Convert .DAT file to .csv..."
Call dat2csv(outfile4)

wksSurface.Cells(19, 12) = ".GRD file (csv)"
wksSurface.Cells(19, 13) = Replace(outfile4, ".dat", ".csv")

Application.StatusBar = "Done."

'Calculate Residuals. For now, only works for Surfer version 12 and earlier
Dim resCheck As Integer

If surfType = 12 Then
    resCheck = MsgBox("Append Residuals to .csv file?", vbQuestion + vbYesNo + vbDefaultButton2, "Calculate Residuals")
    If resCheck = vbYes Then Call srfGrdResiduals(filetyp, rootname, strDirOut, delim, colCount)
End If

End Sub

Sub IIIc_Difference_SrfGrds()
'Macro calculates difference between two surfer girds
'User is prompted to select Grids A and B in the Public Function GridCompatibilityCheck()

'v1.1 SWM
    'Include lines of code to check if the the _extracted.grd file was created in the GridCompatabilityCheck()
    'If Grid A and Grid B have exact same dimensions/extents, the _extracted.grd file is not created

'Variables needed by GridCompatibilityCheck() Public Function
Dim SurferApp As Object
Dim strDirOut As String
Dim rootname_A As String
Dim rootname_B As String
Dim GridA As String
Dim GridB As String

'Variables needed for dat2csv function
Dim outfile4 As String

'Variables needed for srfFillContours function
Dim outfile10 As String
Dim ContourMap As Object
Dim clvl As Double
Dim zMin_diff As Double
Dim zMax_diff As Double

Set wksSurface = Sheets("SURFACE")
wksSurface.Activate

'Output folder assignment
If wksSurface.Cells(13, 1) = "" Then
    strDirOut = Application.ActiveWorkbook.Path
Else
    strDirOut = wksSurface.Cells(13, 1)
    If Right(strDirOut, 1) <> "\" Then strDirOut = strDirOut & "\"
End If

Application.StatusBar = "Opening Surfer and importing grids..."
'Open Surfer
Set SurferApp = CreateObject("Surfer.Application")
SurferApp.Visible = True

'Creates a plot document window
Dim plot As Object
'Set plot = SurferApp.Documents.Add

Call GridCompatibilityCheck(SurferApp, strDirOut, rootname_A, rootname_B, GridA, GridB)

'Verify Grid Math Options
gridMathCheck = MsgBox("Grid A:  " & rootname_A & vbLf & _
            "Grid B:  " & rootname_B & vbLf & _
            "Difference Grid = Grid A - Grid B" & vbLf & vbLf & _
            "Click NO for Grid B - Grid A", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM GRID MATH")

'Use Grid Math to perform function on all grids specified above
Application.StatusBar = "Creating Difference Grid..."

If gridMathCheck = vbYes Then
    outfile10 = strDirOut & "Diff_" & rootname_A & "-" & rootname_B & ".grd"
    If Dir(strDirOut & rootname_A & "_extracted.grd") <> "" Then
        srfGridDiff = SurferApp.GridMath(Function:="C=A-B", IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "DIFFERENCE GRID: GRID_A - GRID_B"
    Else
        srfGridDiff = SurferApp.GridMath(Function:="C=A-B", IngridA:=strDirOut & rootname_A & ".grd", InGridB:=strDirOut & rootname_B & ".grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "DIFFERENCE GRID: GRID_A - GRID_B"
    End If
Else
    outfile10 = strDirOut & "Diff_" & rootname_B & "-" & rootname_A & ".grd"
    If Dir(strDirOut & rootname_A & "_extracted.grd") <> "" Then
        srfGridDiff = SurferApp.GridMath(Function:="C=B-A", IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "DIFFERENCE GRID: GRID_B - GRID_A"
    Else
        srfGridDiff = SurferApp.GridMath(Function:="C=B-A", IngridA:=strDirOut & rootname_A & ".grd", InGridB:=strDirOut & rootname_B & ".grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "DIFFERENCE GRID: GRID_B - GRID_A"
    End If
End If

'Delete extracted grids (keeps directory clean)
If wksSurface.Cells(14, 1) = "Y" And Dir(strDirOut & rootname_A & "_extracted.grd") <> "" Then
    Kill (strDirOut & rootname_A & "_extracted.grd")
    Kill (strDirOut & rootname_B & "_extracted.grd")
    wksSurface.Cells(13, 10).Clear
    wksSurface.Cells(13, 11).Clear
    wksSurface.Cells(13, 12).Clear
End If

wksSurface.Cells(15, 10).Font.Bold = True
wksSurface.Cells(16, 11) = outfile10
wksSurface.Cells(16, 12) = "Difference grid file (.GRD)"

'Create X Y Z .dat file of grid nodes. Convert it to .csv
Application.StatusBar = "Creating XYZ .DAT file of grid..."
outfile4 = Replace(outfile10, ".grd", ".dat")
srfgrid_xyz = SurferApp.GridConvert2(inGrid:=outfile10, outGrid:=outfile4, _
        OutFmt:=4, _
        OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=8")

Application.StatusBar = "Convert .DAT file to .csv..."
Call dat2csv(outfile4)

Dim srfDiffGrid As Object
Set srfDiffGrid = SurferApp.NewGrid
myDiffGrid = srfDiffGrid.LoadFile(outfile10, True)
zMin_diff = srfDiffGrid.zMin
zMax_diff = srfDiffGrid.zMax

clvl = Val(InputBox("Contour settings for difference grid map:" & vbLf _
            & "Min. Z = " & Round(zMin_diff, 2) & vbLf _
            & "Max. Y = " & Round(zMax_diff, 2) & vbLf & vbLf _
            & "Enter contour interval" & vbLf, _
            "CONTOUR LEVEL", 5))

Call srfFillContours(SurferApp, ContourMap, outfile10, clvl, zMin_diff, zMax_diff)

wksSurface.Cells(19, 11) = clvl
wksSurface.Cells(19, 12) = "Contour Level"

wksSurface.Cells(20, 11) = Round(zMin_diff, 2)
wksSurface.Cells(20, 12) = "zMin (Difference Grid)"
wksSurface.Cells(21, 11) = Round(zMax_diff, 2)
wksSurface.Cells(21, 12) = "zMax (Difference Grid)"

'Create .shp, .dxf files of contours and exports
Application.StatusBar = "Exporting .SHP file of contours..."
If gridMathCheck = vbYes Then
    outfile2 = strDirOut & "Diff_" & rootname_A & "-" & rootname_B & ".shp"
Else
    outfile2 = strDirOut & "Diff_" & rootname_B & "-" & rootname_A & ".shp"
End If
ContourMap.ExportContours(Filename:=outfile2, Format:=3) = myexport         'SHP filepath
wksSurface.Cells(17, 11) = outfile2
wksSurface.Cells(17, 12) = ".SHP file"

Application.StatusBar = "Exporting .DXF file of contours..."
If gridMathCheck = vbYes Then
    outfile3 = strDirOut & "Diff_" & rootname_A & "-" & rootname_B & ".dxf"
Else
    outfile3 = strDirOut & "Diff_" & rootname_B & "-" & rootname_A & ".dxf"
End If
ContourMap.ExportContours(Filename:=outfile3, Format:=1) = myexport           'DXF filepath
wksSurface.Cells(18, 11) = outfile3
wksSurface.Cells(18, 12) = ".DXF file"

Application.StatusBar = "Difference Grid calculation completed"
End Sub

Sub IIId_CombineGrids_Bounding()
'Clip a Primary grid using a Bounding grid
    'The Gridmath() function is executed on the overlapping portions of the Primary and Bounding grids
    'The Gridmath() function creates a grid that is equal to/smaller than the original Primary grid.
    'The GridMosaic() function is then used to update the Primary grid with the bounded grid created using Gridmath().
    'This preserves the extents of the Primary grid
    
'The bounding grid can represent topography, geolgic contact, fault surface
'Useful workflow for ensure water table does not daylight ground surface

'Variables needed by GridCompatibilityCheck() Public Function
Dim SurferApp As Object
Dim strDirOut As String
Dim rootname_A As String
Dim rootname_B As String
Dim GridA As String
Dim GridB As String

'Variables needed for dat2csv function
Dim outfile4 As String

'Variables needed for srfGridMosaicLastNode function
Dim PGrid As String
Dim outfile10 As String

'Variables needed for SrfGrdResiduals function
Dim resfiletyp As String
Dim resRootname As String
Dim resStrDirOut As String
Dim resdelim As String
Dim colCount As String

Set wksSurface = Sheets("SURFACE")
wksSurface.Activate

'Output folder assignment
If wksSurface.Cells(20, 1) = "" Then
    strDirOut = Application.ActiveWorkbook.Path
Else
    strDirOut = wksSurface.Cells(20, 1)
    If Right(strDirOut, 1) <> "\" Then strDirOut = strDirOut & "\"
End If

zOffset = wksSurface.Cells(21, 1)

Application.StatusBar = "Opening Surfer and importing grids..."
'Open Surfer
Set SurferApp = CreateObject("Surfer.Application")
SurferApp.Visible = True

'Creates a plot document window
Dim plot As Object
Set plot = SurferApp.Documents.Add

Call GridCompatibilityCheck(SurferApp, strDirOut, rootname_A, rootname_B, GridA, GridB)

'Verify Grid Math Options
gridMathCheck = MsgBox("Primary grid (Grid A):  " & rootname_A & vbLf & _
            "Bounding grid (Grid B):  " & rootname_B & vbLf & vbLf & _
            "Click NO to switch Primary grid and Bounding grid assignment ", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM GRID ASSIGNMENT")

'Use Grid Math to perform function on all grids specified above
Application.StatusBar = "Creating Bounded Grid..."

If gridMathCheck = 6 Then
    'Verify Bounding Type (Upperbound/Lowerbound)
    Boundtype = Val(InputBox("Bounding Grid: " & rootname_B & ".grd" & vbLf & vbLf & _
                    "Enter 1 for Upperbound surface" & vbLf & "  (Bounding grid is above the Primary grid)." & vbLf & vbLf & _
                    "Enter -1 for Lowerbound surface" & vbLf & "  (Bounding grid is below the Primary grid).", _
                    "BOUNDING SURFACE TYPE", 1))
    If Boundtype <> 1 And Boundtype <> -1 Then
        temp = MsgBox("Invalid Boundary Type assignment", vbOKOnly, "ERROR")
        Application.StatusBar = "Ending Macro"
        Exit Sub
    End If
    
    'Establish offset value
    If Boundtype = 1 Then
        zOffset = Abs(Val(InputBox("Confirm Z offset value" & vbLf & vbLf & _
                    "Upperbound surface: Primary grid will be at bounding surface - Z offset or lower.", _
                    "Z OFFSET VALUE", zOffset, 1)))
    Else
        zOffset = Abs(Val(InputBox("Confirm Z offset value" & vbLf & vbLf & _
                    "Lowerbound surface: Primary grid will be at bounding surface + Z offset or higher.", _
                    "Z OFFSET VALUE", zOffset, 1)))
    End If
    outfile10 = strDirOut & rootname_A & "_bounded.grd"
    
    If Boundtype = 1 Then
        mathString = "C=IF(A>=B-" & zOffset & ",B-" & zOffset & ",A)"
        srfGridDiff = SurferApp.GridMath(Function:=mathString, IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "BOUNDED GRID: " & "IF(A>=B-" & zOffset & ",B-" & zOffset & ",A)"
    Else
        mathString = "C=IF(A<=B+" & zOffset & ",B+" & zOffset & ",A)"
        srfGridDiff = SurferApp.GridMath(Function:=mathString, IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "BOUNDED GRID: " & "IF(A<=B+" & zOffset & ",B+" & zOffset & ",A)"
    End If
Else
    'Verify Bounding Type (Upperbound/Lowerbound)
    Boundtype = Val(InputBox("Bounding Grid: " & rootname_A & ".grd" & vbLf & vbLf & _
                    "Enter 1 for Upperbound surface" & vbLf & "  (Bounding grid is above the Primary grid)." & vbLf & vbLf & _
                    "Enter -1 for Lowerbound surface" & vbLf & "  (Bounding grid is below the Primary grid).", _
                    "BOUNDING SURFACE TYPE", 1))
    If Boundtype <> 1 And Boundtype <> -1 Then
        temp = MsgBox("Invalid Boundary Type assignment", vbOKOnly, "ERROR")
        Application.StatusBar = "Ending Macro"
        Exit Sub
    End If
    
    'Establish offset value
    If Boundtype = 1 Then
        zOffset = Abs(Val(InputBox("Confirm Z offset value" & vbLf & vbLf & _
                    "Upperbound surface: Primary grid will be at bounding surface - Z offset or lower.", _
                    "Z OFFSET VALUE", zOffset, 1)))
    Else
        zOffset = Abs(Val(InputBox("Confirm Z offset value" & vbLf & vbLf & _
                    "Lowerbound surface: Primary grid will be at bounding surface + Z offset or higher.", _
                    "Z OFFSET VALUE", zOffset, 1)))
    End If
    
    outfile10 = strDirOut & rootname_B & "_bounded.grd"
    
    If Boundtype = 1 Then
        mathString = "C=IF(B>=A-" & zOffset & ",A-" & zOffset & ",B)"
        srfGridDiff = SurferApp.GridMath(Function:=mathString, IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "BOUNDED GRID: " & "IF(B>=A-" & zOffset & ",A-" & zOffset & ",B)"
    Else
        mathString = "C=IF(B<=A+" & zOffset & ",A+" & zOffset & ",B)"
        srfGridDiff = SurferApp.GridMath(Function:=mathString, IngridA:=strDirOut & rootname_A & "_extracted.grd", InGridB:=strDirOut & rootname_B & "_extracted.grd", OutGridC:=outfile10)
        wksSurface.Cells(15, 10) = "BOUNDED GRID: " & "IF(B<=A+" & zOffset & ",A+" & zOffset & ",B)"
    End If
End If

'Delete extracted grids (keeps directory clean)
Kill (strDirOut & rootname_A & "_extracted.grd")
Kill (strDirOut & rootname_B & "_extracted.grd")
wksSurface.Cells(13, 10).Clear
wksSurface.Cells(13, 11).Clear
wksSurface.Cells(13, 12).Clear

'Create GridMosaic
    'PGrid = Primary Grid, before bounding
    'Outfile10 = PGrid bounded by BGrid
    'GridMosaic_Last combines PGrid and outfile10. In case of overlapping nodes, use values from outfile10

If gridMathCheck = 6 Then
    PGrid = GridA
Else
    PGrid = GridB
End If

Call srfGridMosaicLastNode(SurferApp, PGrid, outfile10, outfile10)

wksSurface.Cells(15, 10).Font.Bold = True
wksSurface.Cells(16, 11) = outfile10
wksSurface.Cells(16, 12) = "Bounded grid file (.GRD)"

'Create X Y Z .dat file of grid nodes. Convert it to .csv
Application.StatusBar = "Creating XYZ .DAT file of grid..."
outfile4 = Replace(outfile10, ".grd", ".dat")
srfgrid_xyz = SurferApp.GridConvert2(inGrid:=outfile10, outGrid:=outfile4, _
        OutFmt:=4, _
        OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=8")

Application.StatusBar = "Convert .DAT file to .csv..."
Call dat2csv(outfile4)

Application.StatusBar = "Creating Contours..."
Dim srfDiffGrid As Object
Set srfDiffGrid = SurferApp.NewGrid

'Creates a contour map from the grid file
myDiffGrid = srfDiffGrid.LoadFile(outfile10, True)
zMin_diff = srfDiffGrid.zMin
zMax_diff = srfDiffGrid.zMax

clvl = Val(InputBox("Contour settings for difference grid map:" & vbLf _
            & "Min. Z = " & Round(zMin_diff, 2) & vbLf _
            & "Max. Y = " & Round(zMax_diff, 2) & vbLf & vbLf _
            & "Enter contour interval" & vbLf, _
            "CONTOUR LEVEL", Round((zMax_diff - zMin_diff) / 10, 0)))
            
wksSurface.Cells(19, 11) = clvl
wksSurface.Cells(19, 12) = "Contour Level"
wksSurface.Cells(20, 11) = Round(zMin_diff, 2)
wksSurface.Cells(20, 12) = "zMin (Bounded Grid)"
wksSurface.Cells(21, 11) = Round(zMax_diff, 2)
wksSurface.Cells(21, 12) = "zMax (Bounded Grid)"
wksSurface.Cells(22, 11) = zOffset
wksSurface.Cells(22, 12) = "zOffset"

'Create contour Map
Dim MapFrame1 As Object
Set MapFrame1 = plot.Shapes.AddContourMap(outfile10)

Dim ContourMap As Object
Set ContourMap = plot.Shapes.Item(1).overlays.Item(1)

Dim ContourLevels As Object
Set ContourLevels = ContourMap.Levels
mycontours = ContourLevels.AutoGenerate(MinLevel:=WorksheetFunction.Floor(zMin_diff, clvl), MaxLevel:=WorksheetFunction.Ceiling(zMax_diff, clvl), Interval:=clvl)

'Create .shp, .dxf files of contours and exports
Application.StatusBar = "Exporting .SHP file of contours..."
outfile2 = Replace(outfile10, ".grd", ".shp")

ContourMap.ExportContours(Filename:=outfile2, Format:=3) = myexport         'SHP filepath
wksSurface.Cells(17, 11) = outfile2
wksSurface.Cells(17, 12) = ".SHP file"

Application.StatusBar = "Exporting .DXF file of contours..."
outfile3 = Replace(outfile10, ".grd", ".dxf")
ContourMap.ExportContours(Filename:=outfile3, Format:=1) = myexport           'DXF filepath
wksSurface.Cells(18, 11) = outfile3
wksSurface.Cells(18, 12) = ".DXF file"

'Add Post-map of residuals
If wksSurface.Cells(22, 1) = "Y" Then
    Application.StatusBar = "Creating Residuals post-map..."
    filenumber = FreeFile
    myFile = Application.GetOpenFilename("Post Map File *.csv, *.csv", , "Select .CSV to create residual post map", , True)
    resFile = myFile(filenumber)
    
    'Establish the filename
    slash = ""
    temp = Len(resFile)
    i = 0

    While slash <> "\"
        slash = Mid(resFile, temp - i, 1)
        i = i + 1
    Wend
    
    resFilename = Replace(Mid(resFile, temp - i + 2, temp - i + 1), ".csv", "") 'filename
    resFileCopy = strDirOut & resFilename & "_bounded.csv"
    
    'Create copy of Residual CSV file in same directory as bounded grid
    FileCopy resFile, resFileCopy
    
    'Surfer Variables
    appendcol = 10          'Column number to write data to
    xData = 3               'Column number with X data
    yData = 4               'Column number with Y data
    zData = 6               'Column number with data to contour
    
    Set resWks = SurferApp.GridResiduals2(inGrid:=outfile10, _
            DataFile:=resFileCopy, _
            xcol:=xData, ycol:=yData, zcol:=zData, ResidCol:=appendcol)
    
    myTempVar = resWks.SaveAs(Filename:=resFileCopy)
    resWks.Close
    
    'Create Post Map of residuals
    Set MapFrame2 = plot.Shapes.AddPostMap2(DataFileName:=resFileCopy, xcol:=xData, ycol:=yData, Labcol:=appendcol)
     
    'Format Post map labels
    Set Postmap = MapFrame2.overlays(1)
         
         'Round residual label to 1 significant figure
         Postmap.LabelFormat.NumDigits = 1
         
         'Adjust font format for labels
         Set FontFormatPM = Postmap.LabelFont
         FontFormatPM.Bold = True
         FontFormatPM.Size = 12
         FontFormatPM.ForeColorRGBA.Color = RGB(255, 0, 0)
         
         'Change symbol type to solid circle
         Set SymbolFormatPM = Postmap.Symbol
         SymbolFormatPM.Index = 12
         SymbolFormatPM.FillColorRGBA.Color = RGB(255, 0, 0)
         SymbolFormatPM.LineColorRGBA.Color = RGB(255, 0, 0)
         SymbolFormatPM.Size = 0.2
    
    'Select and overlays the map objects
     myMapName = Replace(outfile10, strDirOut, "")
     myMapName = Replace(myMapName, ".grd", "")
     MapFrame1.selected = True
     MapFrame2.selected = True
     Set NewMapFrame = plot.Selection.OverlayMaps
     NewMapFrame.Name = myMapName
     
     NewMapFrame.ylength = 23
     NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
     NewMapFrame.Axes("Bottom Axis").Title = myMapName
     NewMapFrame.Axes("Bottom Axis").TitleFont.ForeColorRGBA.Color = srfColorRed
     NewMapFrame.Left = 1
     NewMapFrame.Top = 27.5
     NewMapFrame.selected = False
    
End If

Application.StatusBar = "Bounded Grid creation completed"

End Sub

Sub IIIe_srfGridVolume()
'Macro calculates the volume of the area between two surfer girds
'Volume is calculated
    'User is prompted to select Grids A and B in the Public Function GridCompatibilityCheck()
    'User will have option of blanking grids

'Variables needed by GridCompatibilityCheck() Public Function
Dim SurferApp As Object
Dim strDirOut As String
Dim rootname_A As String
Dim rootname_B As String
Dim GridA As String
Dim GridB As String

'Variables needed for dat2csv function
Dim outfile4 As String

'Variables needed for srfBlankFile function
Dim grid1 As String
Dim grid2 As String
Dim bFile As String

Set wksSurface = Sheets("SURFACE")
wksSurface.Activate

'Output folder assignment
If wksSurface.Cells(25, 1) = "" Then
    strDirOut = Application.ActiveWorkbook.Path
Else
    strDirOut = wksSurface.Cells(25, 1)
    If Right(strDirOut, 1) <> "\" Then strDirOut = strDirOut & "\"
End If

Application.StatusBar = "Opening Surfer..."
'Open Surfer
Set SurferApp = CreateObject("Surfer.Application")
SurferApp.Visible = True

Application.StatusBar = "Opening surfer grids, checking compatibility..."
Call GridCompatibilityCheck(SurferApp, strDirOut, rootname_A, rootname_B, GridA, GridB)

'Prompt for blanking file
blnFileCheck = MsgBox("Clip volume using a blanking file?", vbQuestion + vbYesNo + vbDefaultButton1, "BLANKING FILE")
    
If blnFileCheck = vbYes Then
    myFile = Application.GetOpenFilename("BLN Blanking file *.bln, *.bln", , "Select " & ".bln File", , True)

    filenumber = FreeFile
    bFile = myFile(filenumber) 'Blanking file filepath
    If Right(bFile, 4) <> ".bln" Then
        temp = MsgBox("Blanking file not a .BLN file. Macro ending...", vbOKOnly, "ERROR")
        Exit Sub
    End If
    
    grid1 = strDirOut & rootname_A & "_extracted.grd"
    grid2 = strDirOut & rootname_A & "_extracted_blanked.grd"
    wksSurface.Cells(13, 10) = grid2
    
    Call srfBlankFile(grid1, bFile, grid2)
    
    'Delete extracted grids (keeps directory clean)
    Kill (strDirOut & rootname_A & "_extracted.grd")
    rootname_A = rootname_A & "_extracted_blanked"  'New rootname
    
    grid1 = strDirOut & rootname_B & "_extracted.grd"
    grid2 = strDirOut & rootname_B & "_extracted_blanked.grd"
    wksSurface.Cells(13, 11) = grid2
     
    Call srfBlankFile(grid1, bFile, grid2)
    
    'Delete extracted grids (keeps directory clean)
    Kill (strDirOut & rootname_B & "_extracted.grd")
    rootname_B = rootname_B & "_extracted_blanked"  'New rootname
Else
    rootname_A = rootname_A & "_extracted"
    rootname_B = rootname_B & "_extracted"
End If

'Verify GridVolume surface assignment
gridMathCheck = MsgBox("Upper Surface:  " & rootname_A & vbLf & _
            "Lower Surface:  " & rootname_B & vbLf & vbLf & _
            "Click NO to flip upper/lower surface assignment", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM UPPER/LOWER SURFACES")

'Verify Surfer version
surfCheck = MsgBox("Are you running Surfer V12 or older?", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM SURFER VERSION")

'Use GridVolume or GridVolume2 function to calculate volume between surfaces
Application.StatusBar = "Calculating Volume between surfaces..."
Dim myResults() As Double
ReDim myResults(10)
Dim myResultsTitle(10)

myResultsTitle(0) = "(L^3) Volume calculated by Trapezoidal rule"
myResultsTitle(1) = "(L^3) Volume calculated by Simpsons's rule"
myResultsTitle(2) = "(L^3) Volume calculated by Simpsons's 3/8 rule"
myResultsTitle(3) = "(L^3) Positive volume (cut)"
myResultsTitle(4) = "(L^3) Negative volume (fill)"
myResultsTitle(5) = "(L^2)Positive planar area (upper surface above lower surface)"
myResultsTitle(6) = "(L^2) Negative planar area (lower surface above upper surface)"
myResultsTitle(7) = "(L^2) Positive surface area (lower surface above upper surface)"
myResultsTitle(8) = "(L^2) Negative surface area (lower surface above upper surface)"
myResultsTitle(9) = "(L^2) Blanked planar area"

wksSurface.Cells(16, 11) = "VOLUME CALCULATIONS"
wksSurface.Cells(16, 11).Font.Bold = True

If gridMathCheck = vbYes Then
    wksSurface.Cells(14, 10) = "Upper"
    wksSurface.Cells(14, 11) = "Lower"
    wksSurface.Cells(14, 12) = "Surface Type"
    
    'Execute gridvolume function, create difference plot
    If surfCheck = vbYes Then
        srfGridVol = SurferApp.GridVolume(Upper:=strDirOut & rootname_A & ".grd", Lower:=strDirOut & rootname_B & ".grd", pResults:=myResults)
    Else
        srfGridVol = SurferApp.GridVolume2(Upper:=strDirOut & rootname_A & ".grd", Lower:=strDirOut & rootname_B & ".grd", pResults:=myResults)
    End If
    
    outfile10 = strDirOut & "Diff_" & rootname_A & "-" & rootname_B & ".grd"
    srfGridDiff = SurferApp.GridMath(Function:="C=A-B", IngridA:=strDirOut & rootname_A & ".grd", InGridB:=strDirOut & rootname_B & ".grd", OutGridC:=outfile10)
    
    'Write volume calculations
    For i = 0 To 9
        wksSurface.Cells(i + 17, 11) = myResults(i)
        wksSurface.Cells(i + 17, 12) = myResultsTitle(i)
    Next i
Else
    wksSurface.Cells(14, 10) = "Lower"
    wksSurface.Cells(14, 11) = "Upper"
    wksSurface.Cells(14, 12) = "Surface Type"
    
    'Execute gridvolume function, create difference plot
    If surfCheck = vbYes Then
        srfGridVol = SurferApp.GridVolume(Upper:=strDirOut & rootname_B & ".grd", Lower:=strDirOut & rootname_A & ".grd", pResults:=myResults)
    Else
        srfGridVol = SurferApp.GridVolume2(Upper:=strDirOut & rootname_B & ".grd", Lower:=strDirOut & rootname_A & ".grd", pResults:=myResults)
    End If
    
    outfile10 = strDirOut & "Diff_" & rootname_B & "-" & rootname_A & ".grd"
    srfGridDiff = SurferApp.GridMath(Function:="C=B-A", IngridA:=strDirOut & rootname_A & ".grd", InGridB:=strDirOut & rootname_B & ".grd", OutGridC:=outfile10)
    
    'Write volume calculations
    For i = 0 To 9
        wksSurface.Cells(i + 17, 11) = myResults(i)
        wksSurface.Cells(i + 17, 12) = myResultsTitle(i)
    Next i
End If


'Creates a contour map from the grid file
Application.StatusBar = "Creating Contours..."

Dim srfDiffGrid As Object
Set srfDiffGrid = SurferApp.NewGrid
myDiffGrid = srfDiffGrid.LoadFile(outfile10, True)

zMin_diff = srfDiffGrid.zMin
zMax_diff = srfDiffGrid.zMax
clvl = Val(InputBox("Contour settings for difference grid map:" & vbLf _
            & "Min. Z = " & Round(zMin_diff, 2) & vbLf _
            & "Max. Y = " & Round(zMax_diff, 2) & vbLf & vbLf _
            & "Enter contour interval" & vbLf, _
            "CONTOUR LEVEL", Round((zMax_diff - zMin_diff) / 10, 0)))


myColorMapFile = "G:\Macro_Library\Groundwater\Steve\2605_THVC\WT_Interpolator\CLR_Files\BlueRed.clr"

'Creates a plot document window
Set plot = SurferApp.Documents.Add

Dim MapFrame1 As Object
Set MapFrame1 = plot.Shapes.AddContourMap(outfile10)

'Dim ContourMap as object
Dim ContourMap As Object
Set ContourMap = plot.Shapes.Item(1).overlays.Item(1)

Dim ContourLevels As Object
Set ContourLevels = ContourMap.Levels
mycontours = ContourLevels.AutoGenerate(MinLevel:=WorksheetFunction.Floor(zMin_diff, clvl), MaxLevel:=WorksheetFunction.Ceiling(zMax_diff, clvl), Interval:=clvl)

'Dim ColorMap As Object. Adjust min/max. limits to +/- 1000
Set ColorMap = ContourMap.FillForegroundColorMap
myTempVar = ColorMap.SetDataLimits(-3000, 3000)

'Load the CLR file
ColorMap.LoadFile (myColorMapFile)

'Apply contour map fill changes
    'If NumberToSet is 1 and NumberToSkip is 0, all lines are filled.
    'If NumberToSet is 1 and NumberToSkip is 1, every other line is filled.
myTempVar = ContourMap.ApplyFillToLevels(FirstIndex:=1, NumberToSet:=1, NumberToSkip:=0)

'Show Fill Contours
ContourMap.FillContours = True
ContourMap.ShowColorScale = True

'Create base map of blanking file
If blnFileCheck = vbYes Then
    Set MapFrame2 = plot.Shapes.AddBaseMap(ImportFileName:=bFile)
    Set Basemap = MapFrame2.overlays(1)
        Basemap.Line.Width = 0.1
    
    'Select and overlays the map objects
     MapFrame1.selected = True
     MapFrame2.selected = True
     Set NewMapFrame = plot.Selection.OverlayMaps
     
     NewMapFrame.ylength = 23
     NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
     NewMapFrame.Left = 1
     NewMapFrame.Top = 27.5
     NewMapFrame.selected = False
Else
     MapFrame1.selected = True
     MapFrame1.ylength = 23
     MapFrame1.xMapPerPU = MapFrame1.yMapPerPU
     MapFrame1.Left = 1
     MapFrame1.Top = 27.5
     MapFrame1.selected = False
End If

Application.StatusBar = "Volume calculation completed"

End Sub

Sub IIIf_MakeSrfMap()
'Loads in multiple files into a single .SRF map file
'   GRD: Contour file from surfer .GRD file
'   POST: Post map from comma-deliminated file
'   BASE: Base map file

Application.StatusBar = "Creating Surfer Map..."

Set wksMapMaker = Sheets("SrfMapMaker")
wksMapMaker.Activate

Dim mFile As String
Dim mType As String

Dim SurferApp As Object
Dim plot As Object
Dim map As Object
Dim ContourLevels As Object
Dim srfGrid As Object

'Variables for color2RGB
Dim myColorString As String
Dim r As Integer
Dim g As Integer
Dim b As Integer

cCount = 0

Set SurferApp = CreateObject("Surfer.Application")
SurferApp.Visible = True

'Create new plot
Set plot = SurferApp.Documents.Add

'Loop through list of map files to load
irow = 4
While wksMapMaker.Cells(irow, 1) <> ""
    mFile = wksMapMaker.Cells(irow, 1)
    mType = UCase(wksMapMaker.Cells(irow, 2))
    
    If mType = "GRD" Then
        cCount = cCount + 1
        GoTo myGRD
    ElseIf mType = "POST" Then
        pCount = pCount + 1
         GoTo myPost
    ElseIf mType = "BASE" Then
        bCount = bCount + 1
        GoTo myBase
    Else
        GoTo skipper
    End If
    
myGRD:
    Set srfGrid = SurferApp.NewGrid
    myGrid = srfGrid.LoadFile(mFile, True)
    zMin = srfGrid.zMin
    zMax = srfGrid.zMax
    clvl = wksMapMaker.Cells(irow, 3)
    If clvl = "" Then clvl = 10 'Default contour level value
    
    Set map = plot.Shapes.AddContourMap(GridFileName:=mFile)
    Set ContourMap = plot.Shapes.Item(cCount).overlays.Item(1)
    Set ContourLevels = ContourMap.Levels
    mycontours = ContourLevels.AutoGenerate(MinLevel:=WorksheetFunction.Floor(zMin, clvl), MaxLevel:=WorksheetFunction.Ceiling(zMax, clvl), Interval:=clvl)
    
    'Fill contours?
    If LCase(wksMapMaker.Cells(irow, 4)) = "y" Then
        Set ColorMap = ContourMap.FillForegroundColorMap
        ContourMap.FillContours = True
        
        'Load colormap file
        clrCode = wksMapMaker.Cells(irow, 5)
        clrFilepath = "G:\Macro_Library\Groundwater\Steve\2605_THVC\WT_Interpolator\CLR_Files\"
        If clrCode = "" Or clrCode = 1 Then myColorMapFile = clrFilepath & "Rainbow.clr"
        If clrCode = 2 Then myColorMapFile = clrFilepath & "Rainbow2.clr"
        If clrCode = 3 Then myColorMapFile = clrFilepath & "Geology2.clr"
        ColorMap.LoadFile (myColorMapFile)
        
        'Set lower/upper limit = rounded data limits
        myTempVar = ColorMap.SetDataLimits(WorksheetFunction.Floor(zMin, clvl), WorksheetFunction.Ceiling(zMax, clvl))
        
        'Set Fill Opacity
        fOpacity = wksMapMaker.Cells(irow, 6)
        If fOpacity < 0 Or fOpacity = "" Or fOpacity > 100 Then fOpacity = 100
        ContourMap.Opacity = fOpacity
        
        'Apply contour map fill changes
            'If NumberToSet is 1 and NumberToSkip is 0, all lines are filled.
            'If NumberToSet is 1 and NumberToSkip is 1, every other line is filled.
        myTempVar = ContourMap.ApplyFillToLevels(FirstIndex:=1, NumberToSet:=1, NumberToSkip:=0)
    End If
    
    'Adjust line style, width and colour
    lStyleCode = wksMapMaker.Cells(irow, 7)
    If lStyleCode = 0 Or lStyleCode = "" Then lStyleCode = 1
    
    lWidth = wksMapMaker.Cells(irow, 8)
    If lWidth = "" Then lWidth = 0
    
    myColorString = wksMapMaker.Cells(irow, 9)
    Call Color2RGB(myColorString, r, g, b)
    
    If lStyleCode = 1 Then lStyle = "Solid"
    If lStyleCode = 2 Then lStyle = "Invisible"
    If lStyleCode = 3 Then lStyle = ".1 in. Dash"
    If lStyleCode = 4 Then lStyle = ".2 in. Dash"
    If lStyleCode = 5 Then lStyle = ".3 in. Dash"
    If lStyleCode = 6 Then lStyle = "Dash Dot"

    For i = 1 To ContourLevels.Count
        Set myContour = ContourLevels.Item(i)
        myContour.Line.Style = lStyle
        
        If lStyle <> 2 Then
            'Set Line Width
            Set LineFormat = myContour.Line
            LineFormat.Width = lWidth
            LineFormat.ForeColorRGBA.Color = RGB(r, g, b)
            'LineFormat.Opacity = 100
        End If
    Next i
    
    'Contour Labels
    If wksMapMaker.Cells(irow, 10) <> "" Then
        labInt = wksMapMaker.Cells(irow, 10)
        If lWidth = 0 Then
            mlWidth = 0.01
        Else
            mlWidth = lWidth * 2
        End If
        
        labFontSz = wksMapMaker.Cells(irow, 11)
        If labFontSz = 0 Then labFontSz = 6

        Set LabelFont = ContourMap.LabelFont
        LabelFont.Size = labFontSz
        LabelFont.Bold = True
        
        For i = 1 To ContourLevels.Count
           Set myContour = ContourLevels.Item(i)
           If myContour.Value Mod labInt = 0 Then
               Set LineFormat = myContour.Line
               LineFormat.Width = mlWidth
               myContour.ShowLabel = True
               
           End If
        Next i
    
    End If
    
    map.selected = False
    GoTo skipper

myPost:
    'Import PostMap of residuals
    xcol = wksMapMaker.Cells(irow, 13)
    ycol = wksMapMaker.Cells(irow, 14)
    zcol = wksMapMaker.Cells(irow, 15)
    
    If xcol = "" Or ycol = "" Then GoTo skipper
    Set map = plot.Shapes.AddPostMap2(DataFileName:=mFile, xcol:=xcol, ycol:=ycol, Labcol:=zcol)
    
    Set Postmap = map.overlays(1)
    Set SymbolFormatPM = Postmap.Symbol
    Set FontFormatPM = Postmap.LabelFont
    
    'Change symbol type to solid circle
        SymbolTypePM = wksMapMaker.Cells(irow, 16)
        If SymbolTypePM = "" Then SymbolTypePM = 12
        SymbolFormatPM.Index = SymbolTypePM
    
    'Change symbol size
        SymbolSzPM = wksMapMaker.Cells(irow, 17)
        If SymbolSzPM = "" Then SymbolSzPM = 0.1
        SymbolFormatPM.Size = SymbolSzPM
    
    'Change symbol fill and line colour
    myColorString = wksMapMaker.Cells(irow, 18)
    If myColorString = "" Then myColorString = "black"
    
    Call Color2RGB(myColorString, r, g, b)
    SymbolFormatPM.FillColorRGBA.Color = RGB(r, g, b)
    SymbolFormatPM.LineColorRGBA.Color = RGB(r, g, b)
    If zcol <> "" And WorksheetFunction.IsNumber(zcol) Then FontFormatPM.ForeColorRGBA.Color = RGB(r, g, b)
    
    'Format Post map labels
    If zcol <> "" And WorksheetFunction.IsNumber(zcol) Then
        'Round residual label to 1 significant figure
        Postmap.LabelFormat.NumDigits = 1
        
        'Adjust font format for labels
        labelSzPM = wksMapMaker.Cells(irow, 19)
        FontFormatPM.Bold = True
        FontFormatPM.Size = labelSzPM
    End If
    
    map.selected = False
    GoTo skipper

myBase:
    'Import basemap
    Set map = plot.Shapes.AddBaseMap(ImportFileName:=mFile)
    Set Basemap = map.overlays(1)
    
    'Line Width
    LineWidthBM = wksMapMaker.Cells(irow, 23)
    If LineWidthBM = "" Then LineWidthBM = 0.01
    Basemap.Line.Width = LineWidthBM
    
    'Line Colour
    myColorString = wksMapMaker.Cells(irow, 24)
    If myColorString = "" Then myColorString = "black"
    Call Color2RGB(myColorString, r, g, b)
    Basemap.Line.ForeColorRGBA.Color = RGB(r, g, b)
    
    'Map Opacity
    mapOpacityBM = wksMapMaker.Cells(irow, 25)
    If mapOpacityBM = "" Then mapOpacityBM = 100
    Basemap.Opacity = mapOpacityBM
    
    'Map Font
    Set FontFormatBM = Basemap.Font
    mapFontBM = wksMapMaker.Cells(irow, 26)
    If mapFontBM = "" Then mapFontBM = 4
    FontFormatBM.Size = mapFontBM
    
    'Horizontal alignment: 1 = left, 2 = center, 3 = right
    'FontFormatBM.HAlign = 1
    'Debug.Print (FontFormatBM.HAlign)
    
    map.selected = False
    
skipper:
    irow = irow + 1
Wend

'Overlay maps
Set myShapes = plot.Shapes
myShapes.SelectAll
Set NewMapFrame = plot.Selection.OverlayMaps
NewMapFrame.Name = "Combined Map"

Application.StatusBar = "Surfer Map Created"

End Sub

