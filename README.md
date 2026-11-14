# Android 虚拟定位 · 一键部署

把微信、高德、QQ 等 App 的定位改到任意城市，一条命令搞定。

适用于 **已 root + 已装 LSPosed** 的 Android 手机，不改系统文件，不装 Xposed 框架本体，卸载即恢复。

---

## 效果

部署后在微信「发送位置」里，地图中心就是设定的坐标，下面的 POI 列表也全是当地的：

```
中国国家博物馆 · 100m内 · 东城区
天安门广场    · 200m  · 东城区东长安街
毛主席纪念堂  · 280m  · 天安门广场
```

---

## 为什么需要两个模块

这是本项目最关键的部分，也是很多同类工具失效的原因。

| 模块 | 作用 | 单独使用的后果 |
|---|---|---|
| **XposedFakeLocation** | hook `Location.getLatitude / getLongitude / getAccuracy` 等，把坐标改成目标值 | 微信仍会用**基站 + WiFi 指纹**反查真实位置，覆盖掉假坐标 |
| **NoCell**（本项目自带） | hook `TelephonyManager.getAllCellInfo`、`getCellLocation`、`WifiManager.getScanResults`、`WifiInfo.getBSSID/SSID/MAC`，让它们返回空 | 坐标还是本地，只是 App 少了旁路数据 |

两个一起装，微信才认假坐标。

实测数据：只装 FakeLocation 时，微信「发送位置」始终显示原地；两个都装之后，切换成目标城市正常。

---

## 环境要求

- Android 8.0 以上，**已 root**（KernelSU / Magisk 都行）
- **已安装 LSPosed 并处于运行状态**
- 电脑端 Windows，手机能通过 USB 调试连接

adb 和 Python 都打包在仓库里了，电脑上不需要额外装东西。

本项目在 **Xiaomi 15 / Android 17 / KernelSU + LSPosed 2.2.0** 上实测通过。

---

## 使用

### 1. 准备

把手机用 USB 连上电脑，打开「开发者选项 → USB 调试」，手机上点「允许」。

### 2. 部署

双击 `一键部署.bat`，菜单里选一个地点：

```
============================================
         Android 虚拟定位
============================================

  请选择目标位置:

   [1] 北京·天安门
   [2] 上海·外滩
   [3] 广州·广州塔
  ...
   [C] 自定义经纬度
   [0] 结束虚拟定位

请输入编号 [1-18]:
```

选完按提示重启手机。重启后打开微信 →「发送位置」，就是目标地点了。

### 3. 自定义坐标

双击 `自定义位置.bat`，输入 `纬度,经度`：

```
坐标: 31.2304,121.4737
```

也可以给 `一键部署.bat` 传参数：

```bat
一键部署.bat 31.2304,121.4737
```

### 4. 结束

双击 `结束虚拟定位.bat`，模块停用，重启后定位恢复真实。

---

## 预设地点

编辑 `presets.txt`，一行一个，格式 `名称|纬度|经度`：

```
# 名称|纬度|经度
北京·天安门|39.90291980|116.39380287
上海·外滩|31.23966000|121.49030000
```

`#` 开头的行是注释。序号会自动重排，加多少行都行。

> 文件是 GBK 编码，用记事本直接编辑保存即可。

---

## 目录结构

```
.
├── 一键部署.bat            主入口，菜单选点
├── 自定义位置.bat          手动输入经纬度
├── 结束虚拟定位.bat        停用模块
├── _core.bat               实际部署逻辑（被上面三个调用）
├── presets.txt             预设地点
├── apply_db.py             改写 LSPosed 配置
├── 说明.txt                简版使用说明
├── apk/
│   ├── XposedFakeLocation.apk
│   ├── NoCell.apk
│   └── lsposed_manager.apk
├── python/                 嵌入式 Python 3.11（写配置用）
└── platform-tools/         自带的 adb
```

全部依赖都打包在里面了，clone 下来双击就能跑，不用另外装 adb 或 Python。

