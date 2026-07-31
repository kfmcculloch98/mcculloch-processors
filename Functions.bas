Attribute VB_Name = "Functions"
Public Function extractoverlappingnodes(SurferApp As Object, strDirOut As String, filetyp As String, GridA As String, _
        GridB As String, arr_GridA() As Double, arr_GridB() As Double, numlinesA As Double, numlinesB As Double)
'Extracts overlapping nodes between two grid files

'initialize variables needed for the parse_string_by_blanks_v2 subroutine
Dim fullstring As String
Dim arrLong() As Long
Dim arrDbl() As Double
Dim arrStr() As String
Dim strType As String

strType = "string"
delim = " "

Set wksSurfer = Sheets("SURFER")
Set wksScript = Sheets("Script")

'Initialize Surfer as an object
'Dim SurferApp As Object
'Set SurferApp = CreateObject("Surfer.Application")

overlapFlag = False

'Grids A and B do not perfectly overlap. Extract grid node data and manually execute grid math
'READ/WRITE GRID A

outfileA_xyz = strDirOut & "GridA" & filetyp
srfGridA_xyz = SurferApp.GridConvert2(inGrid:=GridA, outGrid:=outfileA_xyz, _
    OutFmt:=4, _
    OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=4")

'Read number of lines in text file, redim arrays
Set fso = CreateObject("Scripting.FileSystemObject")
Set thefile = fso.OpenTextFile(outfileA_xyz, 8, True)
numlinesA = thefile.Line - 1
fso = Empty
thefile = Empty
ReDim Preserve arr_GridA(numlines, 2)
    
'Extract point data
filenumber = FreeFile
Open outfileA_xyz For Input As #filenumber

Do While Not EOF(filenumber)
    Line Input #filenumber, fullstring
    Call parse_string_by_space(fullstring, arrLong, arrDbl, arrStr, strType)
    arr_GridA(i, 0) = Val(arrStr(0))    'x
    arr_GridA(i, 1) = Val(arrStr(1))    'y
    arr_GridA(i, 2) = Val(arrStr(2))    'z
Loop

Close #filenumber

'READ/WRITE GRID B

outfileB_xyz = strDirOut & "GridB" & filetyp
srfGridB_xyz = SurferApp.GridConvert2(inGrid:=GridB, outGrid:=outfileB_xyz, _
    OutFmt:=4, _
    OutGridOptions:="ValuesPerLine=1, BlankLinePerGridRow=1, NumericFormatType=2, NumericFormatDigits=4")

'Read number of lines in text file, redim arrays
Set fso = CreateObject("Scripting.FileSystemObject")
Set thefile = fso.OpenTextFile(outfileB_xyz, 8, True)
numlinesB = thefile.Line - 1
fso = Empty
thefile = Empty
    
ReDim Preserve arr_GridB(numlines, 2)
    
'Extract point data
filenumber = FreeFile
Open outfileB_xyz For Input As #filenumber

Do While Not EOF(filenumber)
    Line Input #filenumber, fullstring
    Call parse_string_by_space(fullstring, arrLong, arrDbl, arrStr, strType)
    arr_GridB(i, 0) = Val(arrStr(0))    'x
    arr_GridB(i, 1) = Val(arrStr(1))    'y
    arr_GridB(i, 2) = Val(arrStr(2))    'z
Loop

Close #filenumber

End Function
Public Function dat2csv(outfile4 As String)
'Converts .DAT file created by surfer and
'  1. Adds header information (x,y,z)
'  2. Converts spaces to commas
'  3. deletes original .DAT file

'initialize variables needed for the parse_string_by_blanks_v2 subroutine
Dim fullstring As String
Dim arrLong() As Long
Dim arrDbl() As Double
Dim arrStr() As String
Dim strType As String

Set wksSurfer = Sheets("SURFER")
Set wksScript = Sheets("Script")

delim = ","
strType = "string"

'Extract data from input file
filenumber = FreeFile
Open outfile4 For Input As #filenumber

FileLength = LOF(filenumber)

wksScript.Cells.Clear
wksScript.Cells(1, 1) = "X,Y,Z"     'Header

i = 1
Do While Not EOF(filenumber)
    Line Input #filenumber, fullstring
    Call parse_string_by_space(fullstring, arrLong, arrDbl, arrStr, strType)
    wksScript.Cells(i + 1, 1) = "'" & Val(arrStr(0)) & delim & Val(arrStr(1)) & delim & Val(arrStr(2))
    'Debug.Print (Val(arrStr(0)) & delim & Val(arrStr(1)) & delim & Val(arrStr(2)))
    i = i + 1
Loop

Close #filenumber

fileSaveName = Replace(outfile4, ".dat", ".csv")
wksScript.Copy


If Not fileSaveName = False Then
 ActiveWorkbook.SaveAs Filename:=fileSaveName, _
        FileFormat:=xlTextPrinter, CreateBackup:=False
End If

ActiveWorkbook.Close savechanges:=False 'close the script file

'Delete space deliminated space file
Kill (outfile4)

End Function
Public Function parse_string_by_space(fullstring As String, arrLong() As Long, arrDbl() As Double, _
                            arrStr() As String, strType As String)
'parses array by space, treating multiple blanks as one delimiter
    arrStr = Split(fullstring, " ") 'space deliminator
    LastNonEmpty = -1
    bDebug = False
    
    'Step through string character by character
    For i = 0 To UBound(arrStr)
        If arrStr(i) <> "" Then
            LastNonEmpty = LastNonEmpty + 1
            arrStr(LastNonEmpty) = arrStr(i)
            If blnDebug Then Debug.Print arrStr(LastNonEmpty)
        End If
    Next
    
    ReDim Preserve arrStr(LastNonEmpty)
    ReDim arrLong(LastNonEmpty)
    
    If strType = "Long" Or strType = "long" Then
        For i = 0 To LastNonEmpty
            arrLong(i) = CInt(arrStr(i))
        Next
    ElseIf strType = "Real" Or strType = "real" Then
        For i = 0 To LastNonEmpty
            arrDbl(i) = CDbl(arrStr(i))
        Next
    ElseIf strType <> "String" And strType <> "string" Then
        MsgBox "I'm sorry, type " & strType & " not recognized.  Program stopping."
        Stop
    End If
 
End Function

Public Function parse_string_by_comma(fullstring As String, arrLong() As Long, arrDbl() As Double, _
                            arrStr() As String, strType As String)
'parses array by comma, treating multiple commas as one delimiter
    arrStr = Split(fullstring, ",") 'space deliminator
    LastNonEmpty = -1
    bDebug = False
    
    'Step through string character by character
    For i = 0 To UBound(arrStr)
        If arrStr(i) <> "" Then
            LastNonEmpty = LastNonEmpty + 1
            arrStr(LastNonEmpty) = arrStr(i)
            If blnDebug Then Debug.Print arrStr(LastNonEmpty)
        End If
    Next
    
    ReDim Preserve arrStr(LastNonEmpty)
    ReDim arrLong(LastNonEmpty)
    
    If strType = "Long" Or strType = "long" Then
        For i = 0 To LastNonEmpty
            arrLong(i) = CInt(arrStr(i))
        Next
    ElseIf strType = "Real" Or strType = "real" Then
        For i = 0 To LastNonEmpty
            arrDbl(i) = CDbl(arrStr(i))
        Next
    ElseIf strType <> "String" And strType <> "string" Then
        MsgBox "I'm sorry, type " & strType & " not recognized.  Program stopping."
        Stop
    End If
 
End Function
Public Function grid_overlap(overlap_Flag As Boolean, igrid_xMin As Double, igrid_xMax As Double, igrid_yMin As Double, igrid_yMax As Double, _
                                jgrid_xMin As Double, jgrid_xMax As Double, jgrid_yMin As Double, jgrid_yMax As Double)

'Determine if there is overlap between two rectangular grids
'Use limits of jgrid to determine if igrid is above/below, left/right of new grid
    If (igrid_xMax < jgrid_xMin) Or (igrid_xMin > jgrid_xMax) And _
         (igrid_yMax < jgrid_yMin) Or (igrid_yMin > jgrid_yMax) Then
        overlap_Flag = False
        Exit Function
    End If

End Function

Public Function GridCompatibilityCheck(SurferApp As Object, strDirOut As String, rootname_A As String, rootname_B As String, GridA As String, GridB As String)
'Checks the compatibility of two Surfer grids in preperation for Grid Math
'For grids that overlap but not perfectly, the overlapping portions of each .GRD file is extracted and saved to the working folder
'Properties of Grids A and B are written to the SURFACE worksheet

'Variables needed for extractoverlappingnodes function
'Dim strDirOut As String
Dim filetyp As String
Dim arr_GridA() As Double
Dim arr_GridB() As Double
Dim numlinesA As Double
Dim numlinesB As Double

'Variables needed for grid_overlap function
Dim overlap_Flag As Boolean
Dim igrid_xMin As Double
Dim igrid_xMax As Double
Dim igrid_yMin As Double
Dim igrid_yMax As Double
Dim jgrid_xMin As Double
Dim jgrid_xMax As Double
Dim jgrid_yMin As Double
Dim jgrid_yMax As Double

Set wksSurface = Sheets("SURFACE")

'NEED TO RESIZE GRIDS SO THEY ARE THE SAME SIZE
    'Use gridextract() to make extents of the two grids the same
    'Throws error if the row and column spacing between the two grids are not the same

Dim srfGridA As Object
Set srfGridA = SurferApp.NewGrid
filenumber = FreeFile
myGrid = Application.GetOpenFilename("Surfer Grid File *.grd, *.grd", , "Select " & "Surfer Grid File (A)", , True)

GridA = srfGridA.LoadFile(myGrid(filenumber), True)
GridA = myGrid(filenumber) 'filepath

'Establish the filename
slash = ""
temp = Len(GridA)
i = 0

While slash <> "\"
    slash = Mid(GridA, temp - i, 1)
    i = i + 1
Wend
rootname_A = Replace(Mid(GridA, temp - i + 2, temp - i + 1), ".grd", "") 'filename

xMin_A = srfGridA.xmin
xMax_A = srfGridA.xmax
xSize_A = srfGridA.xSize

yMin_A = srfGridA.ymin
yMax_A = srfGridA.ymax
ySize_A = srfGridA.ySize

zMin_A = srfGridA.zMin
zMax_A = srfGridA.zMax

Close #filenumber

Dim srfGridB As Object
Set srfGridB = SurferApp.NewGrid
filenumber = FreeFile

myGrid = Application.GetOpenFilename("Surfer Grid File *.grd, *.grd", , "Select " & "Surfer Grid File (B)", , True)
GridB = srfGridB.LoadFile(Filename:=myGrid(filenumber), HeaderOnly:=False)
GridB = myGrid(filenumber) 'filepath

'Establish the filename
slash = ""
temp = Len(GridB)
i = 0

While slash <> "\"
    slash = Mid(GridB, temp - i, 1)
    i = i + 1
Wend
rootname_B = Replace(Mid(GridB, temp - i + 2, temp - i + 1), ".grd", "") 'filename

xMin_B = srfGridB.xmin
xMax_B = srfGridB.xmax
xSize_B = srfGridB.xSize

yMin_B = srfGridB.ymin
yMax_B = srfGridB.ymax
ySize_B = srfGridB.ySize

zMin_B = srfGridB.zMin
zMax_B = srfGridB.zMax

Close #filenumber

'Headers for Surface Report
col_writeA = 10
col_writeB = 11
col_writeZ = 12

wksSurface.Columns.Range("G:M").Clear
wksSurface.Cells(1, 10) = "SURFER OUTPUT REPORT"
wksSurface.Cells(1, 10).Font.Bold = True

wksSurface.Cells(2, 10) = "GRID A"
wksSurface.Cells(2, 10).Font.Bold = True

wksSurface.Cells(2, 11) = "GRID B"
wksSurface.Cells(2, 11).Font.Bold = True

wksSurface.Cells(3, 12) = "Filename"
wksSurface.Cells(4, col_writeZ) = "Filepath"
wksSurface.Cells(5, col_writeZ) = "x Min."
wksSurface.Cells(6, col_writeZ) = "x Max."
wksSurface.Cells(7, col_writeZ) = "Cell Size (x)"
wksSurface.Cells(8, col_writeZ) = "y Min."
wksSurface.Cells(9, col_writeZ) = "Y Max."
wksSurface.Cells(10, col_writeZ) = "Cell Size (y)"
wksSurface.Cells(11, col_writeZ) = "z Min."
wksSurface.Cells(12, col_writeZ) = "z Max."

Application.StatusBar = "Evaluating grids A and B..."
'Write grid A, grid B properties
wksSurface.Cells(4, col_writeA) = GridA
wksSurface.Cells(5, col_writeA) = xMin_A
wksSurface.Cells(6, col_writeA) = xMax_A
wksSurface.Cells(7, col_writeA) = xSize_A
wksSurface.Cells(8, col_writeA) = yMin_A
wksSurface.Cells(9, col_writeA) = yMax_A
wksSurface.Cells(10, col_writeA) = ySize_A
wksSurface.Cells(11, col_writeA) = zMin_A
wksSurface.Cells(12, col_writeA) = zMax_A

wksSurface.Cells(4, col_writeB) = GridB
wksSurface.Cells(5, col_writeB) = xMin_B
wksSurface.Cells(6, col_writeB) = xMax_B
wksSurface.Cells(7, col_writeB) = xSize_B
wksSurface.Cells(8, col_writeB) = yMin_B
wksSurface.Cells(9, col_writeB) = yMax_B
wksSurface.Cells(10, col_writeB) = ySize_B
wksSurface.Cells(11, col_writeB) = zMin_B
wksSurface.Cells(12, col_writeB) = zMax_B

'Grid spacing check
If (xSize_A <> xSize_B) Or (ySize_A <> ySize_B) Then
    myDummy = MsgBox("Grid row and/or column size does not match" & vbLf & _
            "Re-grid dataset(s) so X_spacing and Y_spacing are the same.", _
            vbOKOnly, "GRIDS ARE NOT THE SAME SIZE")
    Exit Function
End If

'Evaluate max/min x,y values of two grids
gridsize_Flag = False

If xMin_A <> xMin_B Then gridsize_Flag = True
If xMax_A <> xMax_B Then gridsize_Flag = True
If yMin_A <> yMin_B Then gridsize_Flag = True
If yMax_A <> yMax_B Then gridsize_Flag = True

If gridsize_Flag = True Then
    'Establish new grid minimum/maximum values
    xMin_AB = WorksheetFunction.Max(xMin_A, xMin_B)
    xMax_AB = WorksheetFunction.Min(xMax_A, xMax_B)
    yMin_AB = WorksheetFunction.Max(yMin_A, yMin_B)
    yMax_AB = WorksheetFunction.Min(yMax_A, yMax_B)
        
    jgrid_xMin = xMin_AB
    jgrid_xMax = xMax_AB
    jgrid_yMin = yMin_AB
    jgrid_yMax = yMax_AB
    
    'Confirm Grid A overlaps with new grid
    overlap_Flag = True
    igrid_xMin = xMin_A
    igrid_xMax = xMax_A
    igrid_yMin = yMin_A
    igrid_yMax = yMax_A
    
    Call grid_overlap(overlap_Flag, igrid_xMin, igrid_xMax, igrid_yMin, igrid_yMax, _
                                jgrid_xMin, jgrid_xMax, jgrid_yMin, jgrid_yMax)
    overlapA_Flag = overlap_Flag
    
    'Confirm Grid B contains points that fall within new grid
    overlap_Flag = True
    igrid_xMin = xMin_B
    igrid_xMax = xMax_B
    igrid_yMin = yMin_B
    igrid_yMax = yMax_B
    
    Call grid_overlap(overlap_Flag, igrid_xMin, igrid_xMax, igrid_yMin, igrid_yMax, _
                                jgrid_xMin, jgrid_xMax, jgrid_yMin, jgrid_yMax)
    overlapB_Flag = overlap_Flag
    
    If overlapA_Flag = False Or overlapB_Flag = False Then
        myDummy = MsgBox("Grids A and/or B do not overlap" & vbLf, _
            vbOKOnly, "GRIDS ARE NOT THE SAME SIZE")
        Exit Function
    End If
    
    Application.StatusBar = "Extracting Grid A..."
    'Use GridExtract to create equally dimensioned grids in preperation for grid math
    outfile1a = strDirOut & rootname_A & "_extracted.grd"
    c1a = (xMin_AB - xMin_A) / xSize_A + 1
    c2a = ((xMax_A - xMin_A) / xSize_A) - (xMax_A - xMax_AB) / xSize_A
    r1a = (yMin_AB - yMin_A) / ySize_A + 1
    r2a = ((yMax_A - yMin_A) / ySize_A) - (yMax_A - yMax_AB) / ySize_A
    
    mygridExt_A = SurferApp.GridExtract(inGrid:=GridA, r1:=r1a, r2:=r2a, rFreq:=-1, _
                            c1:=c1a, c2:=c2a, cFreq:=-1, outGrid:=outfile1a)
    
    wksSurface.Cells(3, col_writeA) = rootname_A

    Application.StatusBar = "Extracting Grid B..."
    outfile1b = strDirOut & rootname_B & "_extracted.grd"
    c1a = (xMin_AB - xMin_B) / xSize_B + 1
    c2a = ((xMax_B - xMin_B) / xSize_B) - (xMax_B - xMax_AB) / xSize_B
    r1a = (yMin_AB - yMin_B) / ySize_B + 1
    r2a = ((yMax_B - yMin_B) / ySize_B) - (yMax_B - yMax_AB) / ySize_B
    
    mygridExt_B = SurferApp.GridExtract(inGrid:=GridB, r1:=r1a, r2:=r2a, rFreq:=-1, _
                            c1:=c1a, c2:=c2a, cFreq:=-1, outGrid:=outfile1b)
                            
    wksSurface.Cells(3, col_writeB) = rootname_B
    
    wksSurface.Cells(13, 10) = outfile1a
    wksSurface.Cells(13, 11) = outfile1b
    wksSurface.Cells(13, 12) = "Extracted Grids"
End If

End Function

Public Function srfGridMosaicLastNode(SurferApp As Object, grid1 As String, grid2 As String, myOutGrid)

Dim gridarray(1 To 2) As String

gridarray(1) = grid1
gridarray(2) = grid2

'Mosaic Grid
'SrfOverlapMethodValues
    '1 = Average node value , 2 = First node value, 3 = Last node value
    '4 = Minimum node value, 5 = Maximum node value, 6 = Sum of node values
srfGridMosaic = SurferApp.GridMosaic(InGrids:=gridarray, OverlapMethod:=3, outGrid:=myOutGrid, OutFmt:=3)

End Function

Public Function srfFillContours(SurferApp As Object, ContourMap As Object, myGrid As String, clvl As Double, zMin As Double, zMax As Double)

'Dim SurferApp As Object
'Set SurferApp = CreateObject("Surfer.Application")
'SurferApp.Visible = True

'Creates a contour map from the grid file
Application.StatusBar = "Creating Contours..."
myColorMapFile = "G:\Macro_Library\Groundwater\Steve\2605_THVC\WT_Interpolator\CLR_Files\BlueRed.clr"

'Creates a plot document window
Set plot = SurferApp.Documents.Add

Dim map As Object
Set map = plot.Shapes.AddContourMap(myGrid)

'Dim ContourMap as object
Set ContourMap = plot.Shapes.Item(1).overlays.Item(1)

Dim ContourLevels As Object
Set ContourLevels = ContourMap.Levels
mycontours = ContourLevels.AutoGenerate(MinLevel:=WorksheetFunction.Floor(zMin, clvl), MaxLevel:=WorksheetFunction.Ceiling(zMax, clvl), Interval:=clvl)

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

End Function

Public Function srfBlankFile(grid1 As String, bFile As String, grid2 As String)
'Blanks a surfer .grd file using a blanking file

Dim SrfApp As Object
Set SrfApp = CreateObject("Surfer.Application")

myTempVar = SrfApp.GridBlank(inGrid:=grid1, blankFile:=bFile, outGrid:=grid2, OutFmt:=3)

End Function

Public Function Color2RGB(myColorString As String, r As Integer, g As Integer, b As Integer)

If LCase(myColorString) = "black" Or myColorString = "" Then
    r = 0
    g = 0
    b = 0
    Exit Function
End If

If LCase(myColorString) = "red" Then
    r = 255
    g = 0
    b = 0
    Exit Function
End If

If LCase(myColorString) = "green" Then
    r = 0
    g = 255
    b = 0
    Exit Function
End If

If LCase(myColorString) = "blue" Then
    r = 0
    g = 0
    b = 255
    Exit Function
End If

If LCase(myColorString) = "grey30" Then
    r = 217
    g = 217
    b = 217
    Exit Function
End If

If LCase(myColorString) = "grey50" Then
    r = 191
    g = 191
    b = 191
    Exit Function
End If

If LCase(myColorString) = "grey70" Then
    r = 150
    g = 150
    b = 150
    Exit Function
End If

If LCase(myColorString) = "grey90" Then
    r = 89
    g = 89
    b = 89
    Exit Function
End If

r = 0
g = 0
b = 0

End Function
