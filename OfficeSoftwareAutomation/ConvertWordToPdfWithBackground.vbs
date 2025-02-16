
' This script converts a Microsoft Word document to a PDF file, and then
' generates a second PDF file with extra content in the background (typically a letterhead
' or watermark) on all pages.
'
' The extra content for the background comes from a third, existing PDF file. The path to that
' background PDF file is hard-coded in this script.
'
' You need the pdftk tool installed on your system. pdftk is free software licensed under the GPL.
' Download pdftk for Windows from www.pdftk.com / www.pdflabs.com
' The download package you need for the command-line tool is called "PDFtk Server".
' If you use Chocolatey, the package name is 'pdftk-server'.
'
'
' It is best to install this kind of script to a fixed location for all users, like
' %APPDATA%\MyScripts or even somewhere global for all users, on the PC or on a file server.
'
' In order to add this script to Windows Explorer's "Send to" menu, place a shortcut to it
' in the following directory:
'   %APPDATA%\Microsoft\Windows\SendTo
' (or more correctly, to the folder pointed by the registry key
'  HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\SendTo )
'
' A convenient way to open that directory is to click on "Start", "Run", and then enter "shell:sendto".
'
' The name of the shortcut becomes the menu option's caption, and you can rename the shortcut to your liking.
'
' There is no global "SendTo" folder for all users.
'
' Instead of using the "Send to" menu, the user can drag a file with the mouse to this .vbs
' script file to start the conversion.
'
'
' In order to run this script conveniently with a button from Microsoft Word 2010:
'
' - Create a Word template with macros (a .dotm file) named MyScripts.dotm
'   in directory %APPDATA%\Microsoft\Word\STARTUP .
'
'   Note that the system administrator can change the STARTUP path. You can find out the current path
'   inside Microsoft Word. For Word 2010, Word 2013 or Word 2016, go to File, Options, Advanced,
'   General group, File Locations.
'
' - Add the following code (or similar) to the template:
'
'   Option Explicit
'
'   Sub RunExternalScriptForCurrentDocument(scriptFilename)
'     dim scriptFilenameAbs
'     scriptFilenameAbs = Environ("APPDATA") & "\MyScripts\" & scriptFilename
'     Shell "wscript """ & scriptFilenameAbs & """ """ & ActiveDocument.FullName & """", vbNormalFocus
'   End Sub
'
'   Sub CopyToOldVersionsArchive()
'     RunExternalScriptForCurrentDocument "CopyToOldVersionsArchive.vbs"
'   End Sub
'
'   Sub ConvertWordToPdfWithBackground()
'     RunExternalScriptForCurrentDocument "ConvertWordToPDFWithBackground.vbs"
'   End Sub
'
' - In Word 2010, go to File, Options, Customize Ribbon.
' - Under "Choose commands from", select "Macros".
' - Add the macros above (ConvertWordToPdfWithBackground and CopyToOldVersionsArchive)
'   to the tabs you wish.
'
'
' Copyright (c) 2016-2025 R. Diez - Licensed under the GNU AGPLv3

Option Explicit

' Set here the user language to use. See GetMessage() for a list of language codes available.
const language = "eng"

Function GetMessage ( msgEng, msgDeu, msgSpa )

  Select Case language
    Case "eng"  GetMessage = msgEng
    Case "deu"  GetMessage = msgDeu
    Case "spa"  GetMessage = msgSpa
    Case Else   GetMessage = msgEng
      MsgBox "Invalid language.", vbOkOnly + vbError, "Error"
      WScript.Quit( 1 )
  End Select

End Function


Function Abort ( errorMessage )
  MsgBox errorMessage, vbOkOnly + vbError, GetMessage( "Error", "Fehler", "Error" )
  WScript.Quit( 1 )
End Function

Function AbortWithErrorInfo ( errorMessageAtTheTop, errorInfoAtTheBottom )
         
  Abort errorMessageAtTheTop & vbCr & vbCr & _
      GetMessage( "Error code:", _
                  "Fehlercode:", _
                  "Código de error:" ) & _
      " " & errorInfoAtTheBottom(0) & ", hex " & Hex( errorInfoAtTheBottom(0) ) & _
      vbCr & vbCr & _
      GetMessage( "Error description:", _
                  "Fehlerbeschreibung:", _
                  "Descripción del error:" ) & _
      " " & errorInfoAtTheBottom(1)
  
