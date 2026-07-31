Attribute VB_Name = "Surfer_Grd"
Sub I_MakeSrfGRD()
' Create surfer grid file from point data
' Generate contours

' v1.2 KFM
    'Added robust check for Surfer 11
' v1.1 SWM
    'Changed irow dimention to Long from Integer to accomodate more data points

'Declarations
Dim irow As Long
Dim colCount As Integer
Dim fs, f
Dim filetyp As String
Dim rootname As String
Dim delim As String
Dim strDirOut As String
Dim SurferApp As Object
Set SurferApp = CreateObject("Surfer.Application")

Const ForReading = 1, ForWriting = 2, ForAppending = 3

Set wksData = Sheets("INPUT")
Set wksSurfer = Sheets("SURFER")
Set wksScript = Sheets("Script")

wksData.Activate

'Variable Assignment
filetyp = wksData.Cells(1, 1)
rootname = wksData.Cells(2, 1)
delim = ","

'Output folder assignment
If wksData.Cells(3, 1) = "" Then
    strDirOut = Application.ActiveWorkbook.Path
Else
    strDirOut = wksData.Cells(3, 1)
    If Right(strDirOut, 1) <> "\" Then strDirOut = strDirOut & "\"
End If

ChDir strDirOut

outfile1 = strDirOut & rootname & ".grd"                'name of output file (.grd)
outfile2 = strDirOut & rootname & ".shp"                'name of output file (.shp)
outfile3 = strDirOut & rootname & ".dxf"                'name of output file (.dxf)

wksScript.Cells.Clear

irow = 8        'First row of point data to check
colCount = 9    'Number of columns to write to .csv file
xcol = 3        'Column number in CSV file with x coordinate
ycol = 4        'Column number in CSV file with y coordinate
zcol = 6        'Column number in CSV file containing contour data

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
While wksData.Cells(irow, 1) <> ""
    If wksData.Cells(irow, 10) = 1 Then
        wksScript.Cells(srow, 1) = wksData.Cells(irow, 1) & delim & _
        wksData.Cells(irow, 2) & delim & _
        wksData.Cells(irow, 3) & delim & _
        wksData.Cells(irow, 4) & delim & _
        wksData.Cells(irow, 5) & delim & _
        wksData.Cells(irow, 6) & delim & _
        wksData.Cells(irow, 7) & delim & _
        wksData.Cells(irow, 8) & delim & _
        wksData.Cells(irow, 9)
        srow = srow + 1
    End If
    irow = irow + 1
Wend

fileSaveName = strDirOut & rootname & filetyp
wksScript.Copy

If Not fileSaveName = False Then
 ActiveWorkbook.SaveAs Filename:=fileSaveName, _
        FileFormat:=xlTextPrinter, CreateBackup:=False
End If

ActiveWorkbook.Close savechanges:=False 'close the script file

