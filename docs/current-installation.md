# Termux keepalive

实现：`~/.local/bin/termux-keepalive`
开机入口：`~/.termux/boot/10-keepalive.sh`
交互命令：`.zshrc` 中的 `keepalive` 只是转发参数，不会在打开终端时自动启动。

## 用法

```sh
~/.local/bin/termux-keepalive start
~/.local/bin/termux-keepalive status
~/.local/bin/termux-keepalive stop
~/.local/bin/termux-keepalive install-boot
~/.local/bin/termux-keepalive uninstall-boot
```

默认参数为 start。已加载新 .zshrc 的终端可直接用 `keepalive status` 等。
日志：`~/.local/state/termux-keepalive/keepalive.log`。超过 1 MiB 时在下次 start 保留为 .1；不是实时日志轮转。

## 原理与改进

旧函数获取 Termux app 的 CPU 唤醒锁，再通过 nohup 的 shell 循环每 60 秒播放 quiet_1min.amr。
意图：唤醒锁防 CPU 休眠，无声媒体尝试维持 Android 媒体活跃状态，nohup 让循环脱离终端存活。
后两者并不保证抵抗系统强杀、厂商省电策略或 Android 的其他后台限制。
旧 AMR 实际时长约 65 秒，每 60 秒会重启播放；不是无缝循环。

新实现提供 flock 单实例、PID 校验、start/stop/status、API 调用超时与失败重试、日志和 Boot 安装入口。
循环仍是每次发起播放后等 60 秒，不保证无缝、采样级连续播放。未增加 ffmpeg、Python、Node 等依赖。

## 无 ffmpeg 的静音文件

printf 写入固定 WAV 头（RIFF/WAVE，PCM，单声道，8000 Hz，16 bit），dd 从 /dev/zero 写入 960000 字节采样。
有符号 PCM 中全零就是数字静音。文件共 960044 字节，时长 60 秒，Android MediaPlayer 已实际播放验证。
生成只用 Bash 内建 printf 和 Termux 已有的 coreutils dd/mv；不是新增工具依赖，也不是完全不依赖任何系统工具。
生成命令：`termux-keepalive generate`。文件存在就复用，无需每分钟重建。
相较旧 AMR（42269 字节）约占 0.96 MB 磁盘，但避免编码器与编解码器生成依赖。
ffprobe 仅用于开发验证，不是脚本依赖。

## 开机与限制

设备已安装 com.termux.boot 和 com.termux.api。仍需用户曾打开 Termux:Boot 一次，并允许其开机启动；
Termux 与相关插件应来自兼容签名来源，关闭相关 App 的电池优化/厂商后台限制。
真实重启后的启动行为尚未验证，开机脚本只启动后台 worker，不阻塞后续 Boot 脚本。

Termux:API 的 media-player 是共用播放器：运行期间每分钟会覆盖通过它发起的其他播放。
stop 只在播放器当前曲目名为 silence-60s.wav 时请求停止播放。
唤醒锁是 app 级共享状态，不是本进程独占资源；现有 boot.sh 和 20-ditingd.sh 也请求它，故 stop 不释放它。
完全撤销此功能：stop + uninstall-boot；不要随意执行 termux-wake-unlock 影响其他服务。
如仅需防 CPU 休眠，可不用播放，仅保留现有唤醒锁与电池优化豁免；抗后台清理效果需具体设备实测。
静音音频不等于零功耗，无法以脚本保证永不被杀。

旧文件 ~/.termux/quiet_1min.amr 原样保留。原 .zshrc 的带时间戳备份位于 HOME。
