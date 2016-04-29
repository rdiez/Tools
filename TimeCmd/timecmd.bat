@echo off

rem I downloaded this script from
rem   https://stackoverflow.com/questions/4487100/how-can-i-use-a-windows-batch-file-to-measure-the-performance-of-console-applica
rem and then I made a few changes.

setlocal

rem The format of %TIME% is HH:MM:SS,CS for example 23:59:59,99
set STARTTIME=%TIME%

rem Runs your command
cmd /c %*

set SAVED_ERRORLEVEL=%ERRORLEVEL%
rem echo SAVED_ERRORLEVEL: %SAVED_ERRORLEVEL%

set ENDTIME=%TIME%


:: If the hour component is less than 10, then %TIME% starts with a space, which ends
:: up in trouble later on. Replace that space with a zero.
if "%STARTTIME:~0,1%" == " " set STARTTIME=0%STARTTIME:~1,10%
if "%ENDTIME:~0,1%" == " " set ENDTIME=0%ENDTIME:~1,10%

rem output as time
rem echo STARTTIME: %STARTTIME%
rem echo ENDTIME: %ENDTIME%

rem convert STARTTIME and ENDTIME to centiseconds
set /A STARTTIME=(1%STARTTIME:~0,2%-100)*360000 + (1%STARTTIME:~3,2%-100)*6000 + (1%STARTTIME:~6,2%-100)*100 + (1%STARTTIME:~9,2%-100)
set /A ENDTIME=(1%ENDTIME:~0,2%-100)*360000 + (1%ENDTIME:~3,2%-100)*6000 + (1%ENDTIME:~6,2%-100)*100 + (1%ENDTIME:~9,2%-100)

rem calculating the duration is easy
set /A DURATION=%ENDTIME%-%STARTTIME%

rem we might have measured the time inbetween days
if %ENDTIME% LSS %STARTTIME% set set /A DURATION=%STARTTIME%-%ENDTIME%

rem now break the centiseconds down to hors, minutes, seconds and the remaining centiseconds
set /A DURATIONH=%DURATION% / 360000
set /A DURATIONM=(%DURATION% - %DURATIONH%*360000) / 6000
set /A DURATIONS=(%DURATION% - %DURATIONH%*360000 - %DURATIONM%*6000) / 100
set /A DURATIONHS=(%DURATION% - %DURATIONH%*360000 - %DURATIONM%*6000 - %DURATIONS%*100)

rem some formatting
if %DURATIONH% LSS 10 set DURATIONH=0%DURATIONH%
if %DURATIONM% LSS 10 set DURATIONM=0%DURATIONM%
if %DURATIONS% LSS 10 set DURATIONS=0%DURATIONS%
if %DURATIONHS% LSS 10 set DURATIONHS=0%DURATIONHS%

rem outputing
rem echo STARTTIME: %STARTTIME% centiseconds
rem echo ENDTIME: %ENDTIME% centiseconds
rem echo DURATION: %DURATION% in centiseconds
rem echo %DURATIONH%:%DURATIONM%:%DURATIONS%,%DURATIONHS%

echo:
echo Finished running command: %*
echo Exit code: %SAVED_ERRORLEVEL%

set /A DURATION_TOTAL_SEC=%DURATION% / 100
set /A DURATION_REST_CENTISEC=(%DURATION% - %DURATION_TOTAL_SEC%*100)
echo Elapsed time: %DURATION_TOTAL_SEC%.%DURATION_REST_CENTISEC% s (%DURATIONH%h %DURATIONM%m %DURATIONS%.%DURATIONHS%s)

endlocal & set SAVED_ERRORLEVEL=%SAVED_ERRORLEVEL%

rem echo SAVED_ERRORLEVEL: %SAVED_ERRORLEVEL%
rem This does not work properly, see below:
rem   exit /B %SAVED_ERRORLEVEL%
rem Trick from Stackoverflow article:
rem   https://stackoverflow.com/questions/4632891/exiting-batch-with-exit-b-x-where-x-1-acts-as-if-command-completed-successfu
%COMSPEC% /C exit %SAVED_ERRORLEVEL% >nul
