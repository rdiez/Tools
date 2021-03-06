
' This script prompts the user for a filename using Windows' standard "file open" dialog box.
'
' The chosen filename is printed to stdout, so that a bash script running in Cygwin
' can easily capture it. The caller has to strip the new-line character sequence (CR, LF)
' printed at the end of the filename. An empty filename (nothing is printed) means that
' the user cancelled the dialog box.
'
' Command-line arguments are:
' - The title for the dialog box.
' - Initial directory for the dialog box.
'   Leave empty to use the current directory. However, due to some heuristic implemented in Windows 7,
'   this will probably open the last directory the user has seen, instead of the current one.
' - File type description like "Text files".
' - A single file extension like "txt" for text files.
'
' This script only runs with "cscript", the command-line version of "wscript".
'
' See PromptForFileExample.sh for an example on how to call this script from Cygwin.
'
' Script version 1.03.
'
' Copyright (c) 2016-2018 R. Diez - Licensed under the GNU AGPLv3

Option Explicit


' Set here the user language to use. See GetMessage() for a list of language codes available.
const language = "eng"

Function GetMessage ( msgEng, msgDeu, msgSpa )

  Select Case language
    Case "eng"  GetMessage = msgEng
    Case "deu"  GetMessage = msgDeu
    Case "spa"  GetMessage = msgSpa
    Case Else   GetMessage = msgEng
      ' We cannot use objFSO.GetStandardStream(2).WriteLine() below in order to write to stderr,
      ' because that method is not affected by cscript's command-line switch //U, so it never outputs in Unicode.
      WScript.Echo "Invalid language."
      WScript.Quit( 1 )
  End Select

End Function


Function Abort ( errorMessage )
  ' We cannot use objFSO.GetStandardStream(2).WriteLine() below in order to write to stderr,
  ' because that method is not affected by cscript's command-line switch //U, so it never outputs in Unicode.
  WScript.Echo GetMessage( "Error", "Fehler", "Error" ) & ": " & errorMessage
  WScript.Quit( 1 )
End Function


Function GetFileDlgEx ( sIniDir, sFilter, sTitle )
  ' Class ID "3050f4e1-98b5-11cf-bb82-00aa00bdce0b" below belongs to the HtmlDlgHelper class,
  ' which is an internal, undocumented IE class that we actually should not be using here.
  dim oDlg
  set oDlg = objShell.Exec( "mshta.exe ""about:<object id=d classid=clsid:3050f4e1-98b5-11cf-bb82-00aa00bdce0b></object><script>moveTo(0,-9999);eval(new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(0).Read("&Len(sIniDir)+Len(sFilter)+Len(sTitle)+41&"));function window.onload(){var p=/[^\0]*/;new ActiveXObject('Scripting.FileSystemObject').GetStandardStream(1).Write(p.exec(d.object.openfiledlg(iniDir,null,filter,title)));close();}</script><hta:application showintaskbar=no />""")

  dim str
  str = "var iniDir='" & sIniDir & "';var filter='" & sFilter & "';var title='" & sTitle & "';"
  oDlg.StdIn.Write str

  GetFileDlgEx = oDlg.StdOut.ReadAll
End Function


const StringEndsWith_BinaryCompare = 0  ' Case sensitive.
const StringEndsWith_TextCompare   = 1  ' Case insensitive.

Public Function StringEndsWith ( str, suffix, compareMethod )

  StringEndsWith = ( 0 = StrComp( right( str, len( suffix ) ), suffix, compareMethod ) )

End Function


' ------ Entry point ------

dim objFSO
set objFSO = CreateObject( "Scripting.FileSystemObject" )

' This is often useful for test purposes.
if false then
  WScript.Echo "Simulated filename in .vbs script: aäb.txt"
  WScript.Quit( 0 )
end if

' This is often useful for test purposes.
if false then
  Abort "Simulated error in .vbs script, line 1: aäb" & vbCrLf  & "Simulated error in .vbs script, line 2: añb"
end if


dim args
set args = WScript.Arguments

if args.length <> 4 then
  Abort GetMessage( "Wrong number of command-line arguments.", _
                    "Falsche Anzahl von Befehlszeilenargumenten.", _
                    "Número incorrecto de argumentos de línea de comandos." )
end if

dim title
title = args( 0 )

dim initialDirectory
initialDirectory = args( 1 )

dim fileTypeDescription
fileTypeDescription = args( 2 )

dim fileExtension
fileExtension = args( 3 )


' Check whether the directory exists beforehand. This allows us
' to generate a more user-friendly error message.
if initialDirectory <> "" and not objFSO.FolderExists( initialDirectory ) Then
  Abort GetMessage( "The directory does not exist", _
                    "Das Verzeichnis existiert nicht", _
                    "El directorio no existe" ) & _
        ": " & initialDirectory
end if


dim objShell
set objShell = WScript.CreateObject( "WScript.Shell" )

' The initial filename cannot be empty. Otherwise, the last directory component of the path
' is taken as the filename.
' If you specify "*.extension", then "extension" is removed, and "*" makes all filetypes show up.
' If you specify something long like "Please type here the filename", then
' the text field scrolls to the right, at least on Windows 7, and you get "ere the filename" on the screen,
' which is rather confusing, until you eventually realise that you need to scroll left.
' I tried to avoid passing the initial directory by changing the current directory before running mshta.exe
' to no avail.

dim initialFilename
initialFilename = GetMessage( "Filename", _
                              "Dateiname", _
                              "Archivo" )

dim initialDirectoryAndFilename
if initialFilename = "" then
  initialDirectoryAndFilename = initialFilename & "." & fileExtension
else
  dim slashStr
  if StringEndsWith( initialDirectory, "\", StringEndsWith_BinaryCompare ) then
    slashStr = ""
  else
    slashStr = "\"
  end if

  initialDirectoryAndFilename = initialDirectory & slashStr & initialFilename & "." & fileExtension
end if

dim sFilter
sFilter = fileTypeDescription & " (*." & fileExtension & ")|*." & fileExtension

dim chosenFilename
chosenFilename = GetFileDlgEx( Replace( initialDirectoryAndFilename, "\","\\" ), sFilter, title )

if chosenFilename = "" then
  ' WScript.echo "Cancelled!"
  ' We could return here a different exit code. However, not printing anything
  ' means "cancelled", and cancelling is not really an error.
  WScript.Quit( 0 )
end if


' We cannot use objFSO.GetStandardStream(1).Write() below in order to write to stdout,
' because that method is not affected by cscript's command-line switch //U, so it never outputs in Unicode.
' Unfortunately, the caller has to strip the new-line charater at the end, as
' there is no way to prevent Echo from writing one after the filename.
WScript.Echo chosenFilename

WScript.Quit( 0 )
