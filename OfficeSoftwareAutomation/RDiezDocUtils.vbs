
' This file provides routines for the following purposes:
'
' 1) Convert the current LibreOffice Writer document to a PDF file, and then
'    generate a second PDF file with extra content in the background
'    (typically a letterhead or watermark) on all pages.
'
'    The extra content for the background comes from a third, existing PDF file. The path to that
'    background PDF file is hard-coded in this script.
'
'    You need the pdftk tool installed on your system. pdftk is free software licensed under the GPL.
'    Download pdftk for Windows from www.pdftk.com / www.pdflabs.com
'    The download package you need for the command-line tool is called "PDFtk Server".
'    If you use Chocolatey, the package name is 'pdftk-server'.
'
'    See routine GeneratePdf_GuiWrapper().
'
' 2) Copy the current document to an "Archived" subdirectory.
'    See external script "copy-to-old-versions-archive.sh" for more information
'    about how the archival is performed.
'
'    See routine CopyToOldVersionsArchive_GuiWrapper().
'
' 3) Open a password-protected file programmatically.
'
'    See routine OpenPasswordProtectedFile().
'
' In order to use this code, you need to install it in LibreOffice:
' Open the Macro Editor and create a new BASIC module called "RDiezDocUtils"
' under "My Macros & Dialogs", "Standard". Then copy this source code to that module.
' Afterwards, adjust backgroundFilepath and CopyToOldVersionsArchiveScriptName as needed.
'
' Under Linux, such modules land under: $HOME/.config/libreoffice/4/user/basic/Standard/
' The trouble is, they are XML files with annoying character quoting,
' and they are not really suitable for source control.
'
' Copyright (c) 2024-2025 R. Diez - Licensed under the GNU AGPLv3

' Option Compatible - I haven't needed this one yet.
Option VBASupport 1  REM  Necessary for Err.Raise
Option Explicit


' Programmatically open a password-protected file.
' This routine is designed to be programmatically called,
' see companion script OpenEncryptedLibreOfficeDocument.sh .
'
' Warning: The password is not passed in a secure way, see:
'          Bug 42647 - command line option to specify password
'          https://bugs.documentfoundation.org/show_bug.cgi?id=42647

Sub OpenPasswordProtectedFile ( filename As String, _
                                password As String )

  On Local Error GoTo AlertAndReturn

  Dim fileProps(0) As new com.sun.star.beans.PropertyValue
  fileProps(0).Name = "Password"
  fileProps(0).Value = password

  Dim docUrl
  docUrl = ConvertToURL( filename )

  ' With "_default" LibreOffice checks whether the document is already opened.
  Dim doc As Object
  doc = StarDesktop.loadComponentFromURL( docUrl, "_default", 0, fileProps() )

  ' If the file does not exist, LibreOffice 24.8.6.2 under Linux shows several error dialog boxes,
  ' but it carries on. Therefore, manually check the returned object here.
  '
  ' Unfortunately, if the password is incorrect, you get a "General input/output error",
  ' instead of the "The password is incorrect" error that LibreOffice normally generates.

  If ( IsNull( doc ) ) Then
    RaiseError "Cannot open document. Is the password correct?" & chr(13) & "The document URL is: " & docUrl
  End If

  Exit Sub

AlertAndReturn:

  MsgBox Err.Description, MB_ICONSTOP, "Error"

End Sub


Sub CopyToOldVersionsArchive_GuiWrapper

  Const CopyToOldVersionsArchiveScriptName = "/home/some/where/copy-to-old-versions-archive.sh"

  On Local Error GoTo AlertAndReturn

  Dim doc As Object
  Set doc = ThisComponent

  LoadToolsLibrary  ' Not really needed in this routine.

  VerifyConfiguration

  VerifyIsWriterDocument( doc )

  VerifyDocumentCanBeSavedToFile( doc )

  Dim docFilename As String
  docFilename = ConvertFromURL( doc.URL )

  StoreDoc( doc )

  Dim cmdArgs As String
  cmdArgs = """--zenity""" & " ""--"" " & """" & docFilename & """"

  ShellWrapper CopyToOldVersionsArchiveScriptName, cmdArgs

  If False Then
    MsgBox "Document copied to old versions archive."
  End If

  Exit Sub

AlertAndReturn:

  MsgBox Err.Description, MB_ICONSTOP, "Error"

