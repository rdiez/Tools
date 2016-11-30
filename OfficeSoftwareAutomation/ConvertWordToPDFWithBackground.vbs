
' This script converts a Microsoft Word document to a PDF file, and then
' generates a second PDF file with extra content in the background (typically a letterhead
' or watermark) on all pages.
'
' The extra content for the background comes from a third, existing PDF file. The path to that
' background PDF file is hard-coded in this script.
'
' It is best to install this kind of script in a fixed location for all users, like
' %APPDATA%\MyScripts or even somewhere global for all users, on the PC or on a file server.
'
' In order to add this script to Windows Explorer's "Send to" menu, place a shortcut to it
' in the following directory:
'   %APPDATA%\Microsoft\Windows\SendTo
' (or more correctly, to the folder pointed by the registry key
'  HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\SendTo )
'
' Alternatively, the user can drag a file with the mouse to this .vbs script file
' in order to start the conversion.
'
' You need the pdftk tool installed on your system. pdftk is free software licensed under the GPL.
' Download pdftk for Windows from www.pdftk.com / www.pdflabs.com
' The download package you need for the command-line tool is called "PDFtk Server".
'
' Copyright (c) 2016 R. Diez - Licensed under the GNU AGPLv3

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
      WScript.Quit( 0 )
  End Select

End Function


Function Abort ( errorMessage )
  MsgBox errorMessage, vbOkOnly + vbError, GetMessage( "Error", "Fehler", "Error" )
  WScript.Quit( 0 )
End Function


Function DeleteFileIfExists ( filename )

  if not objFSO.FileExists( filename ) Then
    exit function
  end if

  On Error Resume Next

  objFSO.DeleteFile( filename )

  if Err.Number <> 0 then
    Abort GetMessage( "Error deleting file:", _
                      "Fehler beim Löschen der Datei:", _
                      "Error al borrar el archivo:" ) & _
          vbCr & vbCr & filename & vbCr & vbCr & _
          GetMessage( "The error was:", _
                      "Der Fehler war:", _
                      "El error fue:" ) & _
          " " & Err.Description
  end if

  On Error Goto 0

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

  if Err.Number <> 0 then
    Abort GetMessage( "Error running command:", _
                      "Fehler beim Ausführen des Kommandos:", _
                      "Error durante la ejecución del comando:" ) & _
          vbCr & vbCr & cmd & vbCr & vbCr & _
          GetMessage( "The error was", _
                      "Der Fehler war:", _
                      "El error fue: " ) & _
          Err.Description & vbCr & vbCr & _
          GetMessage( "Error position: ", _
                      "Fehlerposition: ", _
                      "Posición del error: " )
  end if

  On Error Goto 0

  ' If shouldWaitForChildToExit is true, then the exit code from objShell.Run() is always 0.
  if shouldWaitForChildToExit and runRet <> 0 Then

    Abort GetMessage( "Error running command:", _
                      "Fehler beim Ausführen des Kommandos:", _
                      "Error durante la ejecución del comando:" ) & _
                      vbCr & vbCr & cmd & vbCr & vbCr & _
                      GetMessage( "Error code: ", _
                                  "Fehlercode: ", _
                                  "Código de error: " ) & _
                      runRet & ", hex " & Hex( runRet )
    WScript.Quit( runRet )
  End If

End Function


' ------ Entry point ------

Dim args
Set args = WScript.Arguments

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
Set objShell = WScript.CreateObject( "WScript.Shell" )

dim objFSO
set objFSO = CreateObject( "Scripting.FileSystemObject" )

dim srcFilenameAbs
srcFilenameAbs = objFSO.GetAbsolutePathName( srcFilename )

if not objFSO.FileExists( srcFilenameAbs ) Then
  Abort GetMessage( "File does not exist:", _
                    "Die Datei existiert nicht:", _
                    "El archivo no existe:" ) & _
                    vbCr & vbCr & srcFilenameAbs
end if


' Use your own PDF file as background image (typically a letterhead) here.
const backgroundFilename = "C:\full\path\to\Letterhead.pdf"

if not objFSO.FileExists( backgroundFilename ) Then
  Abort GetMessage( "File does not exist:", _
                    "Die Datei existiert nicht:", _
                    "El archivo no existe:" ) & _
                    vbCr & vbCr & backgroundFilename
end if


dim objFile
set objFile = objFSO.GetFile( srcFilenameAbs )

dim fileExtension
fileExtension = objFSO.GetExtensionName( objFile )

if  not ( fileExtension = "doc" ) and not ( fileExtension = "docx" ) then
  Abort GetMessage( "The given file is not a Microsoft Word document:", _
                    "Die angegebene Datei ist kein Microsoft Word Dokument", _
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

Dim wordApp
Dim wordDoc

On Error Resume Next
Set wordApp = GetObject(, "Word.Application")
On Error GoTo 0

dim didWeStartMicrosoftWord
didWeStartMicrosoftWord = false

if IsEmpty( wordApp ) Then
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
Set wordDoc = wordApp.Documents( srcFilenameAbs )
On Error GoTo 0

dim didWeOpenTheDocument
didWeOpenTheDocument = false

if IsEmpty( wordDoc ) Then
  Set wordDoc = wordapp.documents.open( srcFilenameAbs )
  didWeOpenTheDocument = true
end if

if wordDoc.Saved = false then
  Abort GetMessage( "The given document has been modified but not yet saved.", _
                    "Die angegebene Datei wurde verändert aber noch nicht gespeichert.", _
                    "El archivo proporcionado ha sido modificado pero todavía no se ha guardado." )
end if


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
end if

If didWeStartMicrosoftWord and wordApp.Documents.Count = 0 Then
  wordApp.Quit
End If


dim cmd
cmd = "pdftk  """ & pdfFilename & """ background """ & backgroundFilename & """ output """ & pdfWithBackgroundFilename & """"

RunExternalCommand cmd, true

MsgBox GetMessage( "Files created:", _
                   "Erstellte Dateien:", _
                   "Archivos creados:" ) & _
         vbCr & vbCr & pdfFilename & vbCr & pdfWithBackgroundFilename, _
       vbOkOnly + vbInformation, _
       GetMessage( "Files created", "Erstellte Dateien", "Archivos creados" )

WScript.Quit( 0 )