End Function


Function DeleteFileIfExists ( filename )

  if not objFSO.FileExists( filename ) then
    exit function
  end if

  On Error Resume Next

  objFSO.DeleteFile( filename )
  
  dim errorInfo
  errorInfo = Array( Err.Number, Err.Description )
  
  On Error Goto 0

  if errorInfo(0) <> 0 then
    AbortWithErrorInfo GetMessage( "Error deleting file:", _
                                   "Fehler beim Löschen der Datei:", _
                                   "Error al borrar el archivo:" ) & _
                       vbCr & vbCr & filename, _
                       errorInfo
  end if

End Function


Function RunExternalCommand ( cmd, shouldWaitForChildToExit )

  const activateAndDisplayTheWindow = 1

  dim waitFlag
  if shouldWaitForChildToExit then
    waitFlag = true
  else
    waitFlag = false
  end if

  On Error Resume Next

  dim runRet
  runRet = objShell.Run( cmd, activateAndDisplayTheWindow, waitFlag )
  
  dim errFromRun
  errFromRun = Array( Err.Number, Err.Description )
 
  On Error Goto 0

  if errFromRun(0) <> 0 then
    AbortWithErrorInfo GetMessage( "Error running command:", _
                                   "Fehler beim Ausführen des Kommandos:", _
                                   "Error durante la ejecución del comando:" ) & _
                       vbCr & vbCr & cmd, _
                       errFromRun
  end if

  ' If shouldWaitForChildToExit is true, then the exit code from objShell.Run() is always 0.
  if shouldWaitForChildToExit and runRet <> 0 then

    Abort GetMessage( "Error running command:", _
                      "Fehler beim Ausführen des Kommandos:", _
                      "Error durante la ejecución del comando:" ) & _
          vbCr & vbCr & cmd & vbCr & vbCr & _
          GetMessage( "Process exit code: ", _
                      "Prozessbeendigungscode: ", _
                      "Código de salida del proceso: " ) & _
          runRet & ", hex " & Hex( runRet )

  end if

End Function


' ------ Entry point (only by convention) ------

dim args
set args = WScript.Arguments

if args.length = 0 then
  Abort GetMessage( "Wrong number of command-line arguments. Please specify a file to process.", _
                    "Falsche Anzahl von Befehlszeilenargumenten. Bitte geben Sie eine zu verarbeitende Datei an.", _
                    "Número incorrecto de argumentos de línea de comandos. Especifique un archivo a procesar." )
elseif args.length <> 1 then
  Abort GetMessage( "Wrong number of command-line arguments. This script can only process one file at a time.", _
                    "Falsche Anzahl von Befehlszeilenargumenten. Dieses Skript kann nur eine Datei auf einmal verarbeiten.", _
                    "Número incorrecto de argumentos de línea de comandos. Este programa solamente puede procesar un archivo a la vez." )
end if

dim srcFilename
srcFilename = args( 0 )

dim objShell
set objShell = WScript.CreateObject( "WScript.Shell" )

dim objFSO
set objFSO = CreateObject( "Scripting.FileSystemObject" )

dim srcFilenameAbs
srcFilenameAbs = objFSO.GetAbsolutePathName( srcFilename )

if not objFSO.FileExists( srcFilenameAbs ) then
  Abort GetMessage( "File does not exist:", _
                    "Die Datei existiert nicht:", _
                    "El archivo no existe:" ) & _
                    vbCr & vbCr & srcFilenameAbs
end if


' Use your own PDF file as background image (typically a letterhead) here.
const backgroundFilename = "C:\full\path\to\Letterhead.pdf"


if not objFSO.FileExists( backgroundFilename ) then
  Abort GetMessage( "File does not exist:", _
                    "Die Datei existiert nicht:", _
                    "El archivo no existe:" ) & _
                    vbCr & vbCr & backgroundFilename
end if


dim objFile
set objFile = objFSO.GetFile( srcFilenameAbs )

dim fileExtensionInUppercase
fileExtensionInUppercase = UCase( objFSO.GetExtensionName( objFile ) )