End Sub


Const backgroundFilepath = "/home/some/where/Letterhead.pdf"

Const minTopMarginMm =  20


Sub GeneratePdf_GuiWrapper

  On Local Error GoTo AlertAndReturn

  Dim doc As Object
  Set doc = ThisComponent

  GeneratePdf doc, backgroundFilepath

  If False Then
    MsgBox "PDF generated."
  End If

  Exit Sub

AlertAndReturn:

  MsgBox Err.Description, MB_ICONSTOP, "Error"

End Sub


Sub GeneratePdf ( doc As Object, bkgFilename As String )

  LoadToolsLibrary

  VerifyConfiguration

  VerifyIsWriterDocument( doc )

  VerifyDocumentCanBeSavedToFile( doc )

  CheckPageSizes( doc )

  CheckTextSections( doc )

  CheckNoDdelinkBookmarks( doc )

  CheckDocumentProperties( doc )


  ' We could check more things here:
  '
  ' - Check under menu "Edit", "Track Changes" that:
  '   - "Record" should not be active.
  '   - "Manage..." should show an empty change list.
  '
  ' - Check that there is no hidden text (the "Hidden characters" feature).


  ' Update all contents from external content like linked graphics and linked text sections.
  ' The updateLinks() method is in interface com.sun.star.util.XLinkUpdate .
  doc.updateLinks()


  ' I wonder whether there are other things we could update here.
  ' The first thing that springs to mind is an eventual page count field,
  ' but such counters seem to update immediately while editing.
  '
  ' In Menu "Tools", "Update", there are some updatable things.
  ' There is some UpdateAllCharts() method, but I haven't figured out yet how to call it.
  '
  ' There is also reformat() method in com.sun.star.text.XTextDocument,
  ' but I do not know yet what it does.
  If False Then
    doc.reformat()
  End If


  ' Update all "document indexes" like the "table of contents".
  ' Do this after updating all other included documents and fields,
  ' as otherwise the page numbers may be wrong.

  Dim i As Integer

  For i = 0 To doc.getDocumentIndexes().count - 1
    doc.getDocumentIndexes().getByIndex(i).update()
  Next


  StoreDoc( doc )


  ' --- Generate the PDF ---

  Dim urlWithoutFileExtension As String
  urlWithoutFileExtension = GetFileNameWithoutExtension( doc.URL )

  ' After you are happy with the result, you need to manually remove the "draft" suffix from the filenames.
  Const draftSuffix = " - draft"

  Dim pdfUrl as String
  pdfUrl = urlWithoutFileExtension & draftSuffix & ".pdf"

  Dim pdfFilename As String
  pdfFilename = ConvertFromURL( pdfUrl )

  ' Delete the destination file beforehand, so that we can generate
  ' a more user-friendly error message if it fails.
  DeleteFileIfExists pdfFilename

  Dim pdfConversionArgs(0) as new com.sun.star.beans.PropertyValue

  pdfConversionArgs(0).Name  = "FilterName"
  pdfConversionArgs(0).Value = "writer_pdf_Export"

  StoreDocToUrl doc, pdfUrl, pdfConversionArgs


  VerifyFileExists bkgFilename


  ' --- Generate the PDF with the background ---

  Const withBackgroundFilenameSuffix = "-WithLetterhead"

  Dim pdfWithBackgroundUrl as String
  pdfWithBackgroundUrl = urlWithoutFileExtension & withBackgroundFilenameSuffix & draftSuffix & ".pdf"

  Dim pdfWithBackgroundFilepath As String
  pdfWithBackgroundFilepath = ConvertFromURL( pdfWithBackgroundUrl )

  DeleteFileIfExists pdfWithBackgroundFilepath

  Dim letterHeadCmdArgs As String
  letterHeadCmdArgs = """" & pdfFilename & """ background """ & bkgFilename & """ output """ & pdfWithBackgroundFilepath & """"

  ShellWrapper "pdftk", letterHeadCmdArgs

  ' This check is important for two reasons:
  ' 1) We cannot check the exit code of the child process, so we will not realise if the child process failed.
  ' 2) OpenFileWithDefaultSystemHandler() does not fail if the file does not exist.
  VerifyFileExists pdfWithBackgroundFilepath


  ' --- Open the generated PDF with the background ---

  OpenFileWithDefaultSystemHandler pdfWithBackgroundUrl

