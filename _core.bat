@echo off
chcp 936 >nul
setlocal enabledelayedexpansion

rem ===== 参数 =====
rem  %1 = 纬度   %2 = 经度   %3 = stop 时表示结束虚拟定位
set "LAT=%~1"
set "LNG=%~2"
set "MODE=%~3"
set "BASE=%~dp0"

set "ADB="
set "SERIAL="
set "PY="
set "FAKE_PATH="
set "CELL_PATH="

if /i "!MODE!"=="stop" goto BANNER_STOP

if "!LAT!"=="" goto USAGE

:BANNER
echo ============================================
echo   Android 虚拟定位
echo   坐标: !LAT!, !LNG!
echo ============================================
echo.
goto S1

:BANNER_STOP
echo ============================================
echo   Android 虚拟定位 - 结束
echo ============================================
echo.
goto S1

rem ---------- 1. 找 adb ----------
:S1
echo [1/7] 查找 ADB...
if exist "%BASE%platform-tools\adb.exe" set "ADB=%BASE%platform-tools\adb.exe"
if not defined ADB if exist "C:\platform-tools\adb.exe" set "ADB=C:\platform-tools\adb.exe"
if not defined ADB (
  for /f "delims=" %%i in ('where adb.exe 2^>nul') do if not defined ADB set "ADB=%%i"
)
if not defined ADB goto NOADB
for %%i in ("!ADB!") do set "ADB_DIR=%%~dpi"
pushd "!ADB_DIR!"
echo     !ADB!
echo.
goto S2

:NOADB
echo    找不到 adb.exe
echo    请把 platform-tools 文件夹放到本目录下
goto FAIL

rem ---------- 2. 等设备 ----------
:S2
echo [2/7] 等待设备...
set /a TRY=0
:WAIT
set "SERIAL="
"%ADB%" start-server >nul 2>nul
for /f "skip=1 tokens=1,2" %%a in ('""%ADB%" devices" 2^>nul') do (
  if "%%b"=="device" set "SERIAL=%%a"
)
if defined SERIAL goto GOT
set /a TRY+=1
if !TRY! GEQ 20 goto NODEV
ping -n 3 127.0.0.1 >nul
goto WAIT

:NODEV
echo    没检测到已授权的设备
echo    请确认: USB 已连接 / 手机上点了「允许 USB 调试」
goto FAIL

:GOT
echo    设备: !SERIAL!
echo.

rem ---------- 3. 检查环境 ----------
echo [3/7] 检查环境...
set "ID="
for /f "delims=" %%i in ('""%ADB%" -s !SERIAL! shell "su -c id"" 2^>nul') do set "ID=%%i"
echo !ID! | findstr /c:"uid=0" >nul
if errorlevel 1 goto NOROOT
echo    root: OK
"%ADB%" -s !SERIAL! shell "su -c 'test -f /data/adb/lspd/config/modules_config.db'" >nul 2>nul
if errorlevel 1 goto NOLSP
echo    LSPosed: OK
echo.
goto S4

:NOROOT
echo    没有 root
goto FAIL

:NOLSP
echo    没找到 LSPosed
echo    需要先装好 LSPosed 并重启一次
goto FAIL

rem ---------- 4. 装模块 ----------
:S4
echo [4/7] 模块...
if /i "!MODE!"=="stop" goto S4_SKIP
call :INSTALL "XposedFakeLocation.apk" "com.noobexon.xposedfakelocation"
call :INSTALL "NoCell.apk" "com.yg.nocell"
echo.
for /f "tokens=2 delims=:" %%i in ('""%ADB%" -s !SERIAL! shell "pm path com.noobexon.xposedfakelocation"" 2^>nul') do set "FAKE_PATH=%%i"
for /f "tokens=2 delims=:" %%i in ('""%ADB%" -s !SERIAL! shell "pm path com.yg.nocell"" 2^>nul') do set "CELL_PATH=%%i"
goto S5

:S4_SKIP
echo    结束模式，跳过安装
echo.

rem ---------- 5. 写配置 ----------
:S5
echo [5/7] 写入配置...
if exist "%BASE%python\python.exe" set "PY=%BASE%python\python.exe"
if not defined PY (
  py -3 -c "print(1)" >nul 2>nul && set "PY=py -3"
)
if not defined PY (
  python -c "print(1)" >nul 2>nul && set "PY=python"
)
if not defined PY goto NOPY

