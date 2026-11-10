#!/system/bin/sh
# Magisk 模块开机自启入口：后台拉起 rightback 守护脚本，然后立刻退出，不阻塞开机流程。
MODDIR=${0%/*}
LOG=/data/local/tmp/rightback.log

(
    sleep 12
    # 清掉可能残留的旧实例，保证只有一份在监听
    pkill -f "/data/adb/modules/rightback/rightback.sh" 2>/dev/null
    sleep 1
    exec sh "$MODDIR/rightback.sh"
) >/dev/null 2>&1 &

exit 0
