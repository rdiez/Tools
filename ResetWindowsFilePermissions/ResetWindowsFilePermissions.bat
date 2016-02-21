@echo off

:: Notes:
:: 1) You may have to edit the value of the YES_STRING variable further below.
:: 2) You may need to run this script inside a command prompt with elevated privileges.

setlocal

:: It is hard to determine the yes string, as it depends on the current locale,
:: so you will have to edit this for your system.
:: English: 'y', German: 'j', Spanish: 's'.
set YES_STRING=y


set EXPECTED_CMD_LINE_ARG_COUNT=1
set argC=0
for %%x in (%*) do set /A argC+=1
if %argC% NEQ %EXPECTED_CMD_LINE_ARG_COUNT% (
  echo Wrong number of command-line arguments, %argC% found instead of the expected %EXPECTED_CMD_LINE_ARG_COUNT%.
  exit /b 1
  )


:: Step 1) Take ownership as the current user, which not always grants full access to the owner:

:: /R means recursive
:: The ">nul" is necessary because TAKEOWN is too verbose.
:: Alteratively, add switch /A to transfer ownership to the Administrators group, instead of the current user.
TAKEOWN  /F %1  /R  /D %YES_STRING% >nul

if %errorlevel% neq 0 (
  echo TAKEOWN failed with error code %errorlevel%.
  exit /b %errorlevel%
)


:: Step 2) Reset all permissions. This means everything inherits the root permissions.

:: /T means recursive
:: /Q supresses successful messages.
:: Optional: /C means carry on after an error, but still show the error messages.
:: Alternative: /grant Administratoren:F
ICACLS %1 /RESET /T /Q

if %errorlevel% neq 0 (
  echo ICACLS failed with error code %errorlevel%.
  exit /b %errorlevel%
)

:: Step 3) Give full permissions to the current user:
::
:: echo cacls %1 /t /c /e /g %USERNAME%:F
::
::if %errorlevel% neq 0 exit /b %errorlevel%

echo Finished successfully.
