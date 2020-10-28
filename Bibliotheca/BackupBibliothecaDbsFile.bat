@echo off

rem  The other backup script generates a .sql backup file and is the best way
rem  to backup the database. But, just in case, we also backup
rem  the raw binary .dbs file with this script.
rem
rem  The drawback is that this script needs to temporarily stop the database service.
rem  If the Bibliotheca application is currently running, it will no longer word afterwards, 
rem  even if the service has been started again. The next attempt to access any data
rem  inside the application will fail with an error message, and the user gets
rem  a prompt with the option to stop the application.
rem
rem  Note that you need elevated privileges because this script stops and starts services.
rem
rem  Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3


rem  Begin localisation of environment variables,
rem  always a good practice with batch scripts.
setlocal

rem  Without EnableDelayedExpansion, ERRORLEVEL does not work inside IF statements.
setlocal EnableDelayedExpansion


set WHERE_THIS_SCRIPT_IS=%CD%

set BIBLIOTHECA_INSTALLATION_DIR=C:\Program Files (x86)\BOND

set BIBLIO_DIR=%BIBLIOTHECA_INSTALLATION_DIR%\BIBLIO_SERVER\SQLBase\BIBLIO

set BACKUP_OUTPUT_DIR=%WHERE_THIS_SCRIPT_IS%\Bibliotheca DBS Backup


rem  ------ Check for elevated privileges ------

fsutil dirty query %SYSTEMDRIVE% >nul
if !ERRORLEVEL! NEQ 0 (
   echo This script needs elevated privileges because of the "net stop" command.
   exit /b 1
) 


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
    echo Cannot delete existing directory "%BACKUP_OUTPUT_DIR%"
    exit /b 1
  )
)


echo Creating directory "%BACKUP_OUTPUT_DIR%"...

md "%BACKUP_OUTPUT_DIR%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot create directory "%BACKUP_OUTPUT_DIR%".
  exit /b %ERRORLEVEL%
)


rem  ------ Stop the service ------

set DB_SERVICE_NAME=Unify SQLBase 11.5

net stop "%DB_SERVICE_NAME%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot stop service "%DB_SERVICE_NAME%".
  exit /b %ERRORLEVEL%
)

rem  ------ Backup the .DBS file and anything next to it ------

xcopy  /E /I  "%BIBLIO_DIR%"  "%BACKUP_OUTPUT_DIR%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy the files from "%BIBLIO_DIR%\".
  exit /b %ERRORLEVEL%
)


rem  ------ Restart the service ------

net start "%DB_SERVICE_NAME%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot start service "%DB_SERVICE_NAME%".
  exit /b %ERRORLEVEL%
)


rem  ------ Final message ------

echo.
echo Bibliotheca DBS file backup succeeded. Destination directory:
echo   %BACKUP_OUTPUT_DIR%
