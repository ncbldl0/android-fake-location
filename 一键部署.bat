@echo off
chcp 936 >nul
setlocal enabledelayedexpansion
title Android 虚拟定位
set "BASE=%~dp0"

cls
echo ============================================
echo          Android 虚拟定位
echo ============================================
echo.
echo   请选择目标位置:
echo.

if not exist "%BASE%presets.txt" (
  echo    缺少 presets.txt
  pause
  exit /b 1
)

set /a N=0
for /f "usebackq eol=# tokens=1,2,3 delims=|" %%a in ("%BASE%presets.txt") do (
  set /a N+=1
  echo    [!N!] %%a
)
set "MAX=!N!"

echo.
echo    [C] 自定义经纬度
echo    [0] 结束虚拟定位
echo.
set "SEL="
set /p "SEL=请输入编号 [1-!MAX!]: "

set "SEL=!SEL: =!"
if "!SEL!"=="" set "SEL=1"
if /i "!SEL!"=="C" goto CUSTOM
if /i "!SEL!"=="0" goto ENDIT

echo !SEL!| findstr /r /c:"^[0-9][0-9]*$" >nul
if errorlevel 1 goto BAD
if !SEL! LSS 1 goto BAD
if !SEL! GTR !MAX! goto BAD

set "VNAME="
set "VLAT="
set "VLNG="
set /a N=0
for /f "usebackq eol=# tokens=1,2,3 delims=|" %%a in ("%BASE%presets.txt") do (
  set /a N+=1
  if !N! EQU !SEL! (
    set "VNAME=%%a"
    set "VLAT=%%b"
    set "VLNG=%%c"
  )
)

if "!VLAT!"=="" goto BAD
echo.
echo   已选: !VNAME!
call "%BASE%_core.bat" "!VLAT!" "!VLNG!"
exit /b 0

:CUSTOM
call "%BASE%自定义位置.bat"
exit /b 0

:ENDIT
call "%BASE%结束虚拟定位.bat"
exit /b 0

:BAD
echo.
echo   编号不对
pause
exit /b 1
