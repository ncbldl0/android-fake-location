@echo off
chcp 936 >nul
setlocal
title 结束虚拟定位
set "BASE=%~dp0"

cls
echo ============================================
echo           结束虚拟定位
echo ============================================
echo.
echo   将停用两个模块，定位恢复真实位置
echo.

call "%BASE%_core.bat" "" "" stop
exit /b 0
