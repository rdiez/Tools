
-- This logs the command output to another file, in addition to the console.
-- It is not really necessary, but sometimes it is convenient to have the log file.
set spool sql-restore-command-log.spl;

-- Connect to the server, but not to a particular database.
-- Full syntax: set server myserver/password;
-- The default server name is 'server1'.
set server server1;

-- If you are manually performing these steps, you probably want to lists
-- all databases at this point.
-- Before setting the server with "set server", you can do:
--   show databases on server server1;
-- After setting the server, you do not need to specify the server name anymore.
--   show databases;

-- If the database exists, the best thing to do would be to rename it.
-- Unfortunately, I have not found a way to do that yet.
-- SQL command "ALTER DATABASE BIBLIO RENAME TO BIBLIO.OLD;" is not supported.
--
-- This script assumes that the database exists and deletes it.
-- We cannot load the backup into an existing database. I tried once to reuse the existing database,
-- which only had a few readers and books, and I got this error:
--    Error: 00967 PRS DIL Delimited identifier is too long
--    Reason: A delimited string is too long.
--    Remedy: Correct the SQL statement.

DROP DATABASE biblio;

-- Create the database. The default password is 'sysadm', but everything else expects 'geheim',
-- so change the password.
create database biblio;
connect biblio sysadm sysadm;
ALTER PASSWORD sysadm TO geheim;

-- Turning off transaction logging speeds things up.
set recovery off;

-- Some people recommend turning the bulk mode on.
-- If BULK is ON, operations are buffered in the output message buffer as much as possible.
--   set bulk on;

SET ERRORLEVEL 3;

-- Locking the database improves the LOAD command's performance.
-- We do not need an "UNLOCK DATABASE;" because the lock will be automatically released
-- when we disconnect our session.
LOCK DATABASE;

-- Increasing the size of the output message buffer with the SET OUTMESSAGE
-- command increases the number of operations that can be buffered in one message
-- to the server, which improves performance.
-- The value 8000 depends on the amount of RAM available. The maximum number of pages is 32000.
-- The backup script uses actually value 15000.
--   set outmessage 8000;
-- We could also increase the inmessage size.

-- File load-log.txt lands in C:\Windows\SysWOW64 , which is a strange place.
-- We probably do not need this log file.

load SQL bibliotheca-database-backup.sql log load-log.txt;


-- In some places, it says that you need to commit after the 'load' command.
--   commit;

-- set bulk off;

-- We could restart transaction logging here, but it seems already the case,
-- because the following command says then:
--     RECOVERY IS ALREADY ENABLED
--   set recovery on;

-- Sets the outmessage buffer back to the default
-- set outmessage 2000;

disconnect all;
