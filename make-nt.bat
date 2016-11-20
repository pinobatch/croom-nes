@echo off
set PATH=C:\Python26;%PATH%
make
if errorlevel 1 goto Err
goto End
:Err
pause
:End