if  not ( fileExtensionInUppercase = "DOC" ) and _
    not ( fileExtensionInUppercase = "DOCX" ) then
  Abort GetMessage( "The given file is not a Microsoft Word document:", _
                    "Die angegebene Datei ist kein Microsoft Word Dokument:", _
                    "El archivo proporcionado no es un documento de Microsoft Word:" ) & _
        vbCr & vbCr & srcFilename
end if

' Here you can set your own suffix.
dim processedFilenameSuffix
processedFilenameSuffix = GetMessage( "-WithLetterhead", "-MitBriefkopf", "-ConMembrete" )

dim pdfFilename
pdfFilename = objFSO.BuildPath( objFSO.GetParentFolderName( objFile ), _
                                objFSO.GetBaseName( objFile ) & "." & "pdf" )
dim pdfWithBackgroundFilename
pdfWithBackgroundFilename = objFSO.BuildPath( objFSO.GetParentFolderName( objFile ), _
                                              objFSO.GetBaseName( objFile ) & processedFilenameSuffix & "." & "pdf" )

' Delete the target files from this script beforehand, so that we can generate a more user-friendly
' error message if it fails.
DeleteFileIfExists pdfFilename
DeleteFileIfExists pdfWithBackgroundFilename

dim wordApp
dim wordDoc

On Error Resume Next
set wordApp = GetObject(, "Word.Application")
On Error GoTo 0

dim didWeStartMicrosoftWord
didWeStartMicrosoftWord = false

if IsEmpty( wordApp ) then
  Set wordapp = CreateObject("Word.application")
  didWeStartMicrosoftWord = true

  ' If Microsoft Word 2010 is not visible, problems arise:
  ' - You easily get orphaned WinWord.exe processes that you have to manually kill
  '   with the Task Manager.
  ' - Conversion fails, or you get a dialog prompt that does not come on top
  '   of other windows.
  wordapp.Visible = True
end if

On Error Resume Next
set wordDoc = wordApp.Documents( srcFilenameAbs )
On Error GoTo 0

dim didWeOpenTheDocument
didWeOpenTheDocument = false

if IsEmpty( wordDoc ) then
  set wordDoc = wordapp.documents.open( srcFilenameAbs )
  didWeOpenTheDocument = true
end if

if wordDoc.Saved = false then
  Abort GetMessage( "The given document has been modified but not yet saved.", _
                    "Die angegebene Datei wurde verändert aber noch nicht gespeichert.", _
                    "El archivo proporcionado ha sido modificado pero todavía no se ha guardado." )
end if


' This is how you check that the top margin is not too small.
dim sec
for each sec in wordDoc.Sections
  if wordApp.PointsToCentimeters( sec.PageSetup.TopMargin ) < 2 then
    Abort "The top margin is too small."
  end if
next


' The documents can use relative file paths in some INCLUDETEXT fields.
' Using relative file paths is known to be tricky, see for example here for more information:
'   https://www.askwoody.com/forums/topic/word-fields-and-relative-paths-to-external-files/
' Set the base dir before updating the INCLUDETEXT fields.

if true then

  ' The following code uses a custom property.
  ' The INCLUDETEXT field in a document looks like this:
  '   Use Ctrl+F9 to insert the nested DOCPROPERTY field below.
  ' { INCLUDETEXT "{ DOCPROPERTY IncludeTextDir }Some.doc" }

  const IncludeTextDirPropName = "IncludeTextDir"

  const msoPropertyTypeString = 4

  ' Watch out: The documents expect a trailing \\ in the custom property.
  const NewValueForIncludeTextDirProp = "C:\Some\Path\\"

  ' If the property already exists, method Add would fail. So we need to check first whether it exists.

  dim includeTextDirProperty

  ' I could not find a way to cleanly check whether a particular property exists.
  ' Therefore, try to locate the property, and if it fails in any way,
  ' we assume that the property does not exist.
  On Error Resume Next
  includeTextDirProperty = wordDoc.CustomDocumentProperties.Item( IncludeTextDirPropName )
  On Error GoTo 0

  if IsEmpty( includeTextDirProperty ) then
    wordDoc.CustomDocumentProperties.Add IncludeTextDirPropName, False, msoPropertyTypeString, NewValueForIncludeTextDirProp
  else
    ' I cannot use here the found includeTextDirProperty object. I do not know why.
    ' So we have to look the property up again.
    wordDoc.CustomDocumentProperties.Item( IncludeTextDirPropName ).Value = NewValueForIncludeTextDirProp
  end if

