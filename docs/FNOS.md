# AriaPilot fnOS 版

AriaPilot fnOS 版是面向飞牛私有云 fnOS 的下载管理应用，以 FPK 形式安装。它自带独立的 aria2 引擎，与飞牛自带下载中心互不影响，可以管理下载任务、查看实时进度、修改下载目录和常用配置。

## 功能

1. 添加 HTTP、HTTPS、FTP、磁力链接和 `.torrent` 种子任务
2. 实时查看任务进度、下载速度、上传速度、连接数和剩余时间
3. 暂停、继续、删除任务，删除时可选择同时删除已下载文件
4. 已完成任务历史持久化，重启后仍可查看
5. 在已授权目录中选择和修改下载目录
6. 配置并发任务数、每任务连接数、分片数、全局下载与上传限速
7. 支持内置 aria2 引擎和连接已有 aria2 RPC 两种模式
8. 双架构 FPK，分别面向 x86 与 ARM 飞牛设备

## 与飞牛自带下载中心的关系

飞牛自带下载中心由 `dlcenter`、`trim-aria2c` 和 `trim-qbittorrent-nox` 组成，其中直链下载使用 aria2，BT 与磁力下载使用 qBittorrent。这套服务没有对外公开的 RPC 接口。

AriaPilot fnOS 版不接管系统下载中心，安装后会在应用自己的目录中启动一个独立的 aria2c，RPC 只监听 `127.0.0.1`，密钥自动生成且不会下发到浏览器。两套下载服务可以同时存在。

## 系统要求

1. fnOS 1.1.8 或更高版本
2. 应用中心可用的 `nodejs_v22` 运行时
3. 已授权至少一个可写目录

应用安装时会通过 `install_dep_apps` 自动安装 `nodejs_v22`。运行身份是应用专用用户 `ariapilot`，不使用 root。

## 构建

在仓库根目录执行：

```bash
bash scripts/build_fpk.sh --arch all
```

也可以只构建单个架构：

```bash
bash scripts/build_fpk.sh --arch x86
bash scripts/build_fpk.sh --arch arm
```

构建流程会完成以下工作：

1. 从 `assets/app-icon.svg` 生成 64 与 256 像素图标
2. 检查 `vendor/aria2/linux-amd64/aria2c` 与 `vendor/aria2/linux-arm64/aria2c`，缺失时调用 `scripts/fetch_aria2_linux.sh` 下载静态二进制
3. 组装 `fnos/build/<arch>/`，其中 `app/` 包含服务端、前端和对应架构的 aria2
4. 优先使用官方 `fnpack` 打包，未安装时自动下载到 `.tools/fnpack`
5. 校验包结构、manifest 架构与 `app.tgz` 校验和

产物：

```text
dist/ariapilot_1.0.7_x86.fpk
dist/ariapilot_1.0.7_arm.fpk
```

如果构建机无法联网，可以提前把 aria2 二进制放到 `vendor/aria2/linux-amd64/` 和 `vendor/aria2/linux-arm64/`，并设置 `FNOS_SKIP_FNPACK_DOWNLOAD=1` 使用内置打包器。

## 安装

1. 打开飞牛应用中心
2. 选择手动安装
3. 根据设备架构选择 `x86` 或 `arm` 包
4. 安装完成后，管理员桌面会出现 AriaPilot 图标。1.0.7 修正了入口引用与实际图标文件名不一致的问题，并补齐管理员入口配置；升级后可刷新桌面，必要时退出飞牛账号后重新登录。
5. 首次打开时，默认下载目录是应用共享目录 `ariapilot/downloads`

如需下载到个人目录：

1. 进入飞牛「应用设置 → AriaPilot → 授权目录」
2. 添加目标目录并授予读写权限
3. 回到 AriaPilot 设置页，点击浏览选择该目录，保存

保存设置时应用会做写探测，目录不可写会直接提示。

## 数据与日志

安装后的目录结构遵循 fnOS 约定：

```text
/var/apps/ariapilot/
├── target/                 应用可执行文件
├── etc/aria2.conf          aria2 配置
├── var/settings.json       应用设置
├── var/history.json        已完成任务历史
├── var/aria2/              会话文件与 pid
├── var/logs/app.log        Node 服务日志
└── var/logs/aria2.log      aria2 日志
```

卸载时默认保留 `var` 下的任务记录与会话，已下载的文件在任何情况下都不会被删除。卸载向导选择「删除任务记录与下载会话」后，应用会清理设置、历史和会话。

## 配置说明

### 下载目录

内置引擎模式下，下载目录必须是已授权目录或其子目录。应用共享目录 `ariapilot/downloads` 默认可用，其他目录需要在应用设置中授权。

默认下载目录就是共享目录本身，例如 `/vol1/@appshare/ariapilot/downloads`。1.0.1 及更早版本可能在这里多拼一层 `downloads`，1.0.2 已修复：旧目录为空时启动后会自动迁回共享目录，旧目录里已有文件时会保留原路径并在应用内提示。

