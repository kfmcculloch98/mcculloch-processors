VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsMaps"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'Class Module: clsMaps
'Used for storing collection of objects for use in Surfer

Private mapColl As Collection

Property Get oName() As Collection
    Set oName = mapColl
End Property

Property Set oName(newMap As Collection)
    Set mapColl = newMap
End Property
