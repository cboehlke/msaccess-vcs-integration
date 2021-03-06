Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'---------------------------------------------------------------------------------------
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : This class extends the IDbComponent class to perform the specific
'           : operations required by this particular object type.
'           : (I.e. The specific way you export or import this component.)
'---------------------------------------------------------------------------------------
Option Compare Database
Option Explicit

Private m_Property As DAO.Property
Private m_AllItems As Collection

' This requires us to use all the public methods and properties of the implemented class
' which keeps all the component classes consistent in how they are used in the export
' and import process. The implemented functions should be kept private as they are called
' from the implementing class, not this class.
Implements IDbComponent


'---------------------------------------------------------------------------------------
' Procedure : Export
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Export the individual database component (table, form, query, etc...)
'---------------------------------------------------------------------------------------
'
Private Sub IDbComponent_Export()
    
    Dim prp As DAO.Property
    Dim dCollection As Dictionary
    Dim dItem As Dictionary
    Dim varValue As Variant
    Dim strPath As String
    
    Set dCollection = New Dictionary
    
    ' Loop through all properties
    For Each prp In CurrentDb.Properties
        Select Case prp.Name
            Case "Connection"
                ' Connection object for ODBCDirect workspaces. Not needed.
            Case "Last VCS Export", "Last VCS Version"
                ' Reduce noise by ignoring these values.
                ' (We already have this information in the header.)
            Case Else
                varValue = prp.Value
                If prp.Name = "AppIcon" Or prp.Name = "Name" Then
                    If Len(varValue) > 0 Then
                        ' Try to use a relative path
                        strPath = GetRelativePath(CStr(varValue))
                        If Len(strPath) > 0 Then
                            varValue = strPath
                        Else
                            ' The full path may contain sensitive info. Encrypt the path but not the file name.
                            varValue = EncryptPath(CStr(varValue))
                        End If
                    End If
                End If
                Set dItem = New Dictionary
                dItem.Add "Value", varValue
                dItem.Add "Type", prp.Type
                dCollection.Add prp.Name, dItem
        End Select
    Next prp
    
    ' Write to file. The order of properties may change, so sort them to keep the order consistent.
    WriteJsonFile Me, SortDictionaryByKeys(dCollection), IDbComponent_SourceFile, "Database Properties (DAO)"
    
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Import
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Import the individual database component from a file.
'---------------------------------------------------------------------------------------
'
Private Sub IDbComponent_Import(strFile As String)
    
    Dim dExisting As Dictionary
    Dim prp As DAO.Property
    Dim dImport As Dictionary
    Dim dItems As Dictionary
    Dim dbs As DAO.Database
    Dim varKey As Variant
    Dim varValue As Variant
    Dim strDecrypted As String
    Dim blnAdd As Boolean
    
    Set dbs = CurrentDb
    
    ' Pull a list of the existing properties so we know whether
    ' to add or update the existing property.
    Set dExisting = New Dictionary
    For Each prp In dbs.Properties
        Select Case prp.Name
            Case "Connection"   ' This is an object.
            Case Else
                dExisting.Add prp.Name, Array(prp.Value, prp.Type)
        End Select
    Next prp

    ' Read properties from source file
    Set dImport = ReadJsonFile(strFile)
    If Not dImport Is Nothing Then
        Set dItems = dImport("Items")
        For Each varKey In dItems.Keys
            Select Case varKey
                Case "Connection", "Name", "Version" ' Can't set these properties
                Case Else
                    blnAdd = False
                    varValue = dItems(varKey)("Value")
                    ' Check for encryption
                    strDecrypted = Decrypt(CStr(varValue))
                    If CStr(varValue) <> strDecrypted Then varValue = strDecrypted
                    ' Check for relative path
                    If Left(varValue, 4) = "rel:" Then varValue = GetPathFromRelative(CStr(varValue))
                    ' Check for existing value
                    If dExisting.Exists(varKey) Then
                        If dItems(varKey)("Type") <> dExisting(varKey)(1) Then
                            ' Type is different. Need to remove and add as correct type.
                            dbs.Properties.Delete varKey
                            blnAdd = True
                        Else
                            ' Check the value, and update if different
                            If varValue <> dExisting(varKey)(0) Then
                                ' Update value of existing property if different.
                                dbs.Properties(varKey).Value = varValue
                            End If
                        End If
                    Else
                        ' Add properties that don't exist.
                        blnAdd = True
                    End If
                    If blnAdd Then
                        ' Create property, then append to collection
                        Set prp = dbs.CreateProperty(varKey, dItems(varKey)("Type"), varValue)
                        dbs.Properties.Append prp
                    End If
            End Select
        Next varKey
    End If
    
End Sub


'---------------------------------------------------------------------------------------
' Procedure : GetAllFromDB
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return a collection of class objects represented by this component type.
'---------------------------------------------------------------------------------------
'
Private Function IDbComponent_GetAllFromDB() As Collection
    
    Dim prp As DAO.Property
    Dim cProp As IDbComponent

    ' Build collection if not already cached
    If m_AllItems Is Nothing Then
        Set m_AllItems = New Collection
        For Each prp In CurrentDb.Properties
            Set cProp = New clsDbProperty
            Set cProp.DbObject = prp
            m_AllItems.Add cProp, prp.Name
        Next prp
    End If

    ' Return cached collection
    Set IDbComponent_GetAllFromDB = m_AllItems
        
