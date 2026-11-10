# 鼠标右键返回键（Right Click = Back）

给 Android TV / 电视盒子用的 Magisk 模块：**把鼠标右键全局映射成返回键**。

不需要 LSPosed、不需要勾选任何 App 作用域，装完重启即可 —— 桌面、系统界面、任意 App 里点一下鼠标右键就等于按了一次返回键。

## 适用场景

很多电视盒子/盒子固件上，鼠标右键默认什么都不做，而返回只能靠遥控器或鼠标侧键。如果你的鼠标没有侧键，盒子上就没法返回上一级。这个模块把右键变成返回键，一只普通鼠标就能完整操作盒子。

## 原理

```
鼠标右键 BTN_RIGHT(273)  →  getevent 监听 /dev/input/event*
        ↓
向内置按键设备 aml_keypad 注入 KEY_BACK(158) 按下 + 抬起
        ↓
系统 InputReader 翻译成 KEYCODE_BACK(4)，投递给当前前台窗口
```

全程在输入层完成，不修改系统框架、不依赖任何注入框架，所以对任何 App 都生效，也不存在开机循环（bootloop）风险。

## 为什么不用 LSPosed

LSPosed 是按进程注入：一个模块只会注入到你勾选作用域里的 App，做不到"一次配置吃全局"，新装 App 还得补勾。
要真正全局只有两条路：

| 方案 | 全局性 | 风险 |
|---|---|---|
| Hook 系统框架（`android` 作用域拦输入） | 全局 | 高，改错会开机循环 |
| **输入层重映射（本模块）** | 全局 | 低，纯脚本，删掉即恢复 |

## 安装

### 方式一：Magisk 刷入（推荐）

1. 下载 [Releases](../../releases) 里的 `rightback_v1.1.zip`
2. 打开 Magisk App → 模块 → 从本地安装 → 选这个 zip
3. 重启

### 方式二：手动放置

```sh
adb push module.prop service.sh rightback.sh /data/local/tmp/
adb shell su -c "mkdir -p /data/adb/modules/rightback && \
  cp /data/local/tmp/{module.prop,service.sh,rightback.sh} /data/adb/modules/rightback/ && \
  chmod 755 /data/adb/modules/rightback/*.sh"
# 重启，或立刻生效：
adb shell su -c "sh /data/adb/modules/rightback/service.sh"
```

## 使用与排查

```sh
# 看日志：每次右键命中都会记录一条
adb shell su -c "tail -f /data/local/tmp/rightback.log"

# 临时停用（重启后会自动恢复）
adb shell su -c "pkill -f rightback.sh"

# 手动重启守护进程
adb shell su -c "sh /data/adb/modules/rightback/service.sh"

# 彻底卸载（删目录后重启）
adb shell su -c "rm -rf /data/adb/modules/rightback"
```

日志正常长这样：

```
[rightback] 启动，KEY_BACK 注入设备 = /dev/input/event0
[rightback] 开始监听右键(BTN_RIGHT)
[rightback] 右键 -> 返回
```

## 兼容性

- 在 Amlogic S905L3A / Android 12 盒子上实测通过（重启后自动生效、系统设置界面点右键即返回）
- 注入设备按名字 `aml_keypad` 自动探测，重启后输入节点编号变化（event0/event5/event6 乱跳）不影响使用
- 只要系统里有内置按键设备（几乎所有盒子都有），就能用；`getevent` 是 Android 自带 toybox 命令，无需额外依赖

## 已知限制

- 右键事件本身仍会传给应用：极少数自带右键菜单的 App 可能出现"弹菜单 + 同时返回"的双动作
- 鼠标热插拔后，新插入的设备不在已启动的监听列表里，重启一次即可恢复
- 需要 Magisk / KernelSU 等 root 环境（要读写 `/dev/input` 与 `/data/adb`）

## 许可

MIT
