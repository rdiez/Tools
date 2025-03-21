
' This script takes a PDF filename and generates a second PDF file with extra content
' in the background (typically a letterhead or watermark) on all pages.
'
' The extra content for the background comes from a third, existing PDF file. The path to that
' background PDF file is hard-coded in this script.
'
' You need the pdftk tool installed on your system. pdftk is free software licensed under the GPL.
' Download pdftk for Windows from www.pdftk.com / www.pdflabs.com
' The download package you need for the command-line tool is called "PDFtk Server".
' If you use Chocolatey, the package name is 'pdftk-server'.
'
' See companion script ConvertWordToPdfWithBackground.vbs for instructions
' about how to install this script for convenient usage.
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

if not ( fileExtensionInUppercase = "PDF" ) then
  Abort GetMessage( "The given file is not a PDF document:", _
                    "Die angegebene Datei ist kein PDF Dokument:", _
                    "El archivo proporcionado no es un documento PDF:" ) & _
        vbCr & vbCr & srcFilename
end if

' Here you can set your own suffix.
dim processedFilenameSuffix
processedFilenameSuffix = GetMessage( "-WithLetterhead", "-MitBriefkopf", "-ConMembrete" )

dim pdfWithBackgroundFilename
pdfWithBackgroundFilename = objFSO.BuildPath( objFSO.GetParentFolderName( objFile ), _
                                              objFSO.GetBaseName( objFile ) & processedFilenameSuffix & "." & "pdf" )

' Delete the target files from this script beforehand, so that we can generate a more user-friendly
' error message if it fails.
DeleteFileIfExists pdfWithBackgroundFilename


' background = place the other PDF in the background (underneath)
' stamp      = place the other PDF in the foreground (on top)
const pdftkOperation = "background"

dim cmd
cmd = "pdftk  """ & srcFilenameAbs & """  " & pdftkOperation & " """ & backgroundFilename & """  output """ & pdfWithBackgroundFilename & """"

RunExternalCommand cmd, true


' If you do not want to keep the original PDF file, you can delete it here.
if false then
  objFSO.DeleteFile( srcFilenameAbs )
end if


' Open a dialog box and show the filename of the just-created file.
if false then
  MsgBox GetMessage( "File created:", _
                     "Erstellte Datei:", _
                     "Archivo creado:" ) & _
         vbCr & vbCr & pdfWithBackgroundFilename, _
         vbOkOnly + vbInformation, _
         GetMessage( "File created", "Erstellte Datei", "Archivo creado" )
end if

' Open the generated PDF file with the background using the system's default PDF file viewer.
if true then
  const activateAndDisplayTheWindow = 1
  const waitFlag = false
  objShell.Run """" & pdfWithBackgroundFilename & """", activateAndDisplayTheWindow, waitFlag
end if

WScript.Quit( 0 )