End Function


'---------------------------------------------------------------------------------------
' Procedure : GetFileList
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return a list of file names to import for this component type.
'---------------------------------------------------------------------------------------
'
Private Function IDbComponent_GetFileList() As Collection
    Set IDbComponent_GetFileList = New Collection
    IDbComponent_GetFileList.Add IDbComponent_SourceFile
End Function


'---------------------------------------------------------------------------------------
' Procedure : ClearOrphanedSourceFiles
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Remove any source files for objects not in the current database.
'---------------------------------------------------------------------------------------
'
Private Sub IDbComponent_ClearOrphanedSourceFiles()
    Dim strFile As String
    strFile = IDbComponent_BaseFolder & "properties.txt"
    If FSO.FileExists(strFile) Then Kill strFile    ' Remove legacy file
End Sub


'---------------------------------------------------------------------------------------
' Procedure : DateModified
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : The date/time the object was modified. (If possible to retrieve)
'           : If the modified date cannot be determined (such as application
'           : properties) then this function will return 0.
'---------------------------------------------------------------------------------------
'
Private Function IDbComponent_DateModified() As Date
    ' Modified date unknown.
    IDbComponent_DateModified = 0
End Function


'---------------------------------------------------------------------------------------
' Procedure : SourceModified
' Author    : Adam Waller
' Date      : 4/27/2020
' Purpose   : The date/time the source object was modified. In most cases, this would
'           : be the date/time of the source file, but it some cases like SQL objects
'           : the date can be determined through other means, so this function
'           : allows either approach to be taken.
'---------------------------------------------------------------------------------------
'
Private Function IDbComponent_SourceModified() As Date
    If FSO.FileExists(IDbComponent_SourceFile) Then IDbComponent_SourceModified = FileDateTime(IDbComponent_SourceFile)
End Function


'---------------------------------------------------------------------------------------
' Procedure : Category
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return a category name for this type. (I.e. forms, queries, macros)
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_Category() As String
    IDbComponent_Category = "db properties"
End Property


'---------------------------------------------------------------------------------------
' Procedure : BaseFolder
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return the base folder for import/export of this component.
'---------------------------------------------------------------------------------------
Private Property Get IDbComponent_BaseFolder() As String
    IDbComponent_BaseFolder = Options.GetExportFolder
End Property


'---------------------------------------------------------------------------------------
' Procedure : Name
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return a name to reference the object for use in logs and screen output.
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_Name() As String
    IDbComponent_Name = "Database Properties (DAO)"
End Property


'---------------------------------------------------------------------------------------
' Procedure : SourceFile
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return the full path of the source file for the current object.
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_SourceFile() As String
    IDbComponent_SourceFile = IDbComponent_BaseFolder & "dbs-properties.json"
End Property


'---------------------------------------------------------------------------------------
' Procedure : Count
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Return a count of how many items are in this category.
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_Count() As Long
    IDbComponent_Count = IDbComponent_GetAllFromDB.Count
End Property


'---------------------------------------------------------------------------------------
' Procedure : ComponentType
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : The type of component represented by this class.
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_ComponentType() As eDatabaseComponentType
    IDbComponent_ComponentType = edbDbsProperty
End Property


'---------------------------------------------------------------------------------------
' Procedure : Upgrade
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : Run any version specific upgrade processes before importing.
'---------------------------------------------------------------------------------------
'
Private Sub IDbComponent_Upgrade()
    ' No upgrade needed.
End Sub


'---------------------------------------------------------------------------------------
' Procedure : DbObject
' Author    : Adam Waller
' Date      : 4/23/2020
' Purpose   : This represents the database object we are dealing with.
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_DbObject() As Object
    Set IDbComponent_DbObject = m_Property
End Property
Private Property Set IDbComponent_DbObject(ByVal RHS As Object)
    Set m_Property = RHS
End Property


'---------------------------------------------------------------------------------------
' Procedure : SingleFile
' Author    : Adam Waller
' Date      : 4/24/2020
' Purpose   : Returns true if the export of all items is done as a single file instead
'           : of individual files for each component. (I.e. properties, references)
'---------------------------------------------------------------------------------------
'
Private Property Get IDbComponent_SingleFile() As Boolean
    IDbComponent_SingleFile = True
End Property


'---------------------------------------------------------------------------------------
' Procedure : Class_Initialize
' Author    : Adam Waller
' Date      : 4/24/2020
' Purpose   : Helps us know whether we have already counted the tables.
'---------------------------------------------------------------------------------------
'
Private Sub Class_Initialize()
    'm_Count = -1
End Sub


'---------------------------------------------------------------------------------------
' Procedure : Parent
' Author    : Adam Waller
' Date      : 4/24/2020
' Purpose   : Return a reference to this class as an IDbComponent. This allows you
'           : to reference the public methods of the parent class without needing
'           : to create a new class object.
'---------------------------------------------------------------------------------------
'
Public Property Get Parent() As IDbComponent
    Set Parent = Me
End Property