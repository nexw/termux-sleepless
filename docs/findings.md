# Findings and scope

## Purpose and mechanisms

用户目标是缓解熄屏电源策略中断 Termux 网络，不只是避免进程退出。
音频焦点协调多个应用的播放／暂停／音量，不是正式的 Doze 网络豁免。
Termux:API 上游当前 MediaPlayerAPI 使用实际媒体播放与 PARTIAL_WAKE_LOCK，
未发现 requestAudioFocus 调用。本机已安装 APK 未做反编译核对。

Android Doze 可以暂停网络访问并忽略普通唤醒锁，因此 CPU 唤醒锁不等于网络豁免。
正式电池优化豁免和厂商后台设置应单独处理。
静音音频是否改变本机省电策略、是否实际改善网络，尚未做对照测试。

## Existing audio loop

旧 .zshrc 函数获取唤醒锁，nohup shell 每 60 秒播放 quiet_1min.amr。
旧文件实测约 65 秒，新脚本生成恰好 60 秒 WAV。
调用／调度可能令新循环产生小空档；后续应考虑恢复“音频时长大于重播周期”的余量。
此仓库先保留原实现，不在归档过程中暗改逻辑。

## Screen event experiment

环境：当前小米 Android 16，普通 Termux UID；无需 root、ADB、Tasker。
通过 javac + d8 构建，app_process 加载只读 DEX。

1. ActivityThread.systemMain 创建上下文后调用 registerReceiver，没有异常。
2. 未收到 SCREEN_OFF/ON；进一步查询 getRegisteredIntentFilters 返回 []。
3. AOSP 新版 BroadcastController 在找不到调用方 ProcessRecord 时可以直接返回 null，
   与现象相符；未取得本机 system_server 日志确认内部具体分支。
4. 改用 DisplayManager.registerDisplayListener，实测收到：

```text
2026-11-17T07:22:51.751610Z DISPLAY onDisplayChanged id=0 state=1
2026-11-17T07:22:58.456383Z DISPLAY onDisplayChanged id=0 state=2
```

这是显示状态回调，不是屏幕广播，也不是轮询。
Display.STATE_DOZE 表示显示设备状态，不证明设备进入 Android Doze。
尚未验证长时间熄屏、系统回收、重启及跨设备兼容性。

## Next steps (not implemented)

- 将显示状态监听与音频 worker 解耦：OFF 启动、ON 停止，处理 DOZE 等状态。
- 启动时读取当前状态，并对重复状态回调去重。
- 管理监听器生命周期，避免重复监听和孤儿进程。
- 改进音频时长／重播周期余量。
- 对照测试电池豁免、唤醒锁、静音播放各自对熄屏网络的效果。
- 不将显示回调或音频活跃表述为“获得 Doze 豁免”。

## References

- https://developer.android.com/media/optimize/audio-focus
- https://developer.android.com/training/monitoring-device-state/doze-standby
- https://developer.android.com/reference/android/content/Intent#ACTION_SCREEN_OFF
- https://developer.android.com/reference/android/hardware/display/DisplayManager.DisplayListener
- https://github.com/termux/termux-api/blob/master/app/src/main/java/com/termux/api/apis/MediaPlayerAPI.java
- https://github.com/aosp-mirror/platform_frameworks_base/blob/master/services/core/java/com/android/server/am/BroadcastController.java
