@echo off

rem  Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3

rem  Begin localisation of environment variables,
rem  always a good practice with batch scripts.
setlocal

rem  Without EnableDelayedExpansion, ERRORLEVEL does not work inside IF statements.
setlocal EnableDelayedExpansion

set WHERE_THIS_SCRIPT_IS=%CD%

set TARBALL_DIRNAME=Tarball
set BACKUP_OUTPUT_DIR=%WHERE_THIS_SCRIPT_IS%\%TARBALL_DIRNAME%

set ADDITIONAL_FILES_TO_BACKUP_1=C:\TestDirRdiez1
set ADDITIONAL_FILES_TO_BACKUP_2=C:\TestDirRdiez2


rem  ------ Check for elevated privileges ------
rem
rem  Check for elevated privileges before checking for TARBALL_PASSWORD.
rem  Otherwise, the user will probably have to set TARBALL_PASSWORD again.

fsutil dirty query %SYSTEMDRIVE% >nul
if !ERRORLEVEL! NEQ 0 (
   echo This script needs elevated privileges, because it will later run script BibliothecaDbsFileBackup.bat .
   exit /b 1
) 


rem  ------ Check for the tarball password environment variable ------

if not defined TARBALL_PASSWORD (
  echo Please set environment variable TARBALL_PASSWORD beforehand. For example:
  echo SET TARBALL_PASSWORD=secret
  echo Do not use spaces or any characters that might be interpreted by CMD.exe .
  exit /b 1
)


rem  ------ Build the tarball filename ------

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I

set TIMESTAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%--%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%

set TARBALL_FILENAME=LibraryBackup-%TIMESTAMP%.7z


rem  ------ Create the output backup directory ------

if exist "%BACKUP_OUTPUT_DIR%" (

  echo Deleting old directory "%BACKUP_OUTPUT_DIR%"...

  rem  Command 'rd' does not set ERRORLEVEL, and in some cases, not even a non-zero process exit code.
  rem  So the only reliable solution is to check again if the directory still exists.

  rd /s /q "%BACKUP_OUTPUT_DIR%"

  rem  Sometimes Windows does not delete the directory immediately.
  rem  It maybe because you have a File Explorer window showing it.
  rem  A short pause usually does the trick.
  if exist "%BACKUP_OUTPUT_DIR%" (
    echo The old directory is still there, doing a short wait just in case...
    rem  We are using ping instead of "sleep 1", which we would have to get from the Windows Resource Kit.
    rem  ping -n 2 makes a pause of 1 second.
    ping -n 2 127.0.0.1 >nul 
  )
  
  if exist "%BACKUP_OUTPUT_DIR%" (
    echo Cannot delete existing directory "%BACKUP_OUTPUT_DIR%".
    exit /b 1
  )
)


echo Creating directory "%BACKUP_OUTPUT_DIR%"...

md "%BACKUP_OUTPUT_DIR%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot create directory "%BACKUP_OUTPUT_DIR%".
  exit /b %ERRORLEVEL%
)


rem  ------ Run all backup scripts ------

call BackupBibliothecaDbsFile.bat

if !ERRORLEVEL! NEQ 0 (
  echo Error in BibliothecaDbsFileBackup.bat .
  exit /b %ERRORLEVEL%
)


call BackupBibliothecaSqlAndConfig.bat

if !ERRORLEVEL! NEQ 0 (
  echo Error in BibliothecaSqlAndConfigBackup.bat .
  exit /b %ERRORLEVEL%
)


rem  ------ Create the tarball ------

rem  The ^ in the 7z command below is to escape ! because of EnableDelayedExpansion.

rem  For zip, which does not support multithreading, use:
rem    set COMPRESSION_OPTIONS=-m0=Deflate -mx1
rem  But from experience, LZMA2 with level 1 compresses much more and is faster due to multithreading.
set COMPRESSION_OPTIONS=-mx=1

"C:\Program Files\7-Zip\7z.exe"  a  -t7z  %COMPRESSION_OPTIONS%  -mmt  -ms  -p%TARBALL_PASSWORD%  -mhe=on  "-x^!%TARBALL_DIRNAME%" -- "%BACKUP_OUTPUT_DIR%\%TARBALL_FILENAME%"  *  "%ADDITIONAL_FILES_TO_BACKUP_1%"  "%ADDITIONAL_FILES_TO_BACKUP_2%"

if !ERRORLEVEL! NEQ 0 (
  echo Error creating the tarball .
  exit /b %ERRORLEVEL%
)

rem  For extra safety, we could use here a tool like par2 in order to add redundant data.


rem  ------ Final message ------

echo.
echo Resulting tarball:
echo   %BACKUP_OUTPUT_DIR%\%TARBALL_FILENAME%
