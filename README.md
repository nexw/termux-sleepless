# termux-net-keepalive

Termux 熄屏网络保活实验：通过唤醒锁和静音音频播放，尝试缓解 Android／厂商电源策略导致的后台网络中断。

**当前是现有实现与实验的归档，尚未接入“熄屏播放／亮屏停止”。不保证获得 Doze 豁免。**

## 目录

- `scripts/termux-keepalive`：当前已部署脚本的快照，支持 start / stop / status / generate / install-boot / uninstall-boot。
- `experimental/screen-probe/`：以 app_process 运行的 Java 显示状态监听实验及编译桩。
- `docs/findings.md`：机制、实测结果和下一步。
- `docs/current-installation.md`：当前设备上现有安装的操作说明。

仓库名采用 termux-net-keepalive；现有脚本名暂保留 termux-keepalive，避免此次归档改变已部署行为。

## 当前保活脚本

运行环境：Termux Bash、coreutils、flock、termux-api 命令，以及 Android Termux:API 插件。
开机自启另外需要 Termux:Boot，安装后打开一次并允许后台运行。

现有脚本按固定部署位置自调用，因此不要直接在仓库里执行 start 或 install-boot：

```sh
mkdir -p ~/.local/bin
install -m 700 scripts/termux-keepalive ~/.local/bin/termux-keepalive
~/.local/bin/termux-keepalive start
~/.local/bin/termux-keepalive status
# 可选，写入 ~/.termux/boot/10-keepalive.sh：
~/.local/bin/termux-keepalive install-boot
```

音频通过 Bash printf 和 dd 直接生成 60 秒 PCM WAV，不需要 ffmpeg、Python、Node。
stop 不释放 Termux app 级共享唤醒锁，避免影响其他服务。
播放器是 Termux:API 共用资源，运行期间会覆盖通过它发起的其他播放。

## 构建和运行屏幕状态实验

需要本机已有的 JDK 与 d8（默认使用 $PREFIX/share/java/d8.jar）。
编译桩只用于编译，不包含在最终 DEX 中；运行时使用 Android 系统类。

```sh
bash experimental/screen-probe/build.sh
# 前台监听 15 分钟，按 Ctrl-C 退出：
bash experimental/screen-probe/listen.sh
```

实验只打印事件，不控制音频、电源或网络。
默认屏幕 id=0：1=OFF、2=ON、3=DOZE、4=DOZE_SUSPEND。
Display 的 DOZE 状态不等于设备的 Doze 省电状态。

已在当前 Android 16 小米设备上实测收到 OFF → ON。
SCREEN_OFF/ON 广播注册仅用于诊断，系统返回的过滤器为空，不能视为成功注册。
短时测试通过不代表长期后台稳定或其他 Android 版本兼容。

## 部署状态

创建仓库时未修改现有 ~/.local/bin、.zshrc 或 Boot 入口；也未创建远端。
生成音频、PID、日志、构建产物不进入版本控制。
