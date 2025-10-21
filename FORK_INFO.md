# Fork 信息

## 目的

这是 [Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server) 的技术性 fork，**唯一目的是避免包名冲突**，以便可以与原始包并行安装使用。

## 核心修改

### 包名修改（避免冲突）

1. **Python 包名**
   - `zen-mcp-server` → `martin-mcp-server`
   - 修改位置：`pyproject.toml`

2. **虚拟环境名称**
   - `.zen_venv` → `.martin_venv`
   - 修改位置：`run-server.sh`, `run-server.ps1`, `pyproject.toml`

3. **NOTICE 文件**
   - 新建，声明这是派生作品
   - 符合 Apache-2.0 许可证要求

### 功能增强（插件方式）

4. **自定义 Base URL 支持** 🆕
   - **文件**：`martin_patches.py`（新增）
   - **功能**：支持通过环境变量配置 OpenAI、XAI、DIAL 的自定义端点
   - **用途**：API 代理、企业网关、区域端点、测试环境
   - **实现**：Monkey Patch 方式，最小侵入（server.py 仅 3 行修改）
   - **详细说明**：见 [MARTIN_CUSTOM_FEATURES.md](MARTIN_CUSTOM_FEATURES.md)

支持的环境变量：
```bash
OPENAI_BASE_URL=https://your-proxy.com/v1
XAI_BASE_URL=https://your-xai-gateway.com/v1
DIAL_BASE_URL=https://your-dial-endpoint.com
```

## 未修改的内容

- ✅ 作者信息（保留 Fahad Gilani）
- ✅ 项目名称和文档（保持 "Zen MCP Server"）
- ✅ 所有功能代码
- ✅ README 和其他文档
- ✅ 版本检查（仍指向上游仓库）

## 同步上游

### 自动同步（推荐）

使用提供的同步脚本自动处理：

```bash
# 运行自动同步脚本
./sync-upstream.sh
```

脚本会自动：
- ✅ 检测上游更新
- ✅ 自动合并无冲突的更改
- ✅ 验证自定义修改是否保留
- ✅ 自动修复 server.py 的 import（如果被覆盖）
- ⚠️ 检测并提示需要手动处理的冲突

### 手动同步

如果需要手动同步：

```bash
# 1. 获取上游更新
git fetch upstream

# 2. 查看上游变化
git log HEAD..upstream/main --oneline

# 3. 合并上游更新
git merge upstream/main

# 4. 如有冲突，解决方法见下文
```

### 冲突解决策略

#### 1. server.py - 导入语句冲突

**现象**：合并后 martin_patches 导入丢失

**解决**：在模块 docstring 之后、其他 import 之前重新添加：

```python
"""
Zen MCP Server - Main server implementation
...
"""

# Apply Martin's custom patches (must be first, before any provider imports)
try:
    import martin_patches  # noqa: F401
except ImportError:
    pass  # Patches not available, continue with default behavior

import asyncio
```

#### 2. pyproject.toml - 包名冲突

**现象**：包名被重置为 zen-mcp-server

**解决**：
```bash
# 接受上游的版本和依赖
git checkout --theirs pyproject.toml

# 手动修改包名
sed -i '' 's/name = "zen-mcp-server"/name = "martin-mcp-server"/' pyproject.toml
sed -i '' 's/zen-mcp-server = /martin-mcp-server = /' pyproject.toml

# 确保 .martin_venv 在排除列表中
# 手动编辑 pyproject.toml，在 exclude 中添加 ".martin_venv"
```

#### 3. .env.example - 环境变量说明冲突

**现象**：Martin's Custom Patches 部分丢失

**解决**：
```bash
# 接受上游修改
git checkout --theirs .env.example

# 重新添加自定义部分（在 GEMINI_BASE_URL 之后）
cat >> .env.example << 'EOF'

# ============================================================================
# Martin's Custom Patches - Additional Base URL Support
# ============================================================================
# These environment variables are enabled by martin_patches.py
# Useful for: API proxies, enterprise gateways, regional endpoints, testing
# Note: Requires martin_patches.py to be imported in server.py

# OPENAI_BASE_URL=https://api.openai.com/v1  # Optional: Custom OpenAI endpoint
# XAI_BASE_URL=https://api.x.ai/v1            # Optional: Custom XAI endpoint
# DIAL_BASE_URL=https://core.dialx.ai         # Optional: Custom DIAL endpoint
EOF
```

#### 4. run-server.sh / run-server.ps1 - 虚拟环境名冲突

**现象**：脚本中虚拟环境名重置为 .zen_venv

**解决**：
```bash
# macOS/Linux
sed -i '' 's/.zen_venv/.martin_venv/g' run-server.sh

# Windows PowerShell
(Get-Content run-server.ps1) -replace '.zen_venv', '.martin_venv' | Set-Content run-server.ps1
```

### 受保护的文件

以下文件通过 `.gitattributes` 配置，合并时自动保留我们的版本：

- ✅ **NOTICE** - 永远保留（Apache-2.0 声明）
- ✅ **FORK_INFO.md** - 永远保留（fork 文档）
- ✅ **MARTIN_CUSTOM_FEATURES.md** - 永远保留（自定义功能文档）
- ✅ **martin_patches.py** - 永远保留（自定义 patch）

### 验证同步结果

合并完成后，验证关键修改：

```bash
# 1. 检查包名
grep "name = " pyproject.toml
# 应该显示: name = "martin-mcp-server"

# 2. 检查 server.py 导入
grep -A 3 "import martin_patches" server.py
# 应该找到导入语句

# 3. 检查自定义文件
ls -la martin_patches.py NOTICE FORK_INFO.md MARTIN_CUSTOM_FEATURES.md
# 所有文件都应该存在

# 4. 运行质量检查
./code_quality_checks.sh
```

## 安装

```bash
# 克隆此 fork
git clone <your-fork-url>
cd martin-mcp-server

# 运行设置脚本（会创建 .martin_venv 虚拟环境）
./run-server.sh
```

## 原项目信息

- **原项目**：[Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server)
- **原作者**：Fahad Gilani @ Beehive Innovations
- **许可证**：Apache License 2.0

---

**注意**：这不是一个独立项目，只是为了避免包名冲突的技术性调整。所有功劳归原作者。
