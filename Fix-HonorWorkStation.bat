@echo off
setlocal EnableExtensions
title Fix HONOR WorkStation

:: When re-run elevated with /devicefix, it applies the device identity keys first,
:: then continues with the normal flow automatically.
if /I "%~1"=="/devicefix" (
    reg add "HKLM\SOFTWARE\HONOR\HonorVersion" /v HonorDevice /t REG_SZ /d 1 /f >nul 2>&1
    reg add "HKLM\SOFTWARE\HONOR\BIOS" /v ProductVersion /t REG_SZ /d HONOR /f >nul 2>&1
    echo Device identity updated - continuing with the fix...
)

set "APP=C:\Program Files\Hihonornote\Hihonornote.exe"
set "APPDIR=C:\Program Files\Hihonornote"
set "OFFCENTER=C:\Program Files\HONOR\OfficeCenter\HNOfficeCenter.exe"
set "CFGDIR=%USERPROFILE%\.config\hihonornote"
set "FEAT=%CFGDIR%\features.json"
set "LOG=%TEMP%\HonorWorkStation_fix.log"

echo ==== Fix HONOR WorkStation on %COMPUTERNAME% / %date% %time% ==== > "%LOG%"

echo.
echo  ==========================================
echo    Fix HONOR WorkStation  (all-in-one)
echo  ==========================================
echo.

:: ---------- step 1: is the app installed? ----------
if exist "%APP%" goto :appok

echo [1/3] HONOR WorkStation is not installed on this PC yet.
set "SETUPFILE="
for %%F in ("%~dp0HonorWorkStation_Setup*.exe") do set "SETUPFILE=%%~fF"
if not defined SETUPFILE (
    echo        ERROR: no installer found next to this file.
    echo        Keep "HonorWorkStation_Setup_3IN1_*.exe" in the same folder, then re-run.
    call :log "ERROR: app not installed and no bundled installer found"
    goto :fail
)
echo        Installer found: %SETUPFILE%
echo        Installing silently... please approve ALL UAC prompts that appear.
call :log "installing %SETUPFILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%SETUPFILE%' -ArgumentList '/S' -Verb RunAs" >nul 2>&1

set /a waited=0
:waitinstall
timeout /t 15 /nologo >nul 2>&1
set /a waited+=15
if exist "%APP%" goto :appok
if %waited% LSS 480 goto :waitinstall
echo        ERROR: installation did not finish within 8 minutes.
call :log "ERROR: install did not finish after %waited% s"
goto :fail

:appok
call :log "app installed: %APP%"
echo [1/3] App found: %APP%

:: ---------- check device identity (app refuses to run on non-HONOR brands) ----------
set "NEEDEV=0"
reg query "HKLM\SOFTWARE\HONOR\HonorVersion" /v HonorDevice >nul 2>&1
if errorlevel 1 set "NEEDEV=1"
reg query "HKLM\SOFTWARE\HONOR\BIOS" /v ProductVersion >nul 2>&1
if errorlevel 1 set "NEEDEV=1"
if "%NEEDEV%"=="1" (
    call :log "device identity keys missing - elevating to apply them"
    echo        Device is not recognized as a HONOR PC. Applying device identity fix...
    echo        Please approve the UAC prompt ^(the window will carry on by itself^).
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '/devicefix' -Verb RunAs" >nul 2>&1
    exit /b 0
)
call :log "device identity OK"

:: ---------- step 2: is it already running? ----------
tasklist /FI "IMAGENAME eq Hihonornote.exe" 2>nul | findstr /I "Hihonornote" >nul
if not errorlevel 1 (
    call :log "app already running"
    echo [2/3] App is already running. Applying safeguard for future launches...
    call :fixfeatures
    echo [3/3] Done - HONOR WorkStation is already open. Nothing else to do.
    goto :ok
)

echo [2/3] Applying startup fix...
call :fixfeatures

if exist "%OFFCENTER%" (
    call :log "OfficeCenter component OK"
) else (
    call :log "WARN: OfficeCenter component missing"
    echo        NOTE: some extras (phone-connect / share / account) may be limited.
    echo        The app can still start; reinstall with the installer if you need those.
)

if exist "%APPDIR%\resources\app.asar.honor-compat-backup" (
    call :log "WARN: modified app package detected"
    echo        NOTE: this install looks modified by another tool.
    echo        If problems persist: uninstall via Control Panel, then run this file with the installer.
)

:: ---------- step 3: launch and verify it stays open ----------
echo [3/3] Starting HONOR WorkStation...
start "" /D "%APPDIR%" "%APP%"

timeout /t 6 /nologo >nul 2>&1
tasklist /FI "IMAGENAME eq Hihonornote.exe" 2>nul | findstr /I "Hihonornote" >nul
if errorlevel 1 (
    call :log "FAIL: app exited within 6 s"
    echo        App exited right away. See log: "%LOG%"
    goto :fail
)

echo        App is starting... waiting 15 s to confirm it stays open.
timeout /t 15 /nologo >nul 2>&1
tasklist /FI "IMAGENAME eq Hihonornote.exe" 2>nul | findstr /I "Hihonornote" >nul
if errorlevel 1 (
    call :log "FAIL: app exited within 21 s"
    echo        App exited shortly after start.
    echo        Likely a broken install: uninstall fully, then keep the installer next to this
    echo        file and re-run it.
    goto :fail
)

call :log "OK: app running on %COMPUTERNAME%"
echo        OK - HONOR WorkStation is running. You can close this window.
goto :ok

:ok
echo.
echo  Done. Log saved to: %LOG%
pause
exit /b 0

:fail
echo.
echo  *** FAILED *** Log saved to: %LOG%
pause
exit /b 1

:: ---------- subroutines ----------
:fixfeatures
if not exist "%CFGDIR%" mkdir "%CFGDIR%" >nul 2>&1
set "NEEDWRITE=1"
if exist "%FEAT%" (
    findstr /C:"HonorFileShare" "%FEAT%" >nul 2>&1
    if not errorlevel 1 set "NEEDWRITE=0"
)
if %NEEDWRITE%==1 (
    echo {"DistributedFramework":"1","HonorFileShare":"1","NetworkSharing":"1","SuperHandoff":"1","SuperKeyMouse":"1","SuperNotification":"1","SuperTerminal":"1","VirtualDeviceService":"1"}>"%FEAT%"
    echo        Wrote fallback flags: %FEAT%
    call :log "wrote fallback features.json"
) else (
    echo        Existing features.json is fine - left untouched.
    call :log "features.json already valid"
)
exit /b 0

:log
echo [%date% %time%] %~1 >> "%LOG%"
exit /b 0