如果外接存储只能授权为只读，请参考「排障」中的「外接存储授权只能只读」。

### 端口说明

AriaPilot 涉及两个端口，它们属于不同服务：

1. `7788`：AriaPilot 的 Web 服务端口。飞牛桌面 iframe 和浏览器访问 `http://NAS:7788/` 时使用这个端口，对应 manifest 的 `service_port` 和桌面入口的 `port`。
2. `6800`：aria2 的 JSON-RPC 端口。Node 服务启动内置 aria2 时通过 `127.0.0.1:6800/jsonrpc` 调用它，只在本机回环地址监听，浏览器不会直接访问。

请求链路：

```text
飞牛桌面 iframe / 浏览器
        │ HTTP 7788
        ▼
Node 服务（0.0.0.0:7788）
        │ aria2 JSON-RPC 127.0.0.1:6800
        ▼
内置 aria2c
```

6800 被占用时，内置引擎会自动尝试 6801 到 6810。1.0.4 起，内置模式不会连接占用端口的其他 aria2 服务，避免 Docker 容器与宿主机的目录、权限不一致。已有服务需通过外部模式显式配置。7788 固定写在 manifest 和桌面入口中，修改后需要重新打包。

### 下载性能

1. 并发任务数：1 到 50
2. 每任务连接数：1 到 64
3. 分片数：1 到 64
4. 全局限速：`0` 表示不限速，也可以填写 `500K`、`2M`

### 引擎模式

内置引擎是默认模式，应用会管理 aria2 的启动、停止和配置。

连接已有 aria2 模式需要填写 RPC 地址与密钥。该模式下不支持删除远端文件，也不支持浏览本机目录。RPC 密钥留空表示保持原值。

## 排障

### 引擎未运行

打开设置页查看引擎状态，或者执行：

```bash
tail -n 100 /var/apps/ariapilot/var/logs/aria2.log
tail -n 100 /var/apps/ariapilot/var/logs/aria2.out.log
tail -n 100 /var/apps/ariapilot/var/logs/aria2.err.log
tail -n 100 /var/apps/ariapilot/var/logs/app.log
```

如果提示端口被占用，应用会自动尝试 6800 到 6810。仍失败时，检查是否有其他 aria2 实例占用了这些端口。

1.0.5 起，启动失败时保留进程退出码、信号和标准输出、标准错误摘要；RPC 就绪检查超时会显示最后一次请求错误。此改动用于定位实际启动原因，不代表设备上的启动问题已经修复。

1.0.6 起，内置 aria2 的 `HOME` 固定为应用的 `var/aria2` 目录。设备上的对照测试表明，原启动环境触发 `SIGSEGV`，仅替换 `HOME` 为应用数据目录后即可正常启动和退出。已有设置、会话和下载文件保持原位置；DHT 等使用默认主目录的辅助文件会使用新的 `HOME`。

### 引擎显示连接失败或状态卡住

1.0.1 起，内置引擎的启动、停止、重启和设置应用会串行执行，避免首次启动尚未完成时手动重启导致状态被旧流程覆盖。启动阶段界面显示「启动中」，不会再把瞬时的连接失败当成引擎故障。首次启动如果遇到端口占用、进程退出或未响应，会在 3 秒后自动重试一次。

如果仍然出现：

1. 等引擎状态变为「运行中」后再保存设置。
2. 状态卡在「引擎异常」时，点击「重启引擎」。
3. 确认安装包架构与设备一致：

```bash
uname -m
/var/apps/ariapilot/target/bin/aria2/aria2c --version
```

x86_64 设备用 x86 包，aarch64 设备用 arm 包。直接执行二进制报格式错误时，通常是装错了架构。

4. 检查端口占用：

```bash
ss -lntp | grep -E '680[0-9]'
```

5. 检查应用用户对配置和数据目录的写权限：

```bash
ls -ld /var/apps/ariapilot/etc /var/apps/ariapilot/var
sudo -u ariapilot test -w /var/apps/ariapilot/var && echo writable
```

### 桌面打开空白

确认 `http://<NAS地址>:7788/` 可以访问。如果目标 fnOS 版本的 iframe 网关表现异常，可以把 `fnos/package/app/ui/config` 中的 `type` 从 `iframe` 改为 `url`，重新打包安装。

### 下载失败提示 Permission denied

任务详情里出现 `Cannot open /.../index.html: Permission denied`，说明 aria2 已经拿到下载地址，失败发生在本地写入阶段，与网络无关。常见原因是下载目录或同名残留文件不属于应用用户。

按顺序处理：

1. 在应用内删除这个失败任务，勾选「同时删除已下载文件」。1.0.3 起会同时清理 `xxx.aria2` 控制文件。
2. 重新添加任务。如果仍然失败，通过 SSH 检查：

```bash
ls -ld /vol1/@appshare/ariapilot/downloads
ls -l /vol1/@appshare/ariapilot/downloads/index.html*
id ariapilot
sudo -u ariapilot touch /vol1/@appshare/ariapilot/downloads/.write-test
```