End Sub


Sub LoadToolsLibrary

  ' We are using routines like GetFileNameWithoutExtension, which are in library 'Tools',
  ' under 'Strings', so check that the library is loaded.

  If Not BasicLibraries.isLibraryLoaded( "Tools" ) Then

    If False Then
      ' Apparently, the Tools library is not loaded by default on start-up.
      RaiseError( "Library 'Tools' not loaded." )
    Else
      BasicLibraries.loadLibrary( "Tools" )
    End If

  End If

End Sub


Sub VerifyConfiguration

  Dim configProvider As Object
  configProvider = CreateUnoServiceWrapper( "com.sun.star.configuration.ConfigurationProvider" )

  Dim configAccessParams(0) As new com.sun.star.beans.PropertyValue
  configAccessParams(0).Name = "nodepath"
  ' The user settings are usually located here: /home/<user>/.config/libreoffice/4/user/registrymodifications.xcu
  configAccessParams(0).Value = "/org.openoffice.Office.Common/Save/URL"

  Dim readOnlySettings As Object
  readOnlySettings = configProvider.createInstanceWithArguments( "com.sun.star.configuration.ConfigurationAccess", configAccessParams )


  Dim optionSaveUrlsRelativeToFilesystem As Variant
  optionSaveUrlsRelativeToFilesystem = readOnlySettings.getByName( "FileSystem" )

  If Not optionSaveUrlsRelativeToFilesystem Then
    ' Otherwise, links to external content will easily break.
    RaiseError( "LibreOffice Option ""Save URLs relative to file system"" must be enabled." )
  End If

End Sub