else

  ' The following code uses the standard "hyperlink base" property,
  ' but I could not make it work, Microsoft Word did not find the files when I tried using it.

  const wdPropertyHyperlinkBase = 29

  ' Warning: Make sure there is no trailing backslash ('\') character.
  wordDoc.BuiltInDocumentProperties(wdPropertyHyperlinkBase) = "C:\Some\Path"

end if


' Before generating a PDF we should update all fields.
' In my Word 2010 I have option "Update fields before printing" turned on. However,
' when generating a PDF, Word still does not update fields like a table of contents.


' Update all the INCLUDETEXT fields before updating the Table of Contents. Otherwise, the section titles
' and the page numbers in the Table of Contents may not get updated properly.
const wdFieldIncludeText = 68
dim fld  ' As Field
for each fld In wordDoc.Fields 
  if fld.Type = wdFieldIncludeText then
    ' UpdateSource is the opposite operation: it updates the source document
    ' with the changes made in this document.
    if fld.Update <> True then
      ' If you update the fields manually with F9, you get to see the error messages
      ' indicating what went wrong. I do not know yet how to achieve that here.
      ' But at least we indicate which field failed.
      Abort "Error updating field " & Chr(34) & fld.Code.Text & Chr(34) & "."
    end if
  end if
Next


' wordDoc.Fields.Update does not seem to do much at all, so the code around still updates
' some fields programmatically. Nevertheless, keep trying to update all fields in this way too.
if wordDoc.Fields.Update <> 0 then
  Abort "Error calling 'wordDoc.Fields.Update'."
end if

' Only tables of contents are updated here. More field types could be updated here.

dim toc
for each toc in wordDoc.TablesOfContents
  toc.Update
next


const addToRecentFiles = false
const wdFormatPDF = 17

wordDoc.SaveAs2  pdfFilename, wdFormatPDF,,, addToRecentFiles

if didWeOpenTheDocument then
  ' Generating a PDF is like printing the document. When printing a document, Microsoft Word repaginates
  ' it and updates all its fields and the "last printed on" timestamp. Afterwards, the document is
  ' considered to have changed. If we just close it now, the user will be prompted
  ' whether to save changes, which can be rather confusing, for the user has no notion
  ' that he changed anything. Therefore, discard any changes at this point.
  const WdDoNotSaveChanges = 0
  wordDoc.close WdDoNotSaveChanges
else
  ' We are assuming here that the user is editing the document and used a button to call this script.
  ' Save the document now. Otherwise, when the user closes the document, he will be prompted.
  ' Alternatively, we could try to undo all changes that this script made to the document.
  wordDoc.Save
end if

if didWeStartMicrosoftWord and wordApp.Documents.Count = 0 then
  wordApp.Quit
end if


' background = place the other PDF in the background (underneath)
' stamp      = place the other PDF in the foreground (on top)
const pdftkOperation = "background"

dim cmd
cmd = "pdftk  """ & pdfFilename & """  " & pdftkOperation & " """ & backgroundFilename & """  output """ & pdfWithBackgroundFilename & """"

RunExternalCommand cmd, true


' You do not normally need to keep the first generated PDF file
' without the background, so delete it.
if true then
  objFSO.DeleteFile( pdfFilename )
end if


' Open a dialog box and show the filenames of the just-created files.
if false then
  MsgBox GetMessage( "Files created:", _
                     "Erstellte Dateien:", _
                     "Archivos creados:" ) & _
         vbCr & vbCr & pdfFilename & vbCr & pdfWithBackgroundFilename, _
         vbOkOnly + vbInformation, _
         GetMessage( "Files created", "Erstellte Dateien", "Archivos creados" )
end if

' Open the generated PDF file with the background using the system's default PDF file viewer.
if true then
  const activateAndDisplayTheWindow = 1
  const waitFlag = false
  objShell.Run """" & pdfWithBackgroundFilename & """", activateAndDisplayTheWindow, waitFlag
end if

WScript.Quit( 0 )
