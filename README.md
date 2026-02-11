# aria2bar

轻量级 macOS 菜单栏工具，用于监控和管理 aria2 下载任务。

## ✨ 特点

- **原生体验**：纯 SwiftUI 开发，零外部依赖，轻量高效
- **菜单栏常驻**：无 Dock 图标，不占用空间
- **实时监控**：全局下载/上传速度一目了然
- **任务管理**：分标签页查看正在下载和已完成任务
- **完整控制**：添加、暂停、恢复、删除下载任务
- **性能优秀**：已完成列表支持分页加载，处理大量任务无压力
- **灵活配置**：支持自定义 RPC 地址和密钥
- **开机自启**：可选开机自动启动

## 📦 安装使用

### 下载安装

从 [Releases](https://github.com/mh567/aria2bar/releases) 下载最新版本，解压后拖入应用程序文件夹即可。

### 配置连接

1. 确保 aria2 已启动并开启 RPC（默认端口 6800）
2. 点击菜单栏图标打开面板
3. 点击底部「Settings」配置连接信息：
   - **RPC URL**: aria2 RPC 地址（默认 `http://localhost:6800/jsonrpc`）
   - **Secret Token**: RPC 密钥（如有设置）
   - **Launch at Login**: 开机自启动选项

## 🛠 开发构建

```bash
# 调试构建
swift build

# 发布构建（生成 .app 包）
bash build.sh
```

## 📋 系统要求

- macOS 13.0+
- aria2 已安装并启用 RPC

## 🔧 技术栈

- **语言**: Swift 5.9+
- **UI 框架**: 纯 SwiftUI
- **依赖管理**: Swift Package Manager
- **网络层**: URLSession + async/await
- **协议**: JSON-RPC 2.0
- **系统框架**: Foundation, ServiceManagement
- **特性**:
  - 零外部依赖
  - 每 2 秒轮询刷新状态
  - @AppStorage 持久化配置
  - SMAppService 开机自启

## 📂 项目结构

```
Sources/aria2bar/
├── aria2barApp.swift       # 应用入口
├── Models.swift            # 数据模型
├── Aria2Client.swift       # JSON-RPC 客户端
├── DownloadManager.swift   # 状态管理
├── ContentView.swift       # 主界面
├── DownloadRowView.swift   # 任务列表项
├── AddDownloadView.swift   # 添加下载
├── SettingsView.swift      # 设置页面
└── Helpers.swift           # 工具函数
```

## 📄 许可证

MIT
