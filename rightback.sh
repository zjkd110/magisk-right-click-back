#!/system/bin/sh
# rightback —— 鼠标右键(BTN_RIGHT) 全局映射为 返回键(KEYCODE_BACK)
# 原理：读内核输入设备 /dev/input/event*，发现右键按下，向「支持 KEY_BACK 的内置键设备」
#       注入 KEY_BACK(158)，由 InputReader 转成 KEYCODE_BACK(4) 发给当前前台应用。
# 不依赖任何 App / LSPosed 作用域：桌面、系统界面、任意 App 全部生效。
# v1.5：正式版。触发键默认鼠标右键，可用 trigger.conf 改成侧键；
#       注入设备按 KEY_BACK 能力位自动探测（盒子 aml_keypad / 手机 AT 键盘都能选对）。

VER=v1.5
LOG=/data/local/tmp/rightback.log
export PATH="/system/bin:/system/xbin:$PATH"

# 触发键，默认右键；改 trigger.conf 可换成 BTN_SIDE / BTN_EXTRA
TRIGGERS="BTN_RIGHT"
CONF="$(dirname "$0")/trigger.conf"
[ -f "$CONF" ] && [ -n "$(cat "$CONF" 2>/dev/null)" ] && TRIGGERS="$(cat "$CONF")"

log() { echo "$(date '+%m-%d %H:%M:%S') [rightback] $*" >>"$LOG"; }
dev_name() { cat "/sys/class/input/event$1/device/name" 2>/dev/null; }
has_key_back() { getevent -pl "$1" 2>/dev/null | grep -qw KEY_BACK; }

# 找能承载 KEY_BACK 的输入设备：优先键类设备（keypad/gpio/keyboard/rcu/input），其次任意带 KEY_BACK 的
find_keydev() {
    fallback=""
    for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        d="/dev/input/event$n"
        [ -e "$d" ] || continue
        has_key_back "$d" || continue
        nm="$(dev_name $n)"
        case "$nm" in
            *keypad*|*gpio*|*keyboard*|*rcu*|*input*) echo "$d"; return 0 ;;
        esac
        [ -z "$fallback" ] && fallback="$d"
    done
    [ -n "$fallback" ] && echo "$fallback"
}

BACKDEV="$(find_keydev)"
if [ -n "$BACKDEV" ]; then
    MODE=sendevent
    log "启动 $VER，注入设备 = $BACKDEV ($(dev_name ${BACKDEV##*/event}))"
else
    MODE=input
    log "启动 $VER，未找到支持 KEY_BACK 的设备，回退 input keyevent 4"
fi

inject_back() {
    if [ "$MODE" = "sendevent" ]; then
        sendevent "$BACKDEV" 1 158 1
        sendevent "$BACKDEV" 0 0 0
        sendevent "$BACKDEV" 1 158 0
        sendevent "$BACKDEV" 0 0 0
    else
        input keyevent 4
    fi
}

log "开始监听 [$TRIGGERS]"
while true; do
    getevent -l 2>/dev/null | while read -r DEV TYPE CODE VAL; do
        [ "$TYPE" = "EV_KEY" ] || continue
        [ "$VAL" = "DOWN" ] || continue
        # 只记录鼠标按键，键盘/遥控器不落日志
        case "$CODE" in
            BTN_LEFT|BTN_RIGHT|BTN_MIDDLE|BTN_SIDE|BTN_EXTRA)
                log "观察到 $CODE 来自 ${DEV%:}" ;;
        esac
        for t in $TRIGGERS; do
            if [ "$CODE" = "$t" ]; then
                inject_back
                log "$t -> 返回"
                break
            fi
        done
    done
    # 设备热插拔会让 getevent 退出，稍等后重连
    log "getevent 退出，2 秒后重连"
    sleep 2
done
