@echo off
chcp 936 >nul
setlocal
title 自定义位置
set "BASE=%~dp0"

cls
echo ============================================
echo          自定义虚拟定位
echo ============================================
echo.
echo   输入格式:  纬度,经度
echo   示例:      31.2304,121.4737
echo   直接回车 = 北京天安门
echo.

set "IN="
set /p "IN=坐标: "
if "%IN%"=="" set "IN=39.90291980,116.39380287"

set "LAT="
set "LNG="
for /f "tokens=1,2 delims=, " %%a in ("%IN%") do (
  set "LAT=%%a"
  set "LNG=%%b"
)

if "%LAT%"=="" goto BAD
if "%LNG%"=="" goto BAD

echo %LAT%| findstr /r /c:"^[-0-9.][0-9.]*$" >nul
if errorlevel 1 goto BAD
echo %LNG%| findstr /r /c:"^[-0-9.][0-9.]*$" >nul
if errorlevel 1 goto BAD

echo.
echo   纬度: %LAT%
echo   经度: %LNG%
echo.
call "%BASE%_core.bat" "%LAT%" "%LNG%"
exit /b 0

:BAD
echo.
echo   格式不对，要用  纬度,经度  这样，比如 31.2304,121.4737
pause
exit /b 1
