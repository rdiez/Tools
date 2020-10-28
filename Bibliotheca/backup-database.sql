
-- This logs the command output to another file, in addition to the console.
-- It is not really necessary, but sometimes it is convenient to have the log file.
set spool sql-backup-command-log.spl;

connect biblio sysadm geheim;

set errorlevel 3;

set inmessage 15000;
set outmessage 15000;

-- This sets the level of detail for the messages on the process activity server
-- display (0-4). The default is 0.
-- I do not know whether setting this option is necessary.
set printlevel 0;

-- If BULK is ON, operations are buffered in the output message buffer as much as possible.
set bulk on;

set activitylog off;

-- Turn off data echo.
set decho off;

unload database bibliotheca-database-backup.sql;

disconnect all;
