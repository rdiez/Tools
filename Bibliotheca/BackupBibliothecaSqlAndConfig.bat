@echo off

rem  Backup script for OCLC BIBLIOTHECAplus.
rem  Script version 1.00.
rem  Copyright (c) 2020 R. Diez - Licensed under the GNU AGPLv3
rem
rem  Developed and tested against version Bibliotheca 8.1.2
rem  in a multiuser (Mehrplatz, MP) installation.
rem
rem  This script uses SQL command "unload database", which does not need stopping
rem  the database service "Unify SQLBase 11.5" (Gupta SQLBase) beforehand.
rem  Command "unload database" DATABASE writes a text file that contains the SQL
rem  statements required to create the database from scratch.
rem  This kind of backup is probably a better than backing up the raw binary dabase file called biblio.dbs .
rem  A binary file tends to be much more dependent on the exact version of the installed database manager.
rem
rem  Alternatively, you could use the "BACKUP SNAPSHOT" command, see the notes about
rem  "Logische Datensicherung als Dienst installieren" below.
rem
rem  In addition to the database, other configuration and template files are also backed up.

rem  Begin localisation of environment variables,
rem  always a good practice with batch scripts.
setlocal

rem  Without EnableDelayedExpansion, ERRORLEVEL does not work inside IF statements.
setlocal EnableDelayedExpansion


set WHERE_THIS_SCRIPT_IS=%CD%

set BIBLIOTHECA_INSTALLATION_DIR=C:\Program Files (x86)\BOND

set BIBLIOTHECA_CONFIG_DIR=%BIBLIOTHECA_INSTALLATION_DIR%\BIBLIO_SERVER\Config

set BACKUP_OUTPUT_DIR=%WHERE_THIS_SCRIPT_IS%\Bibliotheca SQL and Config Backup


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


rem  ------ Backup the SQL database ------

rem  During installation of Bibliotheca, there is the following option:
rem    "Logische Datensicherung als Dienst installieren"
rem  That installs a script that backs the database up in a similar, automatic way.
rem  Unfortunately, configuration files and templates are not included in that backup.
rem  From the documentation about restoring such a backup, it seems that
rem  it uses command "BACKUP SNAPSHOT". More research is needed.
rem
rem  I have tested with Bibliotheca 8.1.2, and there are 2 binary identical copies
rem  of SQLTALK.EXE at these locations:
rem
rem    C:\Program Files (x86)\BOND\BIBLIO_SERVER\SQLBase
rem    C:\Program Files (x86)\BOND\BIBLIO_SERVER\BIN\SQLTalk
rem
rem  There are also 2 binary identical copies of SQLNTTLK.EXE at these locations:
rem     C:\Program Files (x86)\BOND\BIBLIO_SERVER\SQLBase
rem     C:\Program Files (x86)\BOND\BIBLIO_SERVER\SQLBase\CLIENT  (but this one has sql.ini file next to it)
rem
rem  I am not sure which copies I should be using here. I am taking the "SQLBase" directory
rem  because it contains both tools, and because it also has one copy of sql.ini .

set SQL_TOOLS_DIR=%BIBLIOTHECA_INSTALLATION_DIR%\BIBLIO_SERVER\SQLBase


pushd "%BACKUP_OUTPUT_DIR%"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot change to directory "%BACKUP_OUTPUT_DIR%".
  exit /b %ERRORLEVEL%
)

echo Running the SQL backup script...

rem  We could specify the path to the sql.ini file with option "ini=sql.ini",
rem  but the SQLNTTLK.EXE seems to find a suitable one on its own.
rem  There are in fact 3 copies of sql.ini under C:\Program Files (x86)\BOND .
rem  If in doubt, we should probably use the one here:
rem    C:\Program Files (x86)\BOND\BIBLIO_SERVER\Config\sql.ini

"%SQL_TOOLS_DIR%\SQLNTTLK.EXE"  bat  noconnect  "input=%WHERE_THIS_SCRIPT_IS%\backup-database.sql"


rem  If an SQL command fails, SQLNTTLK.EXE prints an error message, but it carries on, effectively ignoring
rem  the error. For example, the "unload database" SQL command that ultimately does the backup fails if
rem  the destination .sql file already exists, but there are many reasons why that command, or any
rem  previous commands, can fail.
rem
rem  This is a serious software quality issue. I could not find a way to manually check for command failures
rem  inside the .sql script file itself, like you can do in batch files with ERRORLEVEL. 
rem  As a result, there is no reliably way to detect whether the backup succeeded.
rem  
rem  This script checks for the existance of the backup file. If the file is actually there,
rem  chances are that the backup is OK.

set SQL_BACKUP_FILENAME=bibliotheca-database-backup.sql

