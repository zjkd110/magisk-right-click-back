#!/system/bin/sh
# rightback —— 鼠标右键(BTN_RIGHT) 全局映射为 返回键(KEYCODE_BACK)
# 原理：直接读内核输入设备 /dev/input/event*，发现 BTN_RIGHT 按下，
#       向内置键设备注入 KEY_BACK(158)，由 InputReader 转成 KEYCODE_BACK(4) 发给当前前台应用。
# 不依赖任何 App / LSPosed 作用域，桌面、系统界面、任意 App 全部生效。

LOG=/data/local/tmp/rightback.log

log() { echo "$(date '+%m-%d %H:%M:%S') [rightback] $*" >>"$LOG"; }

# 找出能承载 KEY_BACK 的内置键设备（优先 aml_keypad，其次带 keypad/keys/rcu 字样的设备）
find_keydev() {
    for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        [ -e "/dev/input/event$n" ] || continue
        case "$(cat "/sys/class/input/event$n/device/name" 2>/dev/null)" in
            aml_keypad) echo "/dev/input/event$n"; return 0 ;;
        esac
    done
    for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        [ -e "/dev/input/event$n" ] || continue
        case "$(cat "/sys/class/input/event$n/device/name" 2>/dev/null)" in
            *keypad*|*keys*|*rcu*) echo "/dev/input/event$n"; return 0 ;;
        esac
    done
    echo "/dev/input/event0"
}

BACKDEV="$(find_keydev)"
log "启动，KEY_BACK 注入设备 = $BACKDEV"

inject_back() {
    sendevent "$BACKDEV" 1 158 1
    sendevent "$BACKDEV" 0 0 0
    sendevent "$BACKDEV" 1 158 0
    sendevent "$BACKDEV" 0 0 0
}

log "开始监听右键(BTN_RIGHT)"
while true; do
    getevent -l 2>/dev/null | while read -r LINE; do
        case "$LINE" in
            *BTN_RIGHT*DOWN*)
                inject_back
                log "右键 -> 返回"
                ;;
        esac
    done
    log "getevent 退出，2 秒后重启监听"
    sleep 2
done