---

## 原理细节

LSPosed 把每个模块的启用状态、作用域、配置都存在一个 SQLite 库里：

```
/data/adb/lspd/config/modules_config.db
```

关键三张表：

```sql
modules(module_pkg_name, apk_path)
modules_state(module_pkg_name, user_id, enabled, scope_request_blocked)
scope(module_pkg_name, app_pkg_name, user_id)
module_configs(module_pkg_name, user_id, group_name, key_name, data)
```

`apply_db.py` 做的就是往这几张表里 UPSERT。有个坑：`module_configs.data` 存的是 **Java `ObjectOutputStream` 序列化后的字节**，不是明文：

```
String : ac ed 00 05 74 <len:2字节大端> <utf8>
Boolean: ac ed 00 05 73 72 00 11 java.lang.Boolean ... 01
```

直接写明文进去，LSPosed 反序列化会失败，模块读不到配置。

流程是：`killall lspd` → pull 数据库 → 本地改 → push 回去 → 删掉 `-wal` / `-shm` → 重启设备让 lspd 重新加载。

---

## 常见问题

**部署完微信还是显示原地？**

1. 确认重启过手机，配置是在 lspd 启动时读的
2. 把微信从后台彻底划掉再进
3. 打开 XposedFakeLocation，确认显示「已设置虚拟位置」且开关是开的
4. LSPosed 管理器里检查两个模块的作用域：`XposedFakeLocation` 要勾 `系统框架` + `微信`，`NoCell` 要勾 `微信`

**显示了目标城市，但 POI 列表不对？**

微信的 POI 是联网从腾讯服务器拉的，按坐标附近搜索。如果列表空，检查网络。如果距离显示成几万公里，说明基站数据没拦住——确认 NoCell 已启用且作用域勾了微信。

**提示找不到 adb？**

把 `platform-tools` 文件夹放到项目根目录。脚本按这个顺序找：本目录 `platform-tools\adb.exe` → `C:\platform-tools\adb.exe` → 系统 PATH。

**提示「拉取配置失败」或 Python 报 `no such table: modules`？**

拉 LSPosed 配置文件时没读到东西（拿到了空文件）。脚本会在这步停下，设备不会被改动。

重启手机，拔插一次 USB，确认 `adb devices` 能看到设备，再跑一遍就行。

早先版本会在拉取前执行 `killall lspd`，LSPosed 守护进程重启的瞬间读不到文件，才会出现这个报错。现在已经去掉这一步，并且加了文件大小和表结构双重校验。

**提示没找到 Python？**

装一个 Python 3（勾选 Add to PATH），或者打开 XposedFakeLocation 手动点地图选点——坐标存在 App 里，效果一样。

**`INSTALL_FAILED_USER_RESTRICTED`？**

MIUI/HyperOS 默认禁止 USB 安装。本项目用 `su -c pm install` 绕过了这个限制，正常不会遇到。如果遇到，去开发者选项里关掉「USB 安装校验」。

**能改高德/百度地图吗？**

可以，把两个模块的作用域里加上对应包名（`com.autonavi.minimap` / `com.baidu.BaiduMap`）即可。

---

## 注意

- 只改 App 拿到的定位数据，不动系统定位服务，卸载模块后完全恢复
- 部分 App 有模拟定位检测，本项目通过拦截基站/WiFi 旁路数据来规避，但不保证对每个 App 都有效
- 打卡类 App 通常还有服务端校验和 GPS 卫星信号校验，不在本项目覆盖范围

---

## 致谢

- [XposedFakeLocation](https://github.com/noobexon1/XposedFakeLocation) —— 坐标 hook 模块
- [LSPosed](https://github.com/LSPosed/LSPosed) —— 框架

`NoCell.apk` 为本项目自行编译，源码逻辑：拦截 `TelephonyManager` / `WifiManager` 的定位相关接口返回空值。

## License

MIT