if not exist "%BACKUP_OUTPUT_DIR%\%SQL_BACKUP_FILENAME%" (
  echo The backup file "%BACKUP_OUTPUT_DIR%\%SQL_BACKUP_FILENAME%" was not generated.
  echo There should be an error message in the previous output explaining what went wrong.
  exit /b 1
)

popd


rem  ------ Backup the 'Config' dir ------

rem  Instead of copying selected configuration and template files, we could just copy anything
rem  underneath the installation directory, just in case. But then we would have to stop
rem  the database service beforehand. And the backup would be much bigger.

rem  Directory C:\Program Files (x86)\BOND\BIBLIO_SERVER\Config has the following files:
rem  - sql.ini , which probably has a valid database connection configuration.
rem  - winoeb.ini   These 2 files look like a standard template configuration, with entries like ProtPfad=C:\BIBLIO ,
rem  - winoebp.ini  so they do not hold a valid configuration.

md "%BACKUP_OUTPUT_DIR%\Config"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot create directory "%BACKUP_OUTPUT_DIR%\Config".
  exit /b %ERRORLEVEL%
)


copy  /B  "%BIBLIOTHECA_CONFIG_DIR%\*"  "%BACKUP_OUTPUT_DIR%\Config"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy the files from "%BIBLIOTHECA_CONFIG_DIR%\".
  exit /b %ERRORLEVEL%
)


rem  ------ Backup the 'BIBLIOTHECA2000' dir ------

rem  Directory C:\ProgramData\BOND\BIBLIOTHECA2000 has the following files:
rem  - winoeb.ini
rem  - winoebp.ini
rem
rem  There is a menu option in the main ("Anmeldung") module to backup these files manually:
rem  Menü "Hilfe", "Konfigurations-Export". The resulting .zip contains these files:
rem  - Winoeb.ini (Arbeitsplatzbezogene Einstellungen), comes apparently from C:\ProgramData\BOND\BIBLIOTHECA2000 .
rem  - Winoebp.ini (Druckvorlagen), comes from the same dir as above.
rem  - perm.pro (Logdatei), comes from C:\Program Files (x86)\BOND\LOG .
rem  There is a text file which contains the installation's licence number, but without the checksum at the end.
rem  I did not see any "Konfigurations-Import" option to import such a backup.

md "%BACKUP_OUTPUT_DIR%\BIBLIOTHECA2000"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot create directory "%BACKUP_OUTPUT_DIR%\BIBLIOTHECA2000".
  exit /b %ERRORLEVEL%
)


copy  /B  "%ProgramData%\BOND\BIBLIOTHECA2000\*"  "%BACKUP_OUTPUT_DIR%\BIBLIOTHECA2000"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy the files from "%ProgramData%\BOND\BIBLIOTHECA2000\".
  exit /b %ERRORLEVEL%
)


rem  ------ About the 'Database' dir ------

rem  Directory BIBLIO_Server\BIN\Database is not used.
rem  Directory BIBLIO_CLIENT\BIN\Database is only used when communicating with Z-Servers with the Z39.50 client,
rem  see menu option Einstellungen / Konfiguration(AP) / Z39.50.


rem  ------ Backup the 'Templates' dir ------

xcopy  /E /I  "%ProgramFiles(x86)%\BOND\BIBLIO_SERVER\Templates"  "%BACKUP_OUTPUT_DIR%\Templates"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy the files from "%ProgramFiles(x86)%\BOND\BIBLIO_SERVER\Templates\".
  exit /b %ERRORLEVEL%
)

rem  According to the documentation, files BibWordPrt.dot and BibWordPrt1.dot through to BibWordPrt5.dot
rem  must not be overwritten on restore.

ren  "%BACKUP_OUTPUT_DIR%\Templates\DOT\BibWordPrt*.dot"  "*.dot.renamed-so-that-it-is-not-restored"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot rename BibWordPrt*.dot etc. in "%BACKUP_OUTPUT_DIR%\Templates\".
  exit /b %ERRORLEVEL%
)


rem  ------ Backup the log file ------

md "%BACKUP_OUTPUT_DIR%\LOG"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot create directory "%BACKUP_OUTPUT_DIR%\LOG".
  exit /b %ERRORLEVEL%
)

copy  /B  "%BIBLIOTHECA_INSTALLATION_DIR%\LOG\perm.pro"  "%BACKUP_OUTPUT_DIR%\LOG"

if !ERRORLEVEL! NEQ 0 (
  echo Cannot copy file "%BIBLIOTHECA_INSTALLATION_DIR%\LOG\perm.pro".
  exit /b %ERRORLEVEL%
)


rem  ------ Final message ------

echo.
echo Bibliotheca data backup succeeded. Destination directory:
echo   %BACKUP_OUTPUT_DIR%
