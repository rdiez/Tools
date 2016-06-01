@echo OFF

:: This script is similar to Unix command 'watch'.
:: Usage example:
::
::  repeat dir /w
::
:: Unfortunately, the SHIFT command does not affect %*,
:: so I could not pass the time between runs as a command-line parameter.
::
:: Alternatives:
:: - Install Cygwin package "procps-ng" to get the 'watch' command,
::   the run it like this:
::      C:\cygwin64\bin\watch  --interval 0.5  cmd /c myscript.bat

:: The pause is in seconds. Unfortunately, no decimals are allowed.
set Pause=1

:loop
  call %*
  timeout /t %Pause% /nobreak >nul
  :: Alternative:  sleep %Pause%
goto loop