Sub VerifyDocumentCanBeSavedToFile ( doc As Object )

  ' Method hasLocation() is in interface com.sun.star.frame.XStorable .
  ' Without a location we cannot save the document.
  If Not doc.hasLocation Then
    RaiseError( "Document """ & doc.Title & """ has not been saved to disk yet." )
  End If

  If doc.isReadonly Then
    RaiseError( "Document """ & doc.Title & """ is read only." )
  End If

End Sub


Sub CheckPageSizes ( doc As Object )

  Const DinA4WidthMm   = 210
  Const DinA4HeightMm  = 297


  Dim viewCursor As Object  ' Interface com.sun.star.text.XTextViewCursor
  viewCursor = doc.CurrentController.getViewCursor()

  ' This is the same cursor instance available in the user interface,
  ' so save and restore its position.
  Dim savedCursorPos As Object
  savedCursorPos = viewCursor.Start  ' Of type SwXTextRange.


  ' Restoring the cursor position does not restore the scroll position,
  ' but setViewData() doesn't do that either.
  Const saveAndRestoreViewData = False

  Dim savedViewData As Object
  If saveAndRestoreViewData Then
    savedViewData = doc.getViewData()
  End If


  ' Instead of querying the page size for each page, it may be more efficient to search
  ' for page style changes, and query the page sizes only after such a change.

  viewCursor.JumpToFirstPage

  Dim pageNumber As Integer
  pageNumber = 1  ' We can actually retrieve the page number with viewCursor.getPage().

  Dim pageStyleName As String
  Dim pageStyle As Object

  Do

    pageStyleName = viewCursor.PageStyleName
    pageStyle = doc.StyleFamilies.getByName( "PageStyles" ).getByName( pageStyleName )

    If Not IsPaperDimensionEqual( pageStyle.Width , DinA4WidthMm  ) Or _
       Not IsPaperDimensionEqual( pageStyle.Height, DinA4HeightMm ) Then

      RaiseError( "Page " & pageNumber & " is not DIN A4 size." )

    End If

    If Not IsPaperDimensionEqualOrGreaterThan( pageStyle.TopMargin, minTopMarginMm ) Then

      RaiseError( "Page " & pageNumber & " has a top margin which is < " & minTopMarginMm & " mm." )

    End If


    If Not viewCursor.JumpToNextPage Then
      Exit Do
    End If

    pageNumber = pageNumber + 1

  Loop


  viewCursor.goToRange( savedCursorPos, false )

  If saveAndRestoreViewData Then
    doc.setViewData( savedViewData )
  End If

End Sub


' The DIN A4 width is 21001, instead of the expected 21000 so there is a little deviation.
Const PaperDimensionTolerance = 1


Function IsPaperDimensionEqual ( dimensionIn100thMm as Long, expectedDimensionInMm as Integer ) As Boolean

  Dim expectedDimensionIn100thMm As Long
  expectedDimensionIn100thMm = expectedDimensionInMm * 100

  Dim difference As Long
  difference = expectedDimensionIn100thMm - dimensionIn100thMm

  ' Calculate the absolute value. There is a built-in Abs() function, but it returns a Double.
  If difference < 0 Then difference = - difference

  ' The DIN A4 width is 21001, so there is a little deviation.

  IsPaperDimensionEqual = difference <= PaperDimensionTolerance

End Function


Function IsPaperDimensionEqualOrGreaterThan ( dimensionIn100thMm as Long, minDimensionInMm as Integer ) As Boolean

  Dim minDimensionIn100thMm As Long
  minDimensionIn100thMm = minDimensionInMm * 100

  Dim difference As Long
  difference = dimensionIn100thMm - minDimensionIn100thMm

  IsPaperDimensionEqualOrGreaterThan = difference >= - PaperDimensionTolerance

End Function


Sub CheckTextSections ( doc As Object )

  If False Then

    Dim allTextSections As Object
    ' Method getTextSections() is in interface com.sun.star.text.XTextSectionsSupplier .
    allTextSections = doc.getTextSections()

    Dim textSectionObj As Object
    Dim textSectionFileLinkUrl As String

    For Each textSectionObj In allTextSections

      ' I had expected that, if the section is not linked to external content,
      ' the textSectionObj.FileLink would be Null, but it is always there.
      ' We can only check whether textSectionObj.FileLink.FileURL is an empty string.
      textSectionFileLinkUrl = textSectionObj.FileLink.FileURL

      If textSectionFileLinkUrl <> "" Then

        ' We cannot actually check here whether the URL in each section's FileLink was stored
        ' in the file as absolute or relative, because the URL in that property is always absolute.

        MsgBox "Section """ & textSectionObj.Name & """ FileLink: " & textSectionFileLinkUrl

      End If

    Next

  End If

End Sub


' DDE Link bookmarks are usually inserted inadvertently and serve no purpose,
' so error if one is found.

Sub CheckNoDdelinkBookmarks ( doc As Object )

  Const DdeLinkNamePrefix = "__DdeLink__"

  Dim allBookmarks As Object  ' SwXBookmarks, com.sun.star.container.XNameAccess
  allBookmarks = doc.GetBookmarks()  ' Interface com.sun.star.text.XBookmarksSupplier

  Dim allBookmarkNames As Object
  allBookmarkNames = allBookmarks.getElementNames()

  Dim bookmarkName As String
  Dim i As Long

  For i = LBound( allBookmarkNames ) To UBound( allBookmarkNames )

    bookmarkName = allBookmarkNames( i )

    If Left( bookmarkName, Len( DdeLinkNamePrefix ) ) = DdeLinkNamePrefix Then
      RaiseError "Bookmark """ & bookmarkName & """ is a DDE Link and should probably be removed."
    End If

    ' How to access a bookmark and use it:
    '   bookmark = allBookmarks.getByName( bookmarkName )
    '   bookmark.Anchor.String = ""  ' Delete the text encompassed by the bookmar.
    '   bookmark.dispose()           ' Delete the bookmark.

  Next

End Sub


Sub CheckDocumentProperties ( doc As Object )

  Dim docProps As Object  ' Interface com.sun.star.document.XDocumentProperties
  docProps = doc.getDocumentProperties()

  If docProps.Author <> "" Then
    RaiseError "The document author is not empty: " & docProps.Author
  End If

  If docProps.Title = "" Then
    RaiseError "The document title is empty."
  End If

End Sub


Sub RaiseError ( errMsg As String )

  Const firstUserDefinedErrorCode = 2001

  Err.Raise( firstUserDefinedErrorCode, , errMsg )

End Sub


Sub VerifyHasUnoInterface ( obj As Object, interfaceName As String )

  If Not HasUnoInterfaces( obj, interfaceName ) Then

    If HasUnoInterfaces( obj, "com.sun.star.lang.XServiceInfo" ) Then

      RaiseError( "The " & obj.getImplementationName & " object does not have interface """ & interfaceName & """." )

    Else

      RaiseError( "The object does not have interface " & interfaceName )

    End If

  End If

End Sub


Sub VerifySupportsUnoService ( obj As Object, serviceName As String )

  If Not HasUnoInterfaces( obj, "com.sun.star.lang.XServiceInfo" ) Then

    RaiseError( "The object does not support interface com.sun.star.lang.XServiceInfo ." )

  End If

  If Not obj.SupportsService ( serviceName ) Then

    RaiseError( "The " & obj.getImplementationName & " object does not support service """ & serviceName & """." )

  End If

End Sub


Sub VerifyIsWriterDocument ( obj As Object )

  ' Make sure we have a LibreOffice Writer document, for example, in order to call
  ' method getDocumentIndexes(), which is actually in interface com.sun.star.text.XDocumentIndexesSupplier,
  ' and other document-related methods.
  '
  ' A LibreOffice Writer document has these 3 services:
  ' - com.sun.star.document.OfficeDocument
  ' - com.sun.star.text.GenericTextDocument
  ' - com.sun.star.text.TextDocument
  ' Just check one of them here.
  VerifySupportsUnoService obj, "com.sun.star.text.GenericTextDocument"

  ' This interface is for method doc.updateLinks(),
  ' in order to update external linked contents.
  VerifyHasUnoInterface obj, "com.sun.star.util.XLinkUpdate"

End Sub


Sub StoreDoc ( doc As Object )

  On Local Error GoTo HandleError

  ' Method store() is in interface com.sun.star.frame.XStorable .
  doc.store()

  Exit Sub

HandleError:

  RaiseError "Error writing document to URL """ & doc.URL & """: " & Err.Description

End Sub


Sub StoreDocToUrl ( doc As Object, url As String, args as Object )

  On Local Error GoTo HandleError

  doc.StoreToUrl( url, args )

  Exit Sub

HandleError:

  RaiseError "Error writing document to URL """ & url & """: " & Err.Description

End Sub


Function CreateUnoServiceWrapper ( serviceName As String )

  Dim serviceObj As Object
  serviceObj = createUnoService( serviceName )

  If IsNull( serviceObj ) Then
    RaiseError( "Cannot create UNO service """ & serviceName & """." )
  End If

  CreateUnoServiceWrapper = serviceObj

End Function


Sub ShellWrapper ( pathname As String, args As String )

  On Local Error GoTo HandleError

  ' About the arguments:
  ' On Linux, LibreOffice seems to identify strings double quotes ('"') and pass them as separate arguments.
  ' For example, the argument string "test1 ""test2 test3"" test4" gets passed as: test1 test2\ test3 test4

  ' The Shell() function returns a Long integer, but it is always 0.
  ' Apparently, there is no way to retrive the child process' exit code.
  Dim uselessReturnValue As Long

  Const focusMinWin = 2  ' Only on Windows: "The focus is on the minimized program window". Ignored on other platforms.

  Const waitForTheChildProcessToExit = True

  uselessReturnValue = Shell( pathname, focusMinWin, args, waitForTheChildProcessToExit )

  If uselessReturnValue <> 0 Then
    RaiseError "Shell() returned an unexpected value of " & uselessReturnValue & "."
  End If

  Exit Sub

HandleError:

  RaiseError "Error starting child process """ & pathname & """, with arguments [" & args & "]: " & Err.Description

End Sub


' Warning: This routine does not complain if the file does not exist,
'          so make sure you call VerifyFileExists() beforehand.

Sub OpenFileWithDefaultSystemHandler ( url As String )

  Dim shellExecute As Object
  shellExecute = CreateUnoServiceWrapper( "com.sun.star.system.SystemShellExecute" )

  Dim filenameToOpenWithDefaultHandler as String
  filenameToOpenWithDefaultHandler = ConvertFromURL( url )

  ' About SystemShellExecute.execute(): With flag value 42, shell escaping is performed, see here:
  ' https://ask.libreoffice.org/t/solved-calc-macro-command-execute-under-linux/35733/8

  shellExecute.execute url, "", 0

End Sub


Sub VerifyFileExists ( filename As String )

  If Not FileExists( filename ) Then

    RaiseError "File does not exist: " & filename

  End If

End Sub


Sub DeleteFileIfExists ( filename As String )

  On Local Error GoTo HandleError

  If FileExists( filename ) Then

    Kill filename

  End If

  Exit Sub

HandleError:

  RaiseError "Cannot delete file: " & filename

End Sub
