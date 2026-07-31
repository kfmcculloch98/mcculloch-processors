Attribute VB_Name = "Xsections"
Sub II_ExtractSectionPoints()

'Declarations
Dim trow As Integer
Dim fs, f

Const ForReading = 1, ForWriting = 2, ForAppending = 3

Set fs = CreateObject("Scripting.FileSystemObject")
Set wksXSec = Sheets("XSECTION")
Set wksMaster = Sheets("Input")

'Clear previous points, insert headers
trow = 1
wksXSec.Columns("G:L").Clear
wksXSec.Cells(1, 7) = "Section Name"
wksXSec.Cells(1, 8) = "Sec_X"
wksXSec.Cells(1, 9) = "Real_Z"
wksXSec.Cells(1, 10) = "Real_X"
wksXSec.Cells(1, 11) = "Real_Y"
trow = trow + 1

'Loop through list of .DXF files. Read in verticies and convert to real coordinates

irow = 3
While wksXSec.Cells(irow, 6) <> ""
    filenumber = FreeFile
    file_poly = wksXSec.Cells(irow, 6)
    start_row = trow
    
    'Populate variables with x-section data
    sec_name = wksXSec.Cells(irow, 1)  'Section Name
    lx = wksXSec.Cells(irow, 2)        'Left x
    ly = wksXSec.Cells(irow, 3)        'Left y
    rx = wksXSec.Cells(irow, 4)        'right x
    ry = wksXSec.Cells(irow, 5)        'right y
    
    dx = rx - lx
    dy = ry - ly
    
    Open file_poly For Input As #filenumber
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
                z1 = Val(fullstring) 'Not used, should be 0
                
                wksXSec.Cells(trow, 7) = sec_name
                wksXSec.Cells(trow, 8) = x1
                wksXSec.Cells(trow, 9) = y1
                trow = trow + 1
            Wend
NextLayer:
        End If
    Loop
        
endoffile:
    Close #filenumber

    'Convert section coordinates to real coordinates
    'secCheck = MsgBox("Do the section coordinates match the Water Table Profile?" & vbLf & vbLf _
                    '& "SECTION NAME: " & sec_name, vbQuestion + vbYesNo + vbDefaultButton2, "CONFIRM WT PROFILE MATCHES SECTION")
    'If secCheck = vbNo Then Exit Sub
    
    trow = start_row
    
    While wksXSec.Cells(trow, 8) <> ""
        'Determine x_section value for piezometer
        If dy = 0 Then 'E-W section
            wksXSec.Cells(trow, 10) = lx + (dx / Abs(dx)) * wksXSec.Cells(trow, 8)
            wksXSec.Cells(trow, 11) = ly
    
        'ElseIf dy = 0 And dx < 0 Then 'E-W section looking south
            'wksXsec.Cells(trow, 10) = lx - wksXsec.Cells(trow, 8)
            'wksXsec.Cells(trow, 11) = ly
    
        ElseIf dx = 0 Then 'N-S section looking west
            wksXSec.Cells(trow, 10) = lx
            wksXSec.Cells(trow, 11) = ly + (dy / Abs(dy)) * wksXSec.Cells(trow, 8)
            
        'ElseIf dx = 0 And dy < 0 Then 'N-S section looking east
            'wksXsec.Cells(trow, 10) = lx
            'wksXsec.Cells(trow, 11) = ly - wksXsec.Cells(trow, 9)
        
        Else 'Angled section
            secAng = Atn(Abs(dy) / Abs(dx))                                 'positive angle, rise/run
            vx = Cos(secAng) * wksXSec.Cells(trow, 8) * (dx / Abs(dx))      'x component of vector. +/- depends on direction of section line
            vy = Sin(secAng) * wksXSec.Cells(trow, 8) * (dy / Abs(dy))      'y component of vector. +/- depends on direction of section line
            
            wksXSec.Cells(trow, 10) = lx + vx                               'Actual X
            wksXSec.Cells(trow, 11) = ly + vy                               'Actual Y
        End If
        
        trow = trow + 1
    Wend
    
    irow = irow + 1
Wend

wksXSec.Activate
numpoints = WorksheetFunction.Count(wksXSec.Columns("H:H"))

appendCheck = MsgBox("Do you want to append data to Master list?" & vbLf & vbLf _
                & "Number of points to append: " & numpoints, vbQuestion + vbYesNo + vbDefaultButton2, "APPEND DATA TO MASTER")

If appendCheck = vbNo Then Exit Sub

'Append Data to Master worksheet
'Prompt user for Date, Category and Plot_Flag fields

sdate = InputBox("Enter watertable profile date" & vbLf & vbLf & "Enter date as: DD/MM/YYYY" & vbLf & "(Field can be left blank)", _
                "Watertable profile date", "DD/MM/YYYY")

If sdate = "" Then
    sdate = "-"
Else
    sdate = DateValue(sdate)
End If

plot_field = Val(InputBox("Enter number for Plot_Flag field: " & vbLf & vbLf & _
            "Enter 1 to include points in grid interpolation" & vbLf & _
            "Enter 0 to exclude points from grid interpolation", _
            "PLOT FLAG FOR SECTION POINTS", 1))
            
cat_field = InputBox("Enter Category Name: " & vbLf & vbLf, _
            "CATEGORY NAME FOR SECTION POINTS", "Section")
        
'Populate array with all section points
ReDim sec_array(numpoints, 4)

For i = 2 To numpoints + 1
    sec_array(i - 1, 1) = wksXSec.Cells(i, 10)                           'Real X
    sec_array(i - 1, 2) = wksXSec.Cells(i, 11)                           'Real Y
    sec_array(i - 1, 3) = wksXSec.Cells(i, 9)                            'Elevation
    sec_array(i - 1, 4) = wksXSec.Cells(i, 7)                            'Section Name
Next i

'Copy section points to end of Master list
wksMaster.Activate

'Find first empty row in Master list
jrow = 8
Do Until wksMaster.Cells(jrow, 1) = ""
    jrow = jrow + 1
Loop

id_count = 1    'Point ID counter

For i = 1 To numpoints
    If sec_array(i, 4) = wksMaster.Cells(jrow - 1, 2) Then
        id_count = id_count + 1
    Else
        id_count = 1
    End If
    
    wksMaster.Cells(jrow, 1) = sec_array(i, 4) & "-" & id_count         'Point_ID
    wksMaster.Cells(jrow, 2) = sec_array(i, 4)                          'Section Name
    wksMaster.Cells(jrow, 3) = sec_array(i, 1)                          'Real X
    wksMaster.Cells(jrow, 4) = sec_array(i, 2)                          'Real Y
    wksMaster.Cells(jrow, 5) = "-"
    wksMaster.Cells(jrow, 6) = sec_array(i, 3)                          'Elevation
    wksMaster.Cells(jrow, 7) = "-"
    wksMaster.Cells(jrow, 8) = sdate                                    'Date
    wksMaster.Cells(jrow, 9) = cat_field                                'Category
    wksMaster.Cells(jrow, 10) = plot_field                              'Plot Flag
    
    jrow = jrow + 1
Next i

End Sub
