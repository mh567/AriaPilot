# aria2bar

轻量级 macOS 菜单栏工具，用于监控和管理 aria2 下载任务。

## 功能

- 菜单栏常驻，无 Dock 图标
- 实时显示全局下载/上传速度
- 分标签页查看「正在下载」和「已完成」任务
- 支持添加、暂停、恢复、删除下载任务
- 已完成列表支持分页加载
- 可配置 aria2 RPC 地址和密钥
- 支持开机自启动

## 系统要求

- macOS 13.0+
- aria2 已安装并启用 RPC

## 构建

```bash
# 调试构建
swift build

# 发布构建（生成 .app 包）
bash build.sh
```

## 使用

### 1. 启动 aria2

```bash
# 最简启动
aria2c --enable-rpc

# 带密钥启动
aria2c --enable-rpc --rpc-secret=YOUR_SECRET
```

### 2. 启动 aria2bar

```bash
open aria2bar.app
```

菜单栏会出现一个下载图标，点击即可打开面板。

### 3. 配置连接

首次使用请点击底部「Settings」按钮，配置：

| 选项 | 说明 | 默认值 |
|------|------|--------|
| RPC URL | aria2 RPC 接口地址 | `http://localhost:6800/jsonrpc` |
| Secret Token | RPC 密钥（可选） | 空 |
| Launch at Login | 开机自启动 | 关闭 |

## 项目结构

```
aria2bar/
├── Package.swift              # Swift Package Manager 配置
├── build.sh                   # 发布构建脚本
├── README.md
└── Sources/aria2bar/
    ├── aria2barApp.swift       # 应用入口，MenuBarExtra
    ├── Models.swift            # 数据模型（Download, GlobalStat, JSON-RPC）
    ├── Helpers.swift           # 字节/速度格式化工具
    ├── Aria2Client.swift       # aria2 JSON-RPC 网络层
    ├── DownloadManager.swift   # 状态管理、轮询逻辑
    ├── ContentView.swift       # 主面板视图（标签页、速度栏）
    ├── DownloadRowView.swift   # 单条下载任务行
    ├── AddDownloadView.swift   # 添加下载表单
    └── SettingsView.swift      # 设置页面
```

## 技术细节

- **语言**: Swift 5.9+，纯 SwiftUI
- **零外部依赖**: 仅使用系统框架（SwiftUI、Foundation、ServiceManagement）
- **网络**: URLSession + async/await，JSON-RPC 2.0 协议
- **轮询**: 每 2 秒刷新一次下载状态
- **分页**: 已完成列表每页 30 条，支持「加载更多」
- **持久化**: @AppStorage 存储 RPC 配置
- **开机自启**: SMAppService（macOS 13+）

## 许可证

MIT
