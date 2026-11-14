#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""直接改写 LSPosed 的 modules_config.db，实现虚拟定位的开/关与坐标设置。

用法:
  apply_db.py <db> <纬度> <经度> [fake_apk] [nocell_apk]   # 开启并设置坐标
  apply_db.py <db> stop                                     # 结束虚拟定位
"""
import sqlite3
import struct
import sys

FAKE = "com.noobexon.xposedfakelocation"
CELL = "com.yg.nocell"
GROUP = "settings"


def jstr(s):
    """Java ObjectOutputStream 序列化一个 String。"""
    b = s.encode("utf-8")
    return b"\xac\xed\x00\x05t" + struct.pack(">H", len(b)) + b


def jbool(v):
    """Java ObjectOutputStream 序列化一个 Boolean。"""
    head = (
        b"\xac\xed\x00\x05sr\x00\x11java.lang.Boolean"
        b"\xcd r\x80\xd5\x9c\xfa\xee\x02\x00\x01Z\x00\x05valuexp"
    )
    return head + (b"\x01" if v else b"\x00")


def set_enabled(cur, pkg, on):
    cur.execute(
        "insert or replace into modules_state"
        "(module_pkg_name,user_id,enabled,scope_request_blocked) values(?,0,?,0)",
        (pkg, 1 if on else 0),
    )


def check(con):
    """确认这是一份可用的 LSPosed 配置，而不是空文件或别的数据库。"""
    rows = con.execute("select name from sqlite_master where type='table'").fetchall()
    tables = {r[0] for r in rows}
    need = {"modules", "modules_state", "scope", "module_configs"}
    missing = need - tables
    if missing:
        raise SystemExit(
            "[db] 拉到的文件里缺少表 %s，说明没有取到真正的配置，已中止（设备未改动）"
            % ",".join(sorted(missing))
        )


def stop(db):
    con = sqlite3.connect(db)
    check(con)
    cur = con.cursor()
    for pkg in (FAKE, CELL):
        set_enabled(cur, pkg, False)
    cur.execute(
        "insert or replace into module_configs values(?,0,?,?,?)",
        (FAKE, GROUP, "is_playing", jbool(False)),
    )
    con.commit()
    con.execute("pragma wal_checkpoint(truncate)")
    con.commit()
    con.close()
    print("[db] 已结束虚拟定位（两个模块均已停用）")
    return 0


def apply(db, lat, lng, fake_apk, cell_apk):
    con = sqlite3.connect(db)
    check(con)
    cur = con.cursor()

    for pkg, apk in ((FAKE, fake_apk), (CELL, cell_apk)):
        cur.execute(
            "insert or ignore into modules(module_pkg_name, apk_path) values(?,?)",
            (pkg, apk),
        )
        set_enabled(cur, pkg, True)

    for pkg, apps in ((FAKE, ["system", "com.tencent.mm"]), (CELL, ["com.tencent.mm"])):
        for app in apps:
            cur.execute("insert or ignore into scope values(?,?,0)", (pkg, app))

    loc = '{"latitude":%r,"longitude":%r}' % (lat, lng)
    cur.execute(
        "insert or replace into module_configs values(?,0,?,?,?)",
        (FAKE, GROUP, "last_clicked_location", jstr(loc)),
    )
    cur.execute(
        "insert or replace into module_configs values(?,0,?,?,?)",
        (FAKE, GROUP, "is_playing", jbool(True)),
    )
    cur.execute(
        "insert or replace into module_configs values(?,0,?,?,?)",
        (FAKE, GROUP, "target_apps", jstr('["com.tencent.mm","system"]')),
    )
    con.commit()
    con.execute("pragma wal_checkpoint(truncate)")
    con.commit()
    con.close()
    print("[db] 模块已启用，作用域已写入")
    print("[db] 坐标 = %r, %r" % (lat, lng))
    return 0


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    db = sys.argv[1]
    if sys.argv[2].lower() == "stop":
        return stop(db)
    if len(sys.argv) < 4:
        print(__doc__)
        return 2
    lat = float(sys.argv[2])
    lng = float(sys.argv[3])
    fake_apk = sys.argv[4] if len(sys.argv) > 4 else ""
    cell_apk = sys.argv[5] if len(sys.argv) > 5 else ""
    return apply(db, lat, lng, fake_apk, cell_apk)


if __name__ == "__main__":
    sys.exit(main())
