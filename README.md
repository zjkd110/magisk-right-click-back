# 鼠标右键返回键（Magisk 模块）

把**鼠标右键**映射成**返回键**，桌面、系统界面、任意 App 全局生效 —— 不依赖 LSPosed 作用域，不需要逐个 App 勾选。

适用于鼠标没有侧键、或侧键在当前系统上不起作用的 Android TV 盒子 / 手机 / 平板。已在 Amlogic S905L3A（Android 12）真机盒子与 Android 14 模拟器上实测。

## 原理

`getevent -l` 读内核输入层，捕获鼠标右键 `BTN_RIGHT`(273) 按下 → 向「支持 `KEY_BACK` 的内置按键设备」注入 `KEY_BACK`(158) 按下+抬起 → 系统 InputReader 翻译成 `KEYCODE_BACK`(4) 交给当前前台窗口。

因为发生在输入层，不针对任何 App，所以是真正全局的：桌面、系统设置、任何第三方 App 都生效。

为什么不走 LSPosed：LSPosed 是按进程注入，模块只注入到作用域里勾选的 App，一个模块吃不到全局（新装 App 还要补勾）；改系统框架又有 bootloop 风险。

## 安装

**方式一：Magisk App 本地安装**
1. 下载 Release 里的 `rightback_v1.5.zip`
2. Magisk App → 模块 → 从本地安装 → 选择该 zip
3. 重启

**方式二：命令行**
```sh
adb push rightback_v1.5.zip /data/local/tmp/
adb shell su -c "magisk --install-module /data/local/tmp/rightback_v1.5.zip"
# 重启生效
```

安装后模块目录为 `/data/adb/modules/rightback`，由 `service.sh` 在开机阶段自动启动，不阻塞开机。

## 验证

```sh
# 实时看日志，每次右键会记录一条
adb shell su -c "tail -f /data/local/tmp/rightback.log"
```

正常情况下打开任意界面点右键，日志出现：

```
[rightback] 观察到 BTN_RIGHT 来自 /dev/input/eventX
[rightback] BTN_RIGHT -> 返回
```

## 切换触发键（可选）

`/data/adb/modules/rightback/trigger.conf` 一行文本，改完重启守护进程即可：

| 想映射的键 | trigger.conf 内容 |
|---|---|
| 鼠标右键（默认） | `BTN_RIGHT` |
| 鼠标侧键（前/后） | `BTN_SIDE BTN_EXTRA` |
| 都要 | `BTN_RIGHT BTN_SIDE BTN_EXTRA` |

```sh
adb shell su -c "echo 'BTN_RIGHT BTN_SIDE BTN_EXTRA' > /data/adb/modules/rightback/trigger.conf"
adb shell su -c "pkill -f /data/adb/modules/rightback/rightback.sh; sh /data/adb/modules/rightback/service.sh"
```

## 常见问题

**Magisk 安装时报 `! Unzip error`**
说明用的 zip 打包方式不标准。本仓库 v1.5 的 zip 用 bsdtar 打包并带官方模板 `META-INF/com/google/android/{update-binary,updater-script}`，可正常安装。自己改包时别用 Windows 的 `Compress-Archive` —— 打出来的包 Magisk 解不出成员，必然报这个错。

**按键按了没反应**
先看日志有没有 `观察到 ...` 这一行：
- 有 `观察到` 但没有 `-> 返回`：注入设备可能不认 `KEY_BACK`，看日志里的 `注入设备` 那台设备。
- 完全没有 `观察到`：说明系统根本没收到这个键。常见于模拟器 / 云手机 / 远程桌面把鼠标按键自己吃掉了，或者该设备的能力位里没有这个键（例如宿主只声明 `BTN_LEFT/BTN_RIGHT/BTN_MIDDLE`，侧键根本不会下发）。这种情况模块无能为力。

**注入设备是怎么选的**
按 `KEY_BACK` 能力位自动探测，优先名字含 `keypad/gpio/keyboard/rcu/input` 的设备（电视盒子会选中 `aml_keypad`），找不到则回退 `input keyevent 4`。所以重启后 `/dev/input/eventN` 编号变化不影响使用。

## 卸载

```sh
adb shell su -c "rm -rf /data/adb/modules/rightback"
# 重启
```
或在 Magisk App 的模块页里直接移除并重启。

## 已知限制

- 右键事件本身仍会传给应用，极少数自带右键菜单的 App 可能出现"弹菜单 + 同时返回"。
- 鼠标热插拔后监听会自行重连（脚本内置 `getevent` 退出后 2 秒重连）。

## 许可证

MIT，见 [LICENSE](LICENSE)。
