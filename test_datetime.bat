@echo off
cls

for /f %%i in ('datetime.exe +"%%Y%%"') do set xdatetime=%%i
echo %datetime%

echo ---
REM for /f "delims=" %%a in ('set _currentdatetime') do @set foobar=%%a
REM echo %_currentdatetime%
REM echo %foobar%
REM echo %WINDIR%
REM echo %xdatetime%