# AriaPilot

![AriaPilot 产品预览](assets/ariapilot-hero.svg)

AriaPilot 是一个 macOS 菜单栏下载管理工具，基于 aria2 JSON RPC 管理下载任务。它既可以连接远程 aria2 服务，也可以在本机安装并管理内置 aria2 后端，把应用直接作为完整下载器使用。

## 核心功能

1. 菜单栏实时查看下载状态、全局速度和任务列表
2. 添加、暂停、继续、删除下载任务
3. 支持下载中、等待、暂停、错误等状态角标
4. 支持独立下载任务窗口，适合管理较多任务
5. 支持本机下载服务和远程 aria2 服务两种模式
6. 支持一键安装、启动、重启、停止、卸载本机 aria2 服务
7. 支持本机已完成任务记录持久化
8. 支持删除任务时选择是否同时删除已下载文件
9. 支持登录时启动和应用内检查更新
10. 内置 macOS ARM64 aria2 后端，构建前可自动同步最新 vendor 更新

## 下载

打开 [GitHub Releases](https://github.com/mh567/AriaPilot/releases)，下载最新的 `AriaPilot-vx.x.x-macos.zip`。

解压后把 `AriaPilot.app` 拖入“应用程序”即可使用。

## 使用方式

AriaPilot 支持两类连接模式：

1. 本机下载服务：由 AriaPilot 管理本机 aria2 后端，适合作为独立下载器使用。
2. 远程 aria2 服务：连接 NAS、服务器或其他设备上的 aria2 RPC 服务。

详细安装、配置和使用说明见 [使用说明](docs/USER_GUIDE.md)。

## 系统要求

1. macOS 13.0 或更高版本
2. Apple Silicon Mac

如果使用远程 aria2 服务，需要远端服务已开启 JSON RPC。

## 开发构建

```bash
swift build
bash build.sh
```

发布构建会生成：

```text
AriaPilot.app
AriaPilot-vx.x.x-macos.zip
```

构建脚本会在编译前检查 bundled aria2 vendor 更新 PR。若存在安全的 vendor 更新，会先合并并拉取最新二进制，再继续打包。

## 技术栈

1. Swift
2. SwiftUI
3. Swift Package Manager
4. aria2 JSON RPC
5. ServiceManagement

## 许可证

MIT
