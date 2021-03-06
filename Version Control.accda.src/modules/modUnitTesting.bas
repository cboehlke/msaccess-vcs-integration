Option Compare Database
Option Explicit
Option Private Module

'@TestModule
'@Folder("Tests")

Private Assert As Object
Private Fakes As Object

'@ModuleInitialize
Private Sub ModuleInitialize()
    'this method runs once per module.
    Set Assert = CreateObject("Rubberduck.AssertClass")
    Set Fakes = CreateObject("Rubberduck.FakesProvider")
End Sub

'@ModuleCleanup
Private Sub ModuleCleanup()
    'this method runs once per module.
    Set Assert = Nothing
    Set Fakes = Nothing
End Sub

'@TestInitialize
Private Sub TestInitialize()
    'this method runs before every test in the module.
End Sub

'@TestCleanup
Private Sub TestCleanup()
    'this method runs after every test in the module.
End Sub

' Test shows that UCS-2 files exported by Access make round trip through our conversions.
'@TestMethod("TextConversions")
Public Sub TestUCS2toUTF8RoundTrip()
    On Error GoTo TestFail
    
    'Arrange:
    Dim queryName As String
    queryName = "Temp_Test_Query_Delete_Me_�_�_�"
    Dim tempFileName As String
    tempFileName = GetTempFile()
    
    Dim UCStoUCS As String
    Dim UCStoUTF As String
    Dim UTFtoUTF As String
    Dim UTFtoUCS As String
    UCStoUCS = tempFileName & "UCS-2toUCS-2"
    UCStoUTF = tempFileName & "UCS-2toUTF-8"
    UTFtoUTF = tempFileName & "UTF-8toUTF-8"
    UTFtoUCS = tempFileName & "UTF-8toUCS-2"
    
    ' Use temporary query to export example file
    CurrentDb.CreateQueryDef queryName, "SELECT * FROM TEST WHERE TESTING='���'"
    Application.SaveAsText acQuery, queryName, tempFileName
    CurrentDb.QueryDefs.Delete queryName
        
    ' Read original export
    Dim originalExport As String
    With FSO.OpenTextFile(tempFileName, , , TristateTrue)
        originalExport = .ReadAll
        .Close
    End With
            
    'Act:
    ConvertUtf8Ucs2 tempFileName, UCStoUCS
    ConvertUcs2Utf8 UCStoUCS, UCStoUTF
    ConvertUcs2Utf8 UCStoUTF, UTFtoUTF
    ConvertUtf8Ucs2 UTFtoUTF, UTFtoUCS
    
    ' Read final file that went through all permutations of conversion
    Dim finalFile As String
    With FSO.OpenTextFile(UTFtoUCS, , , TristateTrue)
        finalFile = .ReadAll
        .Close
    End With
    
    ' Cleanup temp files
    'fso.DeleteFile tempFileName
    'fso.DeleteFile UTFtoUCS
    
    'Assert:
    Assert.AreEqual originalExport, finalFile
    
    GoTo TestExit
    
TestFail:
    Assert.Fail "Test raised an error: #" & Err.Number & " - " & Err.Description

TestExit:
    
End Sub

'@TestMethod("TextConversion")
Private Sub TestParseSpecialCharsInJson()
    On Error GoTo TestFail
    
    'Arrange:
    Dim strPath As String
    Dim dict As Dictionary
    Dim FSO
    strPath = GetTempFile
        
    Set FSO = CreateObject("Scripting.FileSystemObject")
    With FSO.CreateTextFile(strPath, True)
        .WriteLine "{""Test"":""��� are special?""}"
        .Close
    End With
    
    Debug.Print strPath
    
    'Act:
    Set dict = modFunctions.ReadJsonFile(strPath)
    
    'Assert:
    If dict Is Nothing Then
        Assert.Fail "Empty dictionary returned"
    Else
        Debug.Print dict("Test")
        Assert.Succeed
    End If
    

TestExit:
    Exit Sub
TestFail:
    Assert.Fail "Test raised an error: #" & Err.Number & " - " & Err.Description
End Sub


Sub s()
    Dim dItems As Dictionary
    Dim v As Variant
    
    Set dItems = New Dictionary
    
    dItems.Add "C", "C"
    dItems.Add "A", "A"
    dItems.Add "B", "B"
    
    Set dItems = SortDictionaryByKeys(dItems)
    
    For Each v In dItems
        Debug.Print v
    Next
End Sub