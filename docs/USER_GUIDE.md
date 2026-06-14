# AriaPilot 使用说明

本文档介绍 AriaPilot 的安装、连接模式、下载管理、本机服务、删除策略、更新和开发构建。

## 安装应用

1. 打开 [Releases](https://github.com/mh567/AriaPilot/releases)
2. 下载最新的 `AriaPilot-vx.x.x-macos.zip`
3. 解压后把 `AriaPilot.app` 拖入“应用程序”
4. 启动 AriaPilot

首次启动后，建议先打开设置，选择需要使用的连接模式。

## 连接模式

AriaPilot 支持“本机下载服务”和“远程 aria2 服务”。

### 本机下载服务

本机下载服务由 AriaPilot 管理本机 aria2 后端。适合希望打开应用即可下载的场景。

本机服务默认使用：

```text
RPC URL: http://localhost:6800/jsonrpc
下载路径: ~/Downloads/AriaPilot
LaunchAgent: ~/Library/LaunchAgents/com.ariapilot.aria2.plist
配置目录: ~/Library/Application Support/AriaPilot/aria2
```

在设置中选择“本机下载服务”后，可以执行：

1. 安装服务：安装并启动本机 aria2 后端
2. 启动：启动已安装的本机服务
3. 重启：重启已安装的本机服务
4. 停止：停止本机服务
5. 卸载服务：停止服务并移除 LaunchAgent
6. 检测服务：刷新本机服务状态和版本信息

当保存的连接模式为“本机下载服务”时，应用启动后会尝试拉起本机后端。若连接模式为“远程 aria2 服务”，应用不会自动启动本机后端。

### 远程 aria2 服务

远程模式适合连接 NAS、服务器或其他设备上的 aria2。

常见 aria2 RPC 启动示例：

```bash
aria2c --enable-rpc --rpc-listen-all=true --rpc-listen-port=6800 --rpc-secret=123456
```

AriaPilot 中填写：

```text
RPC URL: http://服务器地址:6800/jsonrpc
密钥: 123456
```

如果 aria2 只允许本机监听，请确认远端 aria2 的监听地址、防火墙和网络访问权限。

## 下载路径

设置中的下载路径是 aria2 服务端能访问的路径。

本机下载服务中，路径位于当前 Mac。远程模式中，路径位于远程机器，例如 NAS 或服务器。

示例：

```text
/downloads
/volume1/downloads
D:\Downloads
```

留空时使用 aria2 的默认下载位置。

## 添加下载任务

可以在菜单栏面板中手动输入下载链接，也可以点击输入框右侧的粘贴按钮，从剪贴板导入下载链接。

添加任务后，AriaPilot 会通过当前连接模式对应的 aria2 RPC 创建下载任务。

## 下载列表和已完成列表

下载中列表来自 aria2 当前活跃任务。

已完成列表由两部分组成：

1. aria2 RPC 返回的已停止任务
2. AriaPilot 本机保存的历史任务记录

本机历史记录保存在：

```text
~/Library/Application Support/AriaPilot/download-history.json
```

如果 aria2 服务端没有保留历史结果，AriaPilot 仍会尽量展示本机保存过的已完成记录。若文件已经被手动删除，删除任务时会自动容忍文件缺失。

## 删除任务和文件

删除任务时，AriaPilot 会提示删除方式：

1. 只删除任务
2. 同时删除已下载文件

可以勾选记住选择。默认删除方式可在设置中修改。

远程模式下，AriaPilot 通过 aria2 JSON RPC 删除任务记录。由于 aria2 RPC 没有通用的安全文件删除接口，远程文件删除不会自动执行。若需要删除远程文件，请在远端文件管理器或服务端脚本中处理。

本机下载服务下，选择同时删除文件时，AriaPilot 会尝试删除本机下载文件。若文件已不存在，删除任务流程会继续完成。

## 菜单栏图标状态

AriaPilot 的菜单栏图标会基于当前任务状态显示黑白角标：

1. 下载中：右下角实心点
2. 等待中：右下角空心点
3. 暂停：右下角暂停标识
4. 连接失败或任务错误：右上角感叹号

## 应用内更新

设置窗口提供“检查更新”和“立即更新”。

更新来源为 GitHub Releases。下载完成后，AriaPilot 会校验安装包中的 bundle id 和版本号，再替换当前应用并重新打开。

## 开发构建

调试构建：

```bash
swift build
```

发布构建：

```bash
bash build.sh
```

发布构建会生成：

```text
AriaPilot.app
AriaPilot-vx.x.x-macos.zip
```

构建脚本会把下面的内置后端复制进 app bundle：

```text
vendor/aria2/darwin-arm64/aria2c
vendor/aria2/darwin-arm64/lib
```

## 内置 aria2 更新机制

官方 aria2 Release 当前没有 macOS ARM64 预编译包。仓库内的 `Update bundled aria2` workflow 会在 macOS ARM runner 上从官方源码编译 `aria2c`，更新 vendor 二进制并创建 PR。

执行发布构建时，`build.sh` 会先运行 bundled aria2 vendor 检查。如果存在符合规则的更新 PR，脚本会自动合并并拉取最新 vendor 文件，然后继续打包。

如需跳过编译前检查：

```bash
CHECK_VENDOR_UPDATE=0 bash build.sh
```