"%ADB%" exec-out "su -c 'cat /data/adb/lspd/config/modules_config.db'" > "%BASE%_cfg.tmp" 2>nul
set "FSZ=0"
for %%i in ("%BASE%_cfg.tmp") do set "FSZ=%%~zi"
if !FSZ! LSS 10000 goto PULLFAIL

if /i "!MODE!"=="stop" goto DO_STOP
%PY% "%BASE%apply_db.py" "%BASE%_cfg.tmp" !LAT! !LNG! "!FAKE_PATH!" "!CELL_PATH!"
goto PUSH

:DO_STOP
%PY% "%BASE%apply_db.py" "%BASE%_cfg.tmp" stop

:PUSH
if errorlevel 1 goto PUSHFAIL
"%ADB%" push "%BASE%_cfg.tmp" /data/local/tmp/_cfg.tmp >nul 2>nul
"%ADB%" shell "su -c 'cp /data/local/tmp/_cfg.tmp /data/adb/lspd/config/modules_config.db && chown root:root /data/adb/lspd/config/modules_config.db && chmod 600 /data/adb/lspd/config/modules_config.db && rm -f /data/adb/lspd/config/modules_config.db-wal /data/adb/lspd/config/modules_config.db-shm'"
if errorlevel 1 goto PUSHFAIL
del "%BASE%_cfg.tmp" >nul 2>nul
echo    配置已写入
echo.
goto S6

:NOPY
echo    没找到 Python，跳过配置写入
echo    请打开 XposedFakeLocation 手动点地图选点
goto S6

:PULLFAIL
echo    拉取配置失败（文件为空或不是 LSPosed 配置）
echo    设备未做任何改动，重启手机后重试
del "%BASE%_cfg.tmp" >nul 2>nul
goto S6

:PUSHFAIL
echo    推回设备失败
del "%BASE%_cfg.tmp" >nul 2>nul
goto S6

rem ---------- 6. 重启 ----------
:S6
echo [6/7] 重启设备让配置生效
set "RB="
set /p "RB=现在重启吗 [Y/n]: "
if "!RB!"=="" set "RB=Y"
if /i "!RB!"=="N" goto SKIPREBOOT
echo    重启中，约 40 秒...
"%ADB%" reboot >nul 2>nul
ping -n 46 127.0.0.1 >nul
echo [7/7] 等待开机...
set /a TRY=0
:WAIT2
set "SERIAL="
for /f "skip=1 tokens=1,2" %%a in ('""%ADB%" devices" 2^>nul') do (
  if "%%b"=="device" set "SERIAL=%%a"
)
if defined SERIAL goto DONE
set /a TRY+=1
if !TRY! GEQ 30 goto DONE
ping -n 3 127.0.0.1 >nul
goto WAIT2

:SKIPREBOOT
echo    记得自己重启一次，否则配置不生效
goto DONE

:DONE
echo.
echo ============================================
if /i "!MODE!"=="stop" goto END_STOP
echo   部署完成
echo   打开微信 - 发送位置，应显示目标地点
echo   若仍是原地，把微信从后台划掉再进
goto END_FIN

:END_STOP
echo   已结束虚拟定位
echo   重启后定位恢复正常

:END_FIN
echo ============================================
popd
pause
exit /b 0

:USAGE
echo 用法:
echo   一键部署.bat      - 从菜单选地点
echo   自定义位置.bat    - 手动输入经纬度
echo   结束虚拟定位.bat  - 停止模拟
exit /b 1

:INSTALL
set "APKNAME=%~1"
set "PKG=%~2"
if not exist "%BASE%apk\%APKNAME%" goto NOAPK
"%ADB%" -s !SERIAL! shell "pm list packages %PKG%" 2>nul | findstr /c:"%PKG%" >nul
if not errorlevel 1 goto ALREADY
"%ADB%" push "%BASE%apk\%APKNAME%" "/data/local/tmp/%APKNAME%" >nul 2>nul
"%ADB%" shell "su -c 'chmod 644 /data/local/tmp/%APKNAME% && pm install -r /data/local/tmp/%APKNAME%'" 2>&1 | findstr /c:"Success" >nul
if errorlevel 1 goto INSTFAIL
echo    %PKG% 安装成功
exit /b 0

:ALREADY
echo    %PKG% 已安装
exit /b 0

:NOAPK
echo    缺少 apk\%APKNAME%
exit /b 1

:INSTFAIL
echo    %PKG% 安装失败
exit /b 1

:FAIL
echo.
echo 部署中断
popd
pause
exit /b 1
