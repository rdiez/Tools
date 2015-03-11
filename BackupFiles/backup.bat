@echo off

rem  This is the script template I normally use to back up my files under Windows.
rem  See the Linux sibling script 'backup.sh' for more information.
rem
rem  Copyright (c) 2015 R. Diez
rem  Licensed under the GNU Affero General Public License version 3.

set TARBALL_FILENAME=MyBackupFiles.7z

set TOOL_7Z="%ProgramFiles%\7-Zip\7z.exe"
set TOOL_PAR2="par2.exe"


if exist %TOOL_7Z% goto carryOn2a
WHERE %TOOL_7Z% 2>NUL
IF %ERRORLEVEL% EQU 0 goto carryOn2a
echo Error: Tool %TOOL_7Z% not found.
echo You can download it from www.7-zip.org .
exit /b 1
:carryOn2a

if exist %TOOL_PAR2% goto carryOn2b
WHERE %TOOL_PAR2% 2>NUL
IF %ERRORLEVEL% EQU 0 goto carryOn2b
echo Error: Tool %TOOL_PAR2% not found.
echo You can download it from sourceforge.net/projects/parchive, look for 'par2cmdline'.
exit /b 1
:carryOn2b


rem  Delete any previous backup files, which is convenient if you modify and re-run this script.
if exist "%TARBALL_FILENAME%.*" goto filesExist
goto carryOn3
:filesExist
echo Deleting existing backup files...
del "%TARBALL_FILENAME%.*"
:carryOn3


rem  About excluding "$RECYCLE.BIN" and "System Volume Information" below: I do not know why 7z
rem  has to scan the drive's root directory. Of course, it will always fail to scan those 2,
rem  as normal users do not have permissions to get inside them.
rem
rem  Avoid using 7z's command-line option '-r'. According to the man page:
rem  "CAUTION: this flag does not do what you think, avoid using it"
rem
rem 7z exclusion syntax examples:
rem
rem   - Exclude a particular subdirectory:
rem     -x!dir1/subdir1
rem
rem     Note that "dir1" must be at the backup's root directory.
rem
rem   - Exclude all "Tmp" subdirs:
rem     -xr!Tmp
rem
rem   - Exclude all *.bak files (by extension):
rem     -xr!*.bak
rem
rem  When testing this script, you may want to replace switch -mx1 with -mx0 (no compression, much faster).
rem  You may also want to temporarily remove the -p (password) switch.

start "" /BELOWNORMAL /B /WAIT ^
  %TOOL_7Z% a -t7z "%TARBALL_FILENAME%" -m0=Deflate -mx1 -mmt -ms -mhe=on -v2g -p ^
  ^
  "-x!dirToBackup1\skipThisParticularDir\Subdir1" ^
  "-x!dirToBackup1\skipThisParticularDir\Subdir2" ^
  ^
    "-xr!skipAllSubdirsWithThisName1" ^
    "-xr!skipAllSubdirsWithThisName2" ^
  ^
    "-xr!*.skipAllFilesWithThisExtension1" ^
    "-xr!*.skipAllFilesWithThisExtension2" ^
  ^
  "-x!$RECYCLE.BIN" ^
  "-x!System Volume Information" ^
  ^
  "c:\dirToBackup1" ^
  "c:\dirToBackup2"


set EXIT_CODE=%ERRORLEVEL%
IF %EXIT_CODE% NEQ 0 GOTO CommandFailed

echo Building redundant records...
set REDUNDANCY_PERCENTAGE=1
start "" /BELOWNORMAL /B /WAIT ^
  %TOOL_PAR2%  create -q -r%REDUNDANCY_PERCENTAGE% "%TARBALL_FILENAME%.par2" "%TARBALL_FILENAME%.*"
set EXIT_CODE=%ERRORLEVEL%


rem Notify that we have finished.

set VBS_FILENAME=%TARBALL_FILENAME%.notification-dialog.vbs
echo Option Explicit>%VBS_FILENAME%

IF %EXIT_CODE% EQU 0 GOTO carryOn4
:CommandFailed
echo Error: The command failed with error code %EXIT_CODE%.
echo MsgBox "The command failed with exit code %EXIT_CODE%.", vbOKOnly, "Background cmd FAILED">>%VBS_FILENAME%
GOTO carryOn5
:carryOn4
echo MsgBox "The command finished successfully.", vbOKOnly, "Background cmd OK">>%VBS_FILENAME%
:carryOn5

echo WScript.Quit(0)>>%VBS_FILENAME%
echo Waiting for the user to close the notification dialog window...
cscript //nologo %VBS_FILENAME%
IF %EXIT_CODE% EQU 0 echo Finished creating backup.
IF %EXIT_CODE% NEQ 0 echo Finished with error.
exit /b %EXIT_CODE%
