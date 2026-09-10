@echo off
:: BatchGotAdmin
:-------------------------------------
REM --> Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

REM --> If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo Requesting Administrative privileges to configure Windows Firewall...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params = %*:"=""
    echo UAC.ShellExecute "cmd.exe", "/c """"%~s0"" %params%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------

echo =======================================================
echo Configuring Windows Firewall for PC Control Center...
echo =======================================================

:: Remove any conflicting block rules for python.exe and port 8765
netsh advfirewall firewall delete rule name="python.exe" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetFirewallRule | Where-Object { $_.Action -eq 'Block' -and $_.Direction -eq 'Inbound' -and ($_.DisplayName -eq 'python.exe' -or $_.Name -like '*python.exe*') } | Remove-NetFirewallRule" >nul 2>&1

netsh advfirewall firewall delete rule name="PC Control Center Port 8765" >nul 2>&1
netsh advfirewall firewall delete rule name="PC Control Center UDP 8765" >nul 2>&1
netsh advfirewall firewall delete rule name="PC Control Center Python Inbound" >nul 2>&1
netsh advfirewall firewall delete rule name="PC Control Center Venv Python Inbound" >nul 2>&1

:: Add Inbound Allow Rule for Port 8765 TCP
netsh advfirewall firewall add rule name="PC Control Center Port 8765" dir=in action=allow protocol=TCP localport=8765 profile=any

:: Add Inbound Allow Rule for Port 8765 UDP (MDNS / Discovery)
netsh advfirewall firewall add rule name="PC Control Center UDP 8765" dir=in action=allow protocol=UDP localport=8765 profile=any

:: Add Inbound Allow Rule for Python
netsh advfirewall firewall add rule name="PC Control Center Python Inbound" dir=in action=allow program="%LOCALAPPDATA%\Programs\Python\Python312\python.exe" profile=any >nul 2>&1

:: Add Inbound Allow Rule for Virtualenv Python
if exist "%~dp0.venv\Scripts\python.exe" (
    netsh advfirewall firewall add rule name="PC Control Center Venv Python Inbound" dir=in action=allow program="%~dp0.venv\Scripts\python.exe" profile=any >nul 2>&1
)

echo.
echo [SUCCESS] Windows Firewall rules added successfully!
echo Inbound traffic on Port 8765 (TCP/UDP) is now allowed.
echo.
pause

