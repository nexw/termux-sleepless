# termux-sleepless

[![CI](https://github.com/nexw/termux-sleepless/actions/workflows/ci.yml/badge.svg)](https://github.com/nexw/termux-sleepless/actions/workflows/ci.yml)
[![Release](https://github.com/nexw/termux-sleepless/actions/workflows/release.yml/badge.svg)](https://github.com/nexw/termux-sleepless/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Termux 在熄屏后经常被系统挂起：CPU 休眠、后台被冻结、网络被切断，SSH、
机器人和同步任务就这么静悄悄地断了。

**termux-sleepless** 是一个 Bash 脚本：请求唤醒锁，并让一个静音媒体会话一直
“在播放”，从而降低 Termux 被系统重新挂起的概率。那段静音文件叫
`insomnia.wav`——65 秒纯数字静音，在设备上直接生成，不需要 ffmpeg、
Python 或任何额外软件包。

> **说清楚边界：** 这不是 Doze 网络豁免，也不能阻止系统杀进程或厂商的省电
> 策略。它的原理只是让 App 看起来一直在忙。使用前请读
> [docs/how-it-works.md](docs/how-it-works.md)。

English: [README.md](README.md)

## 特性

- 单个自包含 Bash 脚本，没有守护进程框架，也没有运行时包装。
- 提供 `start` / `stop` / `restart` / `status` / `logs` / `generate`，以及
  开机自启用的 `install-boot` / `uninstall-boot`。
- 用 `flock` 保证单实例；存活检查会核对命令行的脚本路径和 `_run` 参数，
  不会误杀被复用的 PID。
- 独立的状态目录、大小上限的日志轮转、每次 API 调用都有超时。
- 用 `printf` + `dd` 生成 WAV：不需要编码器，不必把音频文件塞进版本库。
- 开机项只覆盖自己写过的文件，遇到用户的手写文件会拒绝。
- ShellCheck、shfmt 全部通过，每次提交和发版都会跑测试。

## 依赖

- 从 [F-Droid](https://f-droid.org/packages/com.termux/) 或
  [GitHub Releases](https://github.com/termux/termux-app/releases) 安装的
  Termux（Play 商店版本已废弃，无法使用插件）。
- `termux-api`、`coreutils`、`util-linux`：
  `pkg install termux-api coreutils util-linux`。
- 已安装 [Termux:API](https://f-droid.org/packages/com.termux.api/) 应用。
- 可选：[Termux:Boot](https://f-droid.org/packages/com.termux.boot/)，安装后
  需要手动打开一次，用于开机自启。

## 安装

### 用 Release 压缩包

```sh
ver=1.0.0
base="https://github.com/nexw/termux-sleepless/releases/download/v$ver"
curl -fLO "$base/termux-sleepless-$ver.tar.gz"
curl -fLO "$base/termux-sleepless-$ver.tar.gz.sha256"
sha256sum -c "termux-sleepless-$ver.tar.gz.sha256"
tar -xzf "termux-sleepless-$ver.tar.gz"
cd "termux-sleepless-$ver"
./install.sh
```

### 从源码

```sh
pkg install git
git clone https://github.com/nexw/termux-sleepless.git
cd termux-sleepless
./install.sh
```

`install.sh` 会把命令安装到 `$PREFIX/bin/termux-sleepless`（本来就在 `PATH`
里），并打印后续步骤。用 `--dir ~/.local/bin` 可以换目录，`--uninstall`
可以卸载命令。

也可以直接运行仓库里的脚本：

```sh
./bin/termux-sleepless start
```

## 用法

```sh
termux-sleepless start      # 启动后台 worker
termux-sleepless status     # 运行中返回 0，未运行返回 1
termux-sleepless logs -f    # 跟踪日志
termux-sleepless stop       # 停止 worker
```

| 命令 | 说明 |
| --- | --- |
| `start` | 启动 worker（默认命令），可重复执行。 |
| `stop` | 停止 worker，并停掉它启动的静音音轨。 |
| `restart` | 先 `stop` 再 `start`。 |
| `status` | 打印状态；仅在运行中返回 0。 |
| `logs [-f]` | 打印最近 100 行，`-f` 跟踪输出。 |
| `generate` | 生成静音 WAV 并打印路径。 |
| `install-boot` | 安装 `~/.termux/boot/10-sleepless.sh`。 |
| `uninstall-boot` | 删除该开机项。 |
| `version` | 打印版本。 |
| `help` | 打印帮助。 |

状态、日志和生成的音频都在 `~/.local/state/termux-sleepless/`，可以用
`TERMUX_SLEEPLESS_STATE_DIR` 覆盖。日志超过 1 MiB 时，会在下次 `start` 时
轮转为 `sleepless.log.1`。

### 开机自启

```sh
termux-sleepless install-boot
```

需要安装并打开过一次 Termux:Boot，且系统允许 Termux 开机启动。开机项只负责
启动后台 worker。

### 卸载

```sh
termux-sleepless stop
termux-sleepless uninstall-boot
./install.sh --uninstall
rm -rf ~/.local/state/termux-sleepless
```

## 配置项

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `TERMUX_SLEEPLESS_STATE_DIR` | `$XDG_STATE_HOME/termux-sleepless` 或 `~/.local/state/termux-sleepless` | PID、锁、日志和音频所在目录。 |
| `TERMUX_SLEEPLESS_BOOT_FILE` | `~/.termux/boot/10-sleepless.sh` | `install-boot` 写入的路径。 |

## 原理简要

1. 用 `termux-wake-lock` 持有 Termux App 的共享唤醒锁。
2. 只生成一次 65 秒 PCM 静音 WAV：44 字节固定头加全零采样。
3. worker 让 Termux:API 播放它，每 60 秒重复一次，让音轨前后重叠，而不是留出
   空档。

得到的是“这个 App 看起来一直在忙”；得不到的是 Doze 网络豁免、免于被低内存
杀手回收，或者对抗厂商的“电池优化”。完整说明和限制见
[docs/how-it-works.md](docs/how-it-works.md)。

## 文档

- [安装](docs/installation.md)
- [原理与边界](docs/how-it-works.md)
- [故障排查](docs/troubleshooting.md)
- [更新日志](CHANGELOG.md)

## 开发

```sh
make check    # shellcheck + shfmt + 测试
make test     # bash tests/run-tests.sh
make dist     # 生成 dist/termux-sleepless-<version>.tar.gz 与 sha256
```

测试用假命令替代 Termux:API，因此在 Linux CI 和手机上都能跑。发版流程见
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可

[MIT](LICENSE)