3. `touch` 失败说明目录对应用用户不可写。建议改到内置存储空间中自己拥有的目录，并在飞牛「应用设置 → 授权目录」中授权。
4. 如果同名文件属于 root 且确实不再需要，可以删除后重试：

```bash
sudo rm -f /vol1/@appshare/ariapilot/downloads/index.html \
  /vol1/@appshare/ariapilot/downloads/index.html.aria2
```

5. 任务名显示 `index.html`，是因为下载地址以 `/download/` 结尾且服务端没有提供文件名。下载完成后可以手动改名。

不要直接对整个共享目录执行 `chmod 777`，优先使用飞牛授权目录并修正所有者。

### 下载目录不可写

在飞牛「应用设置 → 授权目录」中确认目录权限为读写。AriaPilot 运行时使用应用专用用户，目录权限需要授予该用户。

### 外接存储授权只能只读

这是飞牛授权与挂载机制的表现，AriaPilot 无法在应用层把只读改成读写。常见原因有两类：

1. 外接盘文件系统是 exFAT、FAT32 或 NTFS。飞牛默认挂载这类分区时不做 Linux 用户与 ACL 权限映射，应用中心授权时只能选择只读。飞牛论坛已有 exFAT 外置盘授权只读的反馈。
2. 外接盘本身被挂载为只读。常见于非正常拔插、断电后的文件系统错误、NTFS 脏位、USB 连接或供电异常。存储管理里会显示为只读。

先确认属于哪一类：

```bash
df -T /你的/外接目录
findmnt -T /你的/外接目录
mount | grep 你的挂载点
touch /你的/外接目录/.ariapilot-write-test
sudo -u ariapilot touch /你的/外接目录/.ariapilot-write-test
```

判断方式：

1. `findmnt` 或 `mount` 输出里有 `ro`，说明是挂载层只读。
2. `df -T` 显示 `exfat`、`vfat`、`ntfs` 或 `ntfs3`，且 root 能写、`ariapilot` 用户不能写，说明缺少用户权限映射。
3. `setfacl` 报 `Operation not supported`，说明文件系统不支持 ACL。

处理方式：

1. 最稳妥的做法是把下载目录放到内置存储空间或应用共享目录 `ariapilot/downloads`。
2. 必须使用外接盘时，备份数据后把分区格式化为 ext4 或 Btrfs，再重新挂载并授权读写。
3. 不想格式化时，可以安装社区应用「外置存储挂载」，用它的权限兼容模式把 NTFS、exFAT、FAT 分区挂载到用户目录，再在飞牛应用设置中授权该目录。该方式依赖第三方应用，升级前请先验证。
4. 如果是文件系统错误导致的只读，先在存储管理中安全卸载，执行 `fsck` 修复，再重新挂载为读写。操作前务必备份数据。

AriaPilot 保存设置时会做写探测，目录不可写会直接提示，不会带着只读目录启动下载。

### 端口冲突

7788 是页面端口。如果安装时提示 7788 被占用，修改 `fnos/package/manifest` 的 `service_port` 与 `fnos/package/app/ui/config` 的 `port`，然后重新打包。

6800 是 aria2 RPC 端口。被占用时内置引擎会自动尝试 6801 到 6810，不需要手工修改。

## 本地开发与测试

单元测试：

```bash
node --test fnos/src/server/paths.test.js fnos/src/server/settings.test.js
```

端到端冒烟测试：

```bash
node fnos/test/smoke.mjs
```

冒烟测试会自动启动本地下载源和 AriaPilot 服务，验证添加任务、SSE 推送、暂停继续、修改目录、越权拒绝、删除文件与重启后历史保留。macOS 上会使用 `vendor/aria2/darwin-arm64/aria2c`。

手动启动开发服务：

```bash
AP_DEST="$PWD/fnos/src" \
AP_VAR=/tmp/ariapilot-dev \
AP_PORT=7788 \
AP_AUTH_PATHS=/tmp/ariapilot-dev/downloads \
AP_ARIA2_BIN="$PWD/vendor/aria2/darwin-arm64/aria2c" \
DYLD_LIBRARY_PATH="$PWD/vendor/aria2/darwin-arm64/lib" \
node fnos/src/server/index.js
```

然后访问 `http://127.0.0.1:7788/`。

在 Linux 上调试时把 `AP_ARIA2_BIN` 指向 `vendor/aria2/linux-amd64/aria2c` 或 `vendor/aria2/linux-arm64/aria2c`，不需要 `DYLD_LIBRARY_PATH`。

## 已知限制

1. 应用没有按飞牛用户隔离任务，所有有权限的用户看到同一份任务列表
2. 外部 aria2 模式下不能删除远端文件
3. 内置 aria2 使用静态构建 1.36.0，替换 `vendor` 中的二进制后重新打包即可升级
4. 不支持接管飞牛自带下载中心的任务
