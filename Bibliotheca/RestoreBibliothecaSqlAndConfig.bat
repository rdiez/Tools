@echo off

rem  Backup restore script for OCLC BIBLIOTHECAplus.
rem  Script version 1.00.
rem  Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3
rem
rem  See the companion backup script for more information.

rem  Begin localisation of environment variables,
rem  always a good practice with batch scripts.
setlocal

rem  Without EnableDelayedExpansion, ERRORLEVEL does not work inside IF statements.
setlocal EnableDelayedExpansion


set WHERE_THIS_SCRIPT_IS=%CD%

set BIBLIOTHECA_INSTALLATION_DIR=C:\Program Files (x86)\BOND

set BACKUP_SOURCE_DIR=%WHERE_THIS_SCRIPT_IS%\Bibliotheca SQL and Config Backup


pushd "%BACKUP_SOURCE_DIR%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot change to directory "%BACKUP_SOURCE_DIR%".
  exit /b %ERRORLEVEL%
)


rem  ------ Restore the SQL database ------

set SQL_TOOLS_DIR=%BIBLIOTHECA_INSTALLATION_DIR%\BIBLIO_SERVER\SQLBase

echo Running the SQL restore script...

"%SQL_TOOLS_DIR%\SQLNTTLK.EXE"  bat  noconnect  "input=%WHERE_THIS_SCRIPT_IS%\restore-database.sql"


rem  If an SQL command fails, SQLNTTLK.EXE prints an error message, but it carries on, effectively ignoring
rem  the error. Therefore, the user is forced to look at the log manually at the end.

rem Some people recommend doing a "check database;" or a "update statistics on database;" afterwards.

popd


rem  ------ Restore the 'BIBLIOTHECA2000' dir ------

rem  Directory C:\ProgramData\BOND\BIBLIOTHECA2000 has the following files:
rem  - winoeb.ini
rem  - winoebp.ini

set INI_FILES_SRC_DIR=%BACKUP_SOURCE_DIR%\BIBLIOTHECA2000

copy  /B  "%INI_FILES_SRC_DIR%\*"  "%ProgramData%\BOND\BIBLIOTHECA2000\*"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy the files from "%INI_FILES_SRC_DIR%\"
  exit /b %ERRORLEVEL%
)


rem  ------ Restore the 'Templates' dir ------
rem  Some files should always be skipped, but they should already have been renamed by the backup script,
rem  so that they would not overwrite the currently-installed files. Nevertheless, we should
rem  still skip copying such renamed files.
rem  In any case, I am not yet comfortable with a full restore for this directory. I would investigation a little more first.
rem
rem  xcopy  /E /I  "%ProgramFiles(x86)%\BOND\BIBLIO_SERVER\Templates"  "%BACKUP_OUTPUT_DIR%\Templates"

rem  if !ERRORLEVEL! NEQ 0 (
rem    echo Cannot copy the files from "%ProgramFiles(x86)%\BOND\BIBLIO_SERVER\Templates\"
rem    exit /b %ERRORLEVEL%
rem  )


echo.
echo Bibliotheca data restore finished.
echo.
echo Unfortunately, you need to manually check in the log text above
echo whether some of the SQL restore commands failed.
echo.
echo Afterwards, there is an option in Bibliotheca to check the database:
echo Menuepunkt Systempflege -> Datenbank -> Datenbankpflege -> Registerkarte "Pruefen", "Gesamtpruefung".