surfCheck = MsgBox("Are you running Surfer V12 or older?", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM SURFER VERSION")

If surfCheck = vbYes Then
    'Surfer 12 or older
    Call GridDataSrf(filetyp, rootname, strDirOut, delim)
Else
    'Surfer 13 or later
    Call GridDataSrf13(filetyp, rootname, strDirOut, delim)
End If


'Creates a contour map from the grid file
Application.StatusBar = "Creating Contours..."
clvl = wksSurfer.Cells(15, 1)
minZ = WorksheetFunction.Floor(wksSurfer.Cells(7, 1), clvl)
maxZ = WorksheetFunction.Ceiling(wksSurfer.Cells(8, 1), clvl)

'Creates a plot document window
Set plot = SurferApp.Documents.Add

Set MapFrame1 = plot.Shapes.AddContourMap(outfile1)

Dim ContourMap As Object
Set ContourMap = plot.Shapes.Item(1).overlays.Item(1)

Dim ContourLevels As Object
Set ContourLevels = ContourMap.Levels
mycontours = ContourLevels.AutoGenerate(MinLevel:=minZ, MaxLevel:=maxZ, Interval:=clvl)
wksSurfer.Cells(13, 5) = clvl   'Contour interval
     
'Fill Contours
myColorMapFile = "G:\Macro_Library\Groundwater\Steve\2605_THVC\WT_Interpolator\CLR_Files\Geology2.clr"

'Dim ColorMap As Object. Adjust min/max. limits to +/- 1000
Set ColorMap = ContourMap.FillForegroundColorMap
myTempVar = ColorMap.SetDataLimits(minZ, maxZ)

'Load the CLR file
ColorMap.LoadFile (myColorMapFile)

'Apply contour map fill changes
'If NumberToSet is 1 and NumberToSkip is 0, all lines are filled.
'If NumberToSet is 1 and NumberToSkip is 1, every other line is filled.
myTempVar = ContourMap.ApplyFillToLevels(FirstIndex:=1, NumberToSet:=1, NumberToSkip:=0)

'Show Fill Contours
ContourMap.FillContours = True
ContourMap.ShowColorScale = True

'Create .shp, .dxf files of contours and exports
Application.StatusBar = "Exporting .SHP file of contours..."
DoEvents
Application.Wait Now + TimeValue("00:00:01")
ContourMap.ExportContours Filename:=outfile2, Format:=3

Application.StatusBar = "Exporting .DXF file of contours..."
DoEvents
Application.Wait Now + TimeValue("00:00:01")
ContourMap.ExportContours(Filename:=outfile3, Format:=1)          'DXF filepath
wksSurfer.Cells(18, 5) = outfile3

'Calculate Residuals.
Dim resCheck As Integer
resCheck = MsgBox("Append Residuals to .csv file?", vbQuestion + vbYesNo + vbDefaultButton2, "Calculate Residuals")

If resCheck = vbYes Then
    Application.StatusBar = "Appending Residuals..."
    Call srfGrdResiduals(filetyp, rootname, strDirOut, delim, colCount)
    
    'Create Post Map of residuals
    Set MapFrame2 = plot.Shapes.AddPostMap2(DataFileName:=fileSaveName, xcol:=xcol, ycol:=ycol, Labcol:=colCount + 1)
     
    'Format Post map labels
    Set Postmap = MapFrame2.overlays(1)
     
         'Round residual label to 1 significant figure
         Postmap.LabelFormat.NumDigits = 1
         
         'Adjust font format for labels
         Set FontFormatPM = Postmap.LabelFont
         FontFormatPM.Bold = True
         FontFormatPM.Size = 14
         FontFormatPM.ForeColorRGBA.Color = RGB(0, 0, 0)
         
         'Change symbol type to solid circle
         Set SymbolFormatPM = Postmap.Symbol
         SymbolFormatPM.Index = 12
         SymbolFormatPM.FillColorRGBA.Color = RGB(0, 0, 0)
         SymbolFormatPM.LineColorRGBA.Color = RGB(0, 0, 0)
         SymbolFormatPM.Size = 0.25
    
    'Select and overlays the map objects
     MapFrame1.selected = True
     MapFrame2.selected = True
     Set NewMapFrame = plot.Selection.OverlayMaps
     NewMapFrame.Name = rootname
     
     NewMapFrame.ylength = 23
     NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
     NewMapFrame.Axes("Bottom Axis").Title = rootname
     NewMapFrame.Axes("Bottom Axis").TitleFont.ForeColorRGBA.Color = srfColorRed
     NewMapFrame.Left = 1
     NewMapFrame.Top = 27.5
     NewMapFrame.selected = False

End If

Application.StatusBar = "Surfer Grid Complete"

End Sub
Sub GridDataSrf(filetyp As String, rootname As String, strDirOut As String, delim As String)

'Create Surfer grid file
'This code only works for Surfer 12 or earlier

'Open Surfer
Dim SurferApp As Object
Dim outfile4 As String
Set wksSurfer = Sheets("SURFER")
wksSurfer.Activate

Set SurferApp = CreateObject("Surfer.Application")

Dim surferPath As String
Dim surferPID As Long
Dim t As Single

surferPath = "C:\Program Files\Golden Software\Surfer 11\Surfer.exe"

If Dir(surferPath) = "" Then
    MsgBox "Surfer 11 not found at:" & vbCrLf & surferPath, vbCritical
    Exit Sub
End If

surferPID = Shell("""" & surferPath & """", vbNormalFocus)

t = Timer
Do
    On Error Resume Next
    Set SurferApp = GetObject(, "Surfer.Application")
    On Error GoTo 0

    If Not SurferApp Is Nothing Then Exit Do
    DoEvents
Loop While Timer - t < 10 ' Wait for up to 10 seconds for Surfer to start

If SurferApp Is Nothing Then
    MsgBox "Could not connect to Surfer 11.", vbCritical
    Exit Sub
End If

SurferApp.Visible = True

'Surfer Variables
infile1 = strDirOut & rootname & filetyp                '.csv filepath
outfile1 = strDirOut & rootname & ".grd"                'name of output file (.grd)
outfile2 = strDirOut & rootname & ".shp"                'name of output file (.shp)
outfile3 = strDirOut & rootname & ".dxf"                'name of output file (.dxf)
outfile4 = strDirOut & rootname & "_Grid_XYZ" & ".dat"  'name of output file (.dat)

x_default = Val(wksSurfer.Cells(11, 1))                 'initial grid size, x-axis
y_default = Val(wksSurfer.Cells(12, 1))                 'initial grid size, y-axis

'Headers for Surfer output report
wksSurfer.Columns("D:E").Clear
wksSurfer.Cells(1, 4) = "SURFER OUTPUT REPORT"
wksSurfer.Cells(3, 4) = "Grid Geometry"
wksSurfer.Cells(4, 4) = "X min."
wksSurfer.Cells(5, 4) = "X max."
wksSurfer.Cells(6, 4) = "Cell Size (x)"

wksSurfer.Cells(7, 4) = "Y min."
wksSurfer.Cells(8, 4) = "Y max."
wksSurfer.Cells(9, 4) = "Cell Size (y)"

wksSurfer.Cells(11, 4) = "Interpolation Method"
wksSurfer.Cells(12, 4) = "Blanking Value"
wksSurfer.Cells(13, 4) = "Contour Level"

wksSurfer.Cells(15, 4) = ".GRD file (Surfer)"

wksSurfer.Cells(17, 4) = ".SHP file"
wksSurfer.Cells(18, 4) = ".DXF Contour file"

Application.StatusBar = "Opening Surfer..."

'Opens data file in worksheet
Set Wks = SurferApp.Documents.Open(infile1)

'Prompt user to confirm max/min x-dimensions of grid
mycheck = 7
x_spacing = x_default
x_buffer = x_default * 2
x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
x_diffGRD = x_maxGRD - x_minGRD

Do Until mycheck = 6
    x_spacing = Val(InputBox("Default grid dimensions (x-direction): " & x_default & vbLf _
            & "Min. X = " & Round(wksSurfer.Cells(4, 1), 2) & vbLf _
            & "Max. X = " & Round(wksSurfer.Cells(3, 1), 2) & vbLf & vbLf _
            & "Grid Min. X = " & x_minGRD & vbLf _
            & "Grid Max. X = " & x_maxGRD, _
            "Size of grid cells (x-direction)", x_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    x_buffer = x_spacing * 2
    x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
    x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
    x_diffGRD = x_maxGRD - x_minGRD
    
    mycheck = MsgBox("Range of point data (x-direction)" & vbLf _
            & "Min. X (actual)= " & Round(wksSurfer.Cells(4, 1), 1) & vbLf _
            & "Max. X (actual)= " & Round(wksSurfer.Cells(3, 1), 1) & vbLf & vbLf _
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
y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
y_diffGRD = y_maxGRD - y_minGRD

Do Until mycheck = 6
    y_spacing = Val(InputBox("Default grid dimensions (y-direction): " & y_default & vbLf _
            & "Min. Y = " & Round(wksSurfer.Cells(6, 1), 2) & vbLf _
            & "Max. Y = " & Round(wksSurfer.Cells(5, 1), 2) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD, _
            "Size of grid cells (y-direction)", y_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    y_buffer = y_spacing * 2
    y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
    y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
    y_diffGRD = y_maxGRD - y_minGRD
    
    mycheck = MsgBox("Range of point data (y-direction)" & vbLf _
            & "Min. Y (actual)= " & Round(wksSurfer.Cells(6, 1), 1) & vbLf _
            & "Max. Y (actual)= " & Round(wksSurfer.Cells(5, 1), 1) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD & vbLf _
            & "Grid cell size (y-direction) = " & y_spacing & vbLf _
            & "Number of rows = " & y_diffGRD / y_spacing & vbLf _
            , vbYesNoCancel, "Confirm grid dimensions (y-direction)")
    If mycheck = 2 Then Exit Sub
Loop

'write grid geometry
wksSurfer.Cells(4, 5) = x_minGRD
wksSurfer.Cells(5, 5) = x_maxGRD
wksSurfer.Cells(6, 5) = x_spacing

wksSurfer.Cells(7, 5) = y_minGRD
wksSurfer.Cells(8, 5) = y_maxGRD
wksSurfer.Cells(9, 5) = y_spacing

jcols = (x_diffGRD / x_spacing) + 1
jrows = (y_diffGRD / y_spacing) + 1

'Assign gridding algorithm variable
gridAlgorithm = wksSurfer.Cells(14, 1)
If gridAlgorithm = 2 Then wksSurfer.Cells(11, 5) = "Kriging"
If gridAlgorithm = 9 Then
    wksSurfer.Cells(11, 5) = "Triangulation with Lin. Interp."
    blnFilename = strDirOut & rootname & ".bln"
End If

'Assign blanking value variable
If wksSurfer.Cells(16, 1) = "" Then
    gridBlankVal = 1.70141E+38  'Default Surfer blanking value
Else
    gridBlankVal = Val(wksSurfer.Cells(16, 1))
    If WorksheetFunction.IsNumber(gridBlankVal) = False Then
        Application.StatusBar = "Invalid Blank Value"
        temp = MsgBox("Non-numeric blank value", vbOKOnly, "ERROR")
        Exit Sub
    End If
End If

wksSurfer.Cells(12, 5) = gridBlankVal

Application.StatusBar = "Creating Surfer Grid..."
Set srfGrid = SurferApp.NewGrid

'Create Surfer .GRD file. Used for contouring
If gridAlgorithm <> 9 Then
    srfGrid = SurferApp.GridData2(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
            xmin:=x_minGRD, xmax:=x_maxGRD, _
            ymin:=y_minGRD, ymax:=y_maxGRD, _
            numCols:=jcols, NumRows:=jrows, _
            Algorithm:=gridAlgorithm, _
            outGrid:=outfile1)
Else
    srfGrid = SurferApp.GridData2(DataFile:=infile1, xcol:=3, ycol:=4, zcol:=6, _
            xmin:=x_minGRD, xmax:=x_maxGRD, _
            ymin:=y_minGRD, ymax:=y_maxGRD, _
            numCols:=jcols, NumRows:=jrows, _
            Algorithm:=gridAlgorithm, _
            TriangleFileName:=blnFilename, _
            outGrid:=outfile1)
End If
         
'Change default Blank value
If gridBlankVal <> 1.70141E+38 Then
    Set BlankSrfGrid = SurferApp.NewGrid
    myTempVar = BlankSrfGrid.LoadFile(Filename:=outfile1, HeaderOnly:=False)
    BlankSrfGrid.BlankValue = gridBlankVal
    myTempVar = BlankSrfGrid.SaveFile(Filename:=outfile1, Format:=3)
End If
         
wksSurfer.Cells(15, 5) = outfile1   'Surfer .GRD filepath
    
'Create X Y Z .dat file of grid nodes
srfgrid_xyz = SurferApp.GridConvert2(inGrid:=outfile1, outGrid:=outfile4, _
        OutFmt:=4, _
        OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=8")
    
'Convert grid_xyz.dat file to csv with header row
Application.StatusBar = "Convert .DAT file to .csv..."
Call dat2csv(outfile4)

wksSurfer.Cells(19, 4) = ".GRD file (csv)"
wksSurfer.Cells(19, 5) = Replace(outfile4, ".dat", ".csv")

Wks.Close
Application.StatusBar = "Done."
End Sub
Sub GridDataSrf13(filetyp As String, rootname As String, strDirOut As String, delim As String)

'Create Surfer grid file
'This code works for Surfer 13 or later

'Open Surfer
Dim SurferApp As Object
Dim outfile4 As String
Set wksSurfer = Sheets("SURFER")

Set SurferApp = CreateObject("Surfer.Application")

wksSurfer.Activate

'Surfer Variables
infile1 = strDirOut & rootname & filetyp                '.csv filepath
outfile1 = strDirOut & rootname & ".grd"                'name of output file (.grd)
outfile2 = strDirOut & rootname & ".shp"                'name of output file (.shp)
outfile3 = strDirOut & rootname & ".dxf"                'name of output file (.dxf)
outfile4 = strDirOut & rootname & "_Grid_XYZ" & ".dat"  'name of output file (.dat)

x_default = Val(wksSurfer.Cells(11, 1))                 'initial grid size, x-axis
y_default = Val(wksSurfer.Cells(12, 1))                 'initial grid size, y-axis

'Headers for Surfer output report
wksSurfer.Columns("D:E").Clear
wksSurfer.Cells(1, 4) = "SURFER OUTPUT REPORT"
wksSurfer.Cells(3, 4) = "Grid Geometry"
wksSurfer.Cells(4, 4) = "X min."
wksSurfer.Cells(5, 4) = "X max."
wksSurfer.Cells(6, 4) = "Cell Size (x)"

wksSurfer.Cells(7, 4) = "Y min."
wksSurfer.Cells(8, 4) = "Y max."
wksSurfer.Cells(9, 4) = "Cell Size (y)"

wksSurfer.Cells(11, 4) = "Interpolation Method"
wksSurfer.Cells(12, 4) = "Blanking Value"
wksSurfer.Cells(13, 4) = "Contour Level"

wksSurfer.Cells(15, 4) = ".GRD file (Surfer)"

wksSurfer.Cells(17, 4) = ".SHP file"
wksSurfer.Cells(18, 4) = ".DXF Contour file"

Application.StatusBar = "Opening Surfer..."

'Opens data file in worksheet
Set Wks = SurferApp.Documents.Open(infile1)

'Prompt user to confirm max/min x-dimensions of grid
mycheck = 7
x_spacing = x_default
x_buffer = x_default * 2
x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
x_diffGRD = x_maxGRD - x_minGRD

Do Until mycheck = 6
    x_spacing = Val(InputBox("Default grid dimensions (x-direction): " & x_default & vbLf _
            & "Min. X = " & Round(wksSurfer.Cells(4, 1), 2) & vbLf _
            & "Max. X = " & Round(wksSurfer.Cells(3, 1), 2) & vbLf & vbLf _
            & "Grid Min. X = " & x_minGRD & vbLf _
            & "Grid Max. X = " & x_maxGRD, _
            "Size of grid cells (x-direction)", x_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    x_buffer = x_spacing * 2
    x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
    x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
    x_diffGRD = x_maxGRD - x_minGRD
    
    mycheck = MsgBox("Range of point data (x-direction)" & vbLf _
            & "Min. X (actual)= " & Round(wksSurfer.Cells(4, 1), 1) & vbLf _
            & "Max. X (actual)= " & Round(wksSurfer.Cells(3, 1), 1) & vbLf & vbLf _
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
y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
y_diffGRD = y_maxGRD - y_minGRD

Do Until mycheck = 6
    y_spacing = Val(InputBox("Default grid dimensions (y-direction): " & y_default & vbLf _
            & "Min. Y = " & Round(wksSurfer.Cells(6, 1), 2) & vbLf _
            & "Max. Y = " & Round(wksSurfer.Cells(5, 1), 2) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD, _
            "Size of grid cells (y-direction)", y_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    y_buffer = y_spacing * 2
    y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
    y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
    y_diffGRD = y_maxGRD - y_minGRD
    
    mycheck = MsgBox("Range of point data (y-direction)" & vbLf _
            & "Min. Y (actual)= " & Round(wksSurfer.Cells(6, 1), 1) & vbLf _
            & "Max. Y (actual)= " & Round(wksSurfer.Cells(5, 1), 1) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD & vbLf _
            & "Grid cell size (y-direction) = " & y_spacing & vbLf _
            & "Number of rows = " & y_diffGRD / y_spacing & vbLf _
            , vbYesNoCancel, "Confirm grid dimensions (y-direction)")
    If mycheck = 2 Then Exit Sub
Loop

'write grid geometry
wksSurfer.Cells(4, 5) = x_minGRD
wksSurfer.Cells(5, 5) = x_maxGRD
wksSurfer.Cells(6, 5) = x_spacing

wksSurfer.Cells(7, 5) = y_minGRD
wksSurfer.Cells(8, 5) = y_maxGRD
wksSurfer.Cells(9, 5) = y_spacing

jcols = (x_diffGRD / x_spacing) + 1
jrows = (y_diffGRD / y_spacing) + 1

'Assign Gridding Algorithm variable
gridAlgorithm = wksSurfer.Cells(14, 1)
If gridAlgorithm = 2 Then wksSurfer.Cells(11, 5) = "Kriging"
If gridAlgorithm = 9 Then
    wksSurfer.Cells(11, 5) = "Triangulation with Lin. Interp."
    blnFilename = strDirOut & rootname & ".bln"
End If

'Assign Blanking value variable
If wksSurfer.Cells(16, 1) = "" Then
    gridBlankVal = 1.70141E+38  'Default Surfer blanking value
Else
    gridBlankVal = Val(wksSurfer.Cells(16, 1))
    If WorksheetFunction.IsNumber(gridBlankVal) = False Then
        Application.StatusBar = "Invalid Blank Value"
        temp = MsgBox("Non-numeric blank value", vbOKOnly, "ERROR")
        Exit Sub
    End If
End If
wksSurfer.Cells(12, 5) = gridBlankVal

'Prompt user for Convex Hull option
HullCheck = MsgBox("Blank grid values outside convex hull of data?", vbQuestion + vbYesNo + vbDefaultButton1, "EXTENT OF GRID")

If HullCheck = vbYes Then
    hullFlag = 1
Else
     hullFlag = 0
End If

Application.StatusBar = "Creating Surfer Grid..."
Set srfGrid = SurferApp.NewGrid

'Create Surfer .GRD file. Used for contouring
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
            TriangleFileName:=blnFilename, _
            BlankOutsideHull:=hullFlag, _
            outGrid:=outfile1)
End If
  
'Change default Blank value
If gridBlankVal <> 1.70141E+38 Then
    Set BlankSrfGrid = SurferApp.NewGrid
    myTempVar = BlankSrfGrid.LoadFile(Filename:=outfile1, HeaderOnly:=False)
    BlankSrfGrid.BlankValue = gridBlankVal
    myTempVar = BlankSrfGrid.SaveFile(Filename:=outfile1, Format:=3)
End If
  
wksSurfer.Cells(15, 5) = outfile1   'Surfer .GRD filepath
    
'Create X Y Z .dat file of grid nodes
srfgrid_xyz = SurferApp.GridConvert2(inGrid:=outfile1, outGrid:=outfile4, _
        OutFmt:=4, _
        OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=8")
    
'Convert grid_xyz.dat file to csv with header row
Application.StatusBar = "Convert .DAT file to .csv..."
Call dat2csv(outfile4)

wksSurfer.Cells(19, 4) = ".GRD file (csv)"
wksSurfer.Cells(19, 5) = Replace(outfile4, ".dat", ".csv")

Wks.Close
Application.StatusBar = "Done."
End Sub
Sub srfGrdResiduals(filetyp As String, rootname As String, strDirOut As String, delim As String, colCount As Integer)
    
'Append residuals to .CSV file
'This code only works for Surfer 12 or earlier
Dim SurferApp As Object
Set SurferApp = CreateObject("Surfer.Application")

'Surfer Variables
infile1 = strDirOut & rootname & ".grd"             'filepath to .GRD file
outfile1 = strDirOut & rootname & filetyp           'name of output file (.csv with residuals appended)
appendcol = colCount + 1                            'Column number to write data to

Set Wks = SurferApp.GridResiduals2(inGrid:=infile1, _
    DataFile:=outfile1, _
    xcol:=3, ycol:=4, zcol:=6, ResidCol:=appendcol)

myTempVar = Wks.SaveAs(Filename:=outfile1)
Wks.Close

End Sub
Sub srfGrdResiduals2(filetyp As String, rootname As String, irootname As String, strDirOut As String, delim As String, colCount As Integer)
    
'Append residuals to .CSV file
'This code only works for Surfer 12 or earlier
Dim SurferApp As Object
Set SurferApp = CreateObject("Surfer.Application")

'Surfer Variables
infile1 = strDirOut & irootname & ".grd"             'filepath to .GRD file
outfile1 = strDirOut & rootname & filetyp           'name of output file (.csv with residuals appended)
appendcol = colCount + 1                            'Column number to write data to

Set Wks = SurferApp.GridResiduals2(inGrid:=infile1, _
    DataFile:=outfile1, _
    xcol:=3, ycol:=4, zcol:=6, ResidCol:=appendcol)

myTempVar = Wks.SaveAs(Filename:=outfile1)
Wks.Close

End Sub

Sub Ia_GridComparison()
'Compares 8 common gridding methods (interpolations).
'Macro generates contour maps with posted residuals in Surfer.
'Contour map locations assume Surfer layout is landscape with Metric (cm) units

' v1.1 SWM
    'Changed irow dimention to Long from Integer to accomodate more data points

'Variable declaration
Dim irow As Long
Dim colCount As Integer
Dim fs, f
Dim filetyp As String
Dim rootname As String
Dim delim As String
Dim strDirOut As String

Const ForReading = 1, ForWriting = 2, ForAppending = 3

Set wksData = Sheets("INPUT")
Set wksSurfer = Sheets("SURFER")
Set wksScript = Sheets("Script")

wksData.Activate

rootname = InputBox("Enter rootname of input file: ", "ROOTNAME FOR .GRD FILES", wksData.Cells(2, 1))
filetyp = ".csv"
delim = ","

strDirOut = Application.ActiveWorkbook.Path
ChDir strDirOut
'Output folder assignment
'Prompt user to specify a folder. Differs from other codes so that the primary working directory does not get
'Crowded by the 'test' grids generated for the comparative contour plots
Dim diaFolder As FileDialog
Dim selected As Boolean
Set diaFolder = Application.FileDialog(msoFileDialogFolderPicker)
diaFolder.AllowMultiSelect = False
diaFolder.Title = "Select folder to save .grd files to..."

selected = diaFolder.Show

strDirOut = diaFolder.SelectedItems(1) & "\"

x_default = Val(wksSurfer.Cells(11, 1))                 'initial grid size, x-axis
y_default = Val(wksSurfer.Cells(12, 1))                 'initial grid size, y-axis

wksScript.Cells.Clear

irow = 8        'First row of point data to check
colCount = 9    'Number of columns to write to .csv file

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
While wksData.Cells(irow, 1) <> ""
    If wksData.Cells(irow, 10) = 1 Then
        wksScript.Cells(srow, 1) = wksData.Cells(irow, 1) & delim & _
        wksData.Cells(irow, 2) & delim & _
        wksData.Cells(irow, 3) & delim & _
        wksData.Cells(irow, 4) & delim & _
        wksData.Cells(irow, 5) & delim & _
        wksData.Cells(irow, 6) & delim & _
        wksData.Cells(irow, 7) & delim & _
        wksData.Cells(irow, 8) & delim & _
        wksData.Cells(irow, 9)
        srow = srow + 1
    End If
    irow = irow + 1
Wend

fileSaveName = strDirOut & rootname & filetyp

Dim wbScript As Workbook

wksScript.Copy
Set wbScript = ActiveWorkbook

wbScript.SaveAs Filename:=fileSaveName, FileFormat:=xlTextPrinter, CreateBackup:=False
DoEvents
Application.Wait Now + TimeValue("00:00:01")
wbScript.Close SaveChanges:=False
Set wbScript = Nothing

outfile1 = fileSaveName                 'Location of .csv file
    
'Data columns for griddata2 function
xcol = 3
ycol = 4
zcol = 6

'Populate array for each interpolation type:
'Interpolation method, x start, and y top

ReDim arr_interp(9, 2)
arr_interp(1, 0) = "InverseDistance"
arr_interp(1, 1) = 1
arr_interp(1, 2) = 27.5
arr_interp(2, 0) = "Kriging"
arr_interp(2, 1) = 1
arr_interp(2, 2) = 13.75
arr_interp(3, 0) = "MinimumCurvature"
arr_interp(3, 1) = 9
arr_interp(3, 2) = 27.5
arr_interp(4, 0) = "ModifiedShepard"
arr_interp(4, 1) = 9
arr_interp(4, 2) = 13.75
arr_interp(5, 0) = "NaturalNeighbor"
arr_interp(5, 1) = 17
arr_interp(5, 2) = 27.5
arr_interp(6, 0) = "NearestNeighbor"
arr_interp(6, 1) = 17
arr_interp(6, 2) = 13.75

arr_interp(7, 0) = Empty

arr_interp(8, 0) = "RadialBasisFunction"
arr_interp(8, 1) = 25
arr_interp(8, 2) = 27.5
arr_interp(9, 0) = "Tri.Lin.Interp."
arr_interp(9, 1) = 25
arr_interp(9, 2) = 13.75

'Prompt user to confirm max/min x-dimensions of grid
mycheck = 7
x_spacing = x_default
x_buffer = x_default * 2
x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
x_diffGRD = x_maxGRD - x_minGRD

Do Until mycheck = 6
    x_spacing = Val(InputBox("Default grid dimensions (x-direction): " & x_default & vbLf _
            & "Min. X = " & Round(wksSurfer.Cells(4, 1), 2) & vbLf _
            & "Max. X = " & Round(wksSurfer.Cells(3, 1), 2) & vbLf & vbLf _
            & "Grid Min. X = " & x_minGRD & vbLf _
            & "Grid Max. X = " & x_maxGRD, _
            "Size of grid cells (x-direction)", x_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    x_buffer = x_spacing * 2
    x_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(4, 1), x_spacing) - x_buffer
    x_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(3, 1), x_spacing) + x_buffer
    x_diffGRD = x_maxGRD - x_minGRD
    
    mycheck = MsgBox("Range of point data (x-direction)" & vbLf _
            & "Min. X (actual)= " & Round(wksSurfer.Cells(4, 1), 1) & vbLf _
            & "Max. X (actual)= " & Round(wksSurfer.Cells(3, 1), 1) & vbLf & vbLf _
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
y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
y_diffGRD = y_maxGRD - y_minGRD

Do Until mycheck = 6
    y_spacing = Val(InputBox("Default grid dimensions (y-direction): " & y_default & vbLf _
            & "Min. Y = " & Round(wksSurfer.Cells(6, 1), 2) & vbLf _
            & "Max. Y = " & Round(wksSurfer.Cells(5, 1), 2) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD, _
            "Size of grid cells (y-direction)", y_spacing))
            
    're-calculate grid dimensions/extents based on updated x_spacing
    y_buffer = y_spacing * 2
    y_minGRD = WorksheetFunction.Floor(wksSurfer.Cells(6, 1), y_spacing) - y_buffer
    y_maxGRD = WorksheetFunction.Ceiling(wksSurfer.Cells(5, 1), y_spacing) + y_buffer
    y_diffGRD = y_maxGRD - y_minGRD
    
    mycheck = MsgBox("Range of point data (y-direction)" & vbLf _
            & "Min. Y (actual)= " & Round(wksSurfer.Cells(6, 1), 1) & vbLf _
            & "Max. Y (actual)= " & Round(wksSurfer.Cells(5, 1), 1) & vbLf & vbLf _
            & "Grid Min. Y = " & y_minGRD & vbLf _
            & "Grid Max. Y = " & y_maxGRD & vbLf _
            & "Grid cell size (y-direction) = " & y_spacing & vbLf _
            & "Number of rows = " & y_diffGRD / y_spacing & vbLf _
            , vbYesNoCancel, "Confirm grid dimensions (y-direction)")
    If mycheck = 2 Then Exit Sub
Loop

jcols = (x_diffGRD / x_spacing) + 1
jrows = (y_diffGRD / y_spacing) + 1

Dim SurferApp As Object
Set SurferApp = CreateObject("Surfer.Application")
SurferApp.Visible = True

Dim Doc As Object
Set Doc = SurferApp.Documents.Add

'Dim Map As Object
ylength = 12

surfCheck = MsgBox("Are you running Surfer V12 or older?", vbQuestion + vbYesNo + vbDefaultButton1, "CONFIRM SURFER VERSION")
If surfCheck = vbYes Then
    'Surfer 12 or earlier
    Dim irootname As String
    numCols = colCount - 1
    
    For i = 1 To 9
        If i = 7 Then GoTo skipper
        myOutfile = Replace(outfile1, ".csv", "_" & arr_interp(i, 0) & ".grd")
        
        srfGrid = SurferApp.GridData2(DataFile:=outfile1, xcol:=xcol, ycol:=ycol, zcol:=zcol, _
            xmin:=x_minGRD, xmax:=x_maxGRD, _
            ymin:=y_minGRD, ymax:=y_maxGRD, _
            numCols:=jcols, NumRows:=jrows, _
            Algorithm:=i, outGrid:=myOutfile)
                   
        'write residuals
        colCount = numCols + i
        irootname = rootname & "_" & arr_interp(i, 0)
        Call srfGrdResiduals2(filetyp, rootname, irootname, strDirOut, delim, colCount)
        
        'Create Contour Map
        Set MapFrame1 = Doc.Shapes.AddContourMap(GridFileName:=myOutfile)
        
        'Create Post Map of residuals
        Set MapFrame2 = Doc.Shapes.AddPostMap2(DataFileName:=outfile1, xcol:=xcol, ycol:=ycol, Labcol:=numCols + i + 1)
        
        'Format Post map labels
        Set Postmap = MapFrame2.overlays(1)
        
            'Round residual label to 1 significant figure
            Postmap.LabelFormat.NumDigits = 1
            
            'Adjust font format for labels
            Set FontFormatPM = Postmap.LabelFont
            FontFormatPM.Bold = True
            FontFormatPM.Size = 10
            FontFormatPM.ForeColorRGBA.Color = RGB(255, 0, 0)
            
            'Change symbol type to solid circle
            Set SymbolFormatPM = Postmap.Symbol
            SymbolFormatPM.Index = 12
            SymbolFormatPM.FillColorRGBA.Color = RGB(255, 0, 0)
            SymbolFormatPM.LineColorRGBA.Color = RGB(255, 0, 0)
            SymbolFormatPM.Size = 0.15
       
       'Select and overlays the map objects
        MapFrame1.selected = True
        MapFrame2.selected = True
        Set NewMapFrame = Doc.Selection.OverlayMaps
        NewMapFrame.Name = arr_interp(i, 0)
        
        NewMapFrame.ylength = ylength
        NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
        If NewMapFrame.Width < 8.5 Then
            NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
        Else
            NewMapFrame.xLength = 8.5
        End If
        NewMapFrame.Axes("Bottom Axis").Title = arr_interp(i, 0)
        NewMapFrame.Axes("Bottom Axis").TitleFont.ForeColorRGBA.Color = srfColorRed
        NewMapFrame.Left = arr_interp(i, 1)
        NewMapFrame.Top = arr_interp(i, 2)
        NewMapFrame.selected = False

skipper:
    Next i

Else
    'Surfer 13 or later
    'Prompt user for Convex Hull option
    HullCheck = MsgBox("Blank grid values outside convex hull of data?", vbQuestion + vbYesNo + vbDefaultButton1, "EXTENT OF GRID")
    If HullCheck = vbYes Then
        hullFlag = 1
    Else
         hullFlag = 0
    End If
    
    For i = 1 To 9
        If i = 7 Then GoTo skipper13
        myOutfile = Replace(outfile1, ".csv", "_" & arr_interp(i, 0) & ".grd")
        Debug.Print (myOutfile)
        srfGrid = SurferApp.GridData4(DataFile:=outfile1, xcol:=xcol, ycol:=ycol, zcol:=zcol, _
            xmin:=x_minGRD, xmax:=x_maxGRD, _
            ymin:=y_minGRD, ymax:=y_maxGRD, _
            numCols:=jcols, NumRows:=jrows, _
            Algorithm:=i, _
            BlankOutsideHull:=hullFlag, _
            outGrid:=myOutfile)
        
        'write residuals
        colCount = numCols + i
        irootname = rootname & "_" & arr_interp(i, 0)
        Call srfGrdResiduals2(filetyp, rootname, irootname, strDirOut, delim, colCount)
        
        'Creat Contour Map
        Set MapFrame1 = Doc.Shapes.AddContourMap(GridFileName:=myOutfile)
        
        'Create Post Map of residuals
        Set MapFrame2 = Doc.Shapes.AddPostMap2(DataFileName:=outfile1, xcol:=xcol, ycol:=ycol, Labcol:=numCols + i + 1)
        
        'Format Post map labels
        Set Postmap = MapFrame2.overlays(1)
            'Round residual label to 1 significant figure
            Postmap.LabelFormat.NumDigits = 1
            
            'Adjust font format for labels
            Set FontFormatPM = Postmap.LabelFont
            FontFormatPM.Bold = True
            FontFormatPM.Size = 10
            FontFormatPM.ForeColorRGBA.Color = RGB(255, 0, 0)
            
            'Change symbol type to solid circle
            Set SymbolFormatPM = Postmap.Symbol
            SymbolFormatPM.Index = 12
            SymbolFormatPM.FillColorRGBA.Color = RGB(255, 0, 0)
            SymbolFormatPM.LineColorRGBA.Color = RGB(255, 0, 0)
            SymbolFormatPM.Size = 0.15
       
       'Select and overlays the map objects
        MapFrame1.selected = True
        MapFrame2.selected = True
        Set NewMapFrame = Doc.Selection.OverlayMaps
        NewMapFrame.Name = arr_interp(i, 0)
        
        NewMapFrame.ylength = ylength
        NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
        If NewMapFrame.Width < 8.5 Then
            NewMapFrame.xMapPerPU = NewMapFrame.yMapPerPU
        Else
            NewMapFrame.xLength = 8.5
        End If
        NewMapFrame.Axes("Bottom Axis").Title = arr_interp(i, 0)
        NewMapFrame.Axes("Bottom Axis").TitleFont.ForeColorRGBA.Color = srfColorRed
        NewMapFrame.Left = arr_interp(i, 1)
        NewMapFrame.Top = arr_interp(i, 2)
        NewMapFrame.selected = False
skipper13:
    Next i

End If

End Sub

Sub Ib_BlankingFileFromDXF()
'Converts .dxf polygons to Blanking Files (.BLN) used by Surfer to blank grids.

'Set wksData = Sheets("Input")
Set wksScript = Sheets("Script")
Set wksSurface = Sheets("SURFACE")

wksSurface.Activate

'initialize variables needed for the parse_string_by_comma_v2 subroutine
Dim fullstring As String
Dim arrLong() As Long
Dim arrDbl() As Double
Dim arrStr() As String
Dim strType As String

delim = ","
strType = "string"

'Write nodes in BLN file to array
myFile = Application.GetOpenFilename("DXF Polygon File *.dxf, *.dxf", , "Select " & ".dxf File", , True)

For ifile = 1 To UBound(myFile)
    Const ForReading = 1, ForWriting = 2, ForAppending = 3
    Dim fs
    
    Application.StatusBar = "Reading/writing dxf file points..."
    
    wksSurface.Columns.Range("G:M").Clear
    wksSurface.Cells(1, 7) = "DXF Polygon vertices for Blanking file"
    wksSurface.Cells(1, 7).Font.Bold = True
    wksSurface.Cells(3, 7) = "X"
    wksSurface.Cells(3, 8) = "Y"
    wksSurface.Cells(3, 9) = "Z"
    wksSurface.Cells(3, 10) = "LAYER"

    irow = 4
    filenumber = FreeFile
    
    'Establish the filepath, filename
    slash = ""
    filepath = myFile(ifile) 'filepath
    temp = Len(filepath)
    i = 0
    
    While slash <> "\"
        slash = Mid(filepath, temp - i, 1)
        i = i + 1
    Wend
    file_name = Replace(Mid(filepath, temp - i + 2, temp - i + 1), ".dxf", "")
    file_folder = Mid(filepath, 1, temp - i + 1)
    
    'Prompt user to blank inside/outside polygon
    Blanktype = Val(InputBox("Blanking polygon: " & file_name & ".dxf" & vbLf & vbLf & _
                    "Enter 1 to blank grid INSIDE polygon" & vbLf & vbLf & _
                    "Enter 0 to blank grid OUTSIDE polygon" & vbLf, _
                    "BLANK INSIDE/OUTSIDE POLYGON", 1))
    If Blanktype <> 1 And Blanktype <> 0 Then
        temp = MsgBox("Invalid Blank Type assignment", vbOKOnly, "ERROR")
        Application.StatusBar = "Ending Macro"
        Exit Sub
    End If
       
    icount = 0
    
    Open myFile(ifile) For Input As #filenumber
    FileLength = LOF(filenumber)
    
    Do While Not EOF(filenumber)
        Line Input #filenumber, fullstring
        If fullstring = "POLYLINE" Then
            'Extract vertex data
            x1 = ""
            y1 = ""
            z1 = ""
            
            'Extract Layer Name and copy to Targets worksheet
            Line Input #filenumber, fullstring '5
            Line Input #filenumber, fullstring
            Line Input #filenumber, fullstring '8
            Line Input #filenumber, fullstring 'Layer name
            myLayer = fullstring
            
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
                z1 = Val(fullstring) 'Not used
                
                wksSurface.Cells(irow, 7) = Val(x1)
                wksSurface.Cells(irow, 8) = Val(y1)
                wksSurface.Cells(irow, 9) = Val(z1)
                wksSurface.Cells(irow, 10) = myLayer
                irow = irow + 1
            Wend
NextLayer:
        End If
    Loop
        
endoffile:
    Close #filenumber
    
   'Write script file
    Application.StatusBar = "Creating .bln blanking file"
    
    wksScript.Activate
    Columns("A:A").Select
    Selection.ClearContents
    wksSurface.Activate
    
    irow = 4
    trow = 2
    icount = 0
    x1 = wksSurface.Cells(irow, 7)
    y1 = wksSurface.Cells(irow, 8)
    
    While wksSurface.Cells(irow, 7) <> ""
        x = wksSurface.Cells(irow, 7)
        y = wksSurface.Cells(irow, 8)
        wksScript.Cells(trow, 1) = x & delim & y & delim & 0
        
        irow = irow + 1
        trow = trow + 1
        icount = icount + 1
    Wend
    wksScript.Cells(1, 1) = icount + 1 & delim & Blanktype & " " & Chr(34) & "0.000000" & Chr(34)       'Repeats initial point at end of .BLN file (closes polygon)"
    wksScript.Cells(trow, 1) = x1 & delim & y1 & delim & 0                  'Repeats initial point at end of .BLN file (closes polygon)
        
    fileSaveName = file_folder & file_name & ".bln"
    wksScript.Copy
    
    If Not fileSaveName = False Then
     ActiveWorkbook.SaveAs Filename:=fileSaveName, _
            FileFormat:=xlTextPrinter, CreateBackup:=False
    End If
    
    ActiveWorkbook.Close savechanges:=False 'close the script file
    
    wksSurface.Cells(2, 7) = fileSaveName
Next ifile

End Sub

Sub Ic_BlankSrfGrid()
'Macro blanks an existing SRF grid

Application.StatusBar = "Blanking Surfer .GRD File..."

'Variables needed for srfBlankFile function
Dim grid1 As String
Dim grid2 As String
Dim bFile As String

filenumber = FreeFile
myGrid = Application.GetOpenFilename("Surfer Grid File *.grd, *.grd", , "Select " & "Surfer Grid File to Blank", , True)
grid1 = myGrid(filenumber) 'filepath
grid2 = grid1

Close #filenumber

filenumber = FreeFile
mybFile = Application.GetOpenFilename("Surfer Blanking File *.bln, *.bln", , "Select " & "Surfer Blanking File", , True)
bFile = mybFile(filenumber) 'filepath

Call srfBlankFile(grid1, bFile, grid2)

Application.StatusBar = "Surfer Grid Successfully Blanked"

End Sub

Sub Id_AppendResiduals()
'Append residuals to .csv file

'USER INPUT
'Column assignment for x,y,z data
xData = 3
yData = 4
zData = 6
appendcol = 10

'Prompt user for grid file
filenumber = FreeFile
myGrid = Application.GetOpenFilename("Surfer Grid File *.grd, *.grd", , "Select " & "Surfer Grid File to Blank", , True)
grid1 = myGrid(filenumber) 'filepath
Close #filenumber

'Prompt user for .csv file
filenumber = FreeFile
myFile = Application.GetOpenFilename("csv file *.csv, *.csv", , "Select " & ".CSV file with point data", , True)
outfile1 = myFile(filenumber) ' filepath
Close #filenumber

Dim SurferApp As Object
Set SurferApp = CreateObject("Surfer.Application")

Set Wks = SurferApp.GridResiduals2(inGrid:=grid1, _
    DataFile:=outfile1, _
    xcol:=xData, ycol:=yData, zcol:=zData, ResidCol:=appendcol)

myTempVar = Wks.SaveAs(Filename:=outfile1)
Wks.Close

Application.StatusBar = "Residuals calculated and appended to .csv file"

End Sub
