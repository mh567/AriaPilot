# fnOS 应用源码

这个目录包含 AriaPilot 的飞牛 fnOS 版本：

- `src/server`：Node.js 服务端，管理 aria2 进程、RPC 代理、设置与历史
- `src/public`：Web 前端，可嵌入 fnOS 桌面 iframe
- `package`：FPK 元数据、生命周期脚本、权限资源与桌面入口
- `test/smoke.mjs`：端到端冒烟测试

构建与安装说明见 [docs/FNOS.md](../docs/FNOS.md)。

快速构建：

```bash
bash scripts/build_fpk.sh --arch all
```

产物位于 `dist/`。
