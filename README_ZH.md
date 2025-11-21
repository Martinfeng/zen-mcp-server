# Martin's Zen MCP Server Fork

> [Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server) 的增强版 Fork - 由 Beehive Innovations 原创

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.2.0-green.svg)](https://github.com/Martinfeng/zen-mcp-server)
[![Upstream](https://img.shields.io/badge/upstream-v9.4.0-blue.svg)](https://github.com/BeehiveInnovations/zen-mcp-server)

[English](README.md) | 简体中文

## 📌 关于此 Fork

这是优秀的 [Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server) 项目的**技术性 Fork**，包含以下核心增强：

### 🎯 主要目的

1. **包名隔离** - 重命名为 `martin-mcp-server`，避免与原始包安装冲突
2. **自定义 Base URL 支持** - 为企业/代理环境提供灵活的端点配置
3. **模型验证绕过** - 使用自定义端点时支持任意模型名称（Ollama、vLLM、自托管）

### ✨ 核心增强功能

#### 1. 自定义 Base URL 支持 🌐

通过环境变量配置自定义 API 端点，无需修改代码：

```bash
# 使用 API 代理或企业网关
OPENAI_BASE_URL=https://your-proxy.com/v1

# 使用本地 Ollama
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy

# 其他提供商
XAI_BASE_URL=https://your-xai-gateway.com/v1
DIAL_BASE_URL=https://your-dial-endpoint.com
GEMINI_BASE_URL=https://your-gemini-endpoint.com
```

**使用场景：**
- 🏢 企业 API 网关
- 🌍 区域端点
- 🔒 API 代理和速率限制器
- 🏠 本地模型服务器（Ollama、vLLM）
- 🧪 开发/测试环境
- 🔧 自定义 Gemini 兼容端点

#### 2. 无限制模型名称 🔓

使用自定义 Base URL 时，**允许使用任意模型名称** - 无需在 `conf/openai_models.json` 或 `conf/gemini_models.json` 中注册：

```bash
# 示例：使用 Ollama 和任意本地模型
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy
DEFAULT_MODEL=llama3.2  # ✅ 直接可用！无需注册

# 或使用自定义 Gemini 端点
GEMINI_BASE_URL=http://localhost:8088/v1
GEMINI_API_KEY=dummy
DEFAULT_MODEL=gemini-3.0-pro  # ✅ 任意 Gemini 模型！

# 或者 qwen、mistral、deepseek 等
DEFAULT_MODEL=qwen2.5-coder
```

**优势：**
- ✅ 立即使用本地模型
- ✅ 测试自定义模型无需配置文件
- ✅ 支持最新模型，无需等待官方注册
- ✅ 兼容自托管的 OpenAI/Gemini 兼容端点

#### 3. 非侵入式实现 🎨

所有增强功能通过 `martin_patches.py` 使用猴子补丁（monkey patching）实现：
- ✅ 对原始代码库的修改最小（`server.py` 仅 3 行）
- ✅ 易于与上游更新同步
- ✅ 可通过移除导入来禁用
- ✅ 保留所有原始功能

---

## 📖 什么是 Zen MCP Server？

**Zen MCP** 是一个模型上下文协议（MCP）服务器，它连接 AI 工具（如 Claude Code、Codex CLI 和 Cursor）与**多个 AI 模型**，实现增强的开发工作流。

### 核心功能（来自上游）

- 🤖 **多模型编排** - 在单个工作流中协调 Gemini、OpenAI、Anthropic、本地模型
- 🔄 **对话线程** - 上下文在工具和模型之间无缝流转
- 🛠️ **专业工作流** - 代码审查、调试、规划、安全审计、测试生成
- 🧠 **扩展思考** - 使用 Gemini Pro 的扩展思考能力进行深度分析
- 📊 **CLI 到 CLI 桥接** - 在 CLI 中启动 Codex/Gemini/Claude 子代理
- 🎯 **智能模型选择** - 每个任务自动或手动选择模型
- 🖼️ **视觉支持** - 分析屏幕截图和图表
- 🏠 **本地模型支持** - Llama、Mistral 等，保护隐私且零成本

👉 **[查看上游文档](https://github.com/BeehiveInnovations/zen-mcp-server)** 了解完整功能详情、示例和视频。

---

## 🚀 快速开始

### 安装

```bash
# 克隆此 fork
git clone https://github.com/Martinfeng/zen-mcp-server.git
cd zen-mcp-server

# 运行设置脚本（创建虚拟环境、安装依赖、配置 MCP）
./run-server.sh

# 按提示配置 API 密钥
```

### 基础配置

编辑 `.env` 文件：

```bash
# 必需：至少一个 AI 提供商
GEMINI_API_KEY=your_gemini_key
OPENAI_API_KEY=your_openai_key

# 可选：自定义端点（Martin 的增强功能）
OPENAI_BASE_URL=http://localhost:11434/v1  # 用于 Ollama

# 模型选择
DEFAULT_MODEL=auto  # 让 Claude 选择最佳模型
# 或指定：gemini-2.5-pro、gpt-5、o3、llama3.2 等
```

### 使用 Claude Code

```bash
# 多模型代码审查
使用 gemini-pro 和 o3 审查这个 PR

# 使用扩展思考调试
使用 gemini-pro 的扩展思考调试这个认证问题

# 使用多个视角规划实现
使用 gpt-5 和 gemini-pro 达成共识来决定架构方案

# 本地模型（如果使用自定义 base URL）
使用 llama3.2 聊天 - 分析这段代码的安全问题
```

### 使用 Ollama（本地模型）

```bash
# 1. 安装并启动 Ollama
ollama serve

# 2. 拉取模型
ollama pull llama3.2

# 3. 配置 .env
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy
DEFAULT_MODEL=llama3.2

# 4. 开始使用！
# 现在所有 Zen MCP 工具都可以使用你的本地模型 - 完全免费！
```

---

## 🔄 与上游同步

此 fork 保持与上游 Zen MCP Server 的同步：

```bash
# 自动同步（推荐）
./sync-upstream.sh

# 手动同步
git fetch upstream
git merge upstream/main
```

同步脚本会自动：
- ✅ 合并上游更新
- ✅ 保留包名（`martin-mcp-server`）
- ✅ 维护自定义补丁（`martin_patches.py`）
- ✅ 检测并帮助解决冲突

---

## 📚 文档

### Fork 专属文档
- [FORK_INFO.md](FORK_INFO.md) - 详细的 fork 信息和同步流程
- [NOTICE](NOTICE) - Apache 2.0 许可证声明和归属

### 上游文档（完整功能）
- [入门指南](https://github.com/BeehiveInnovations/zen-mcp-server/blob/main/docs/getting-started.md)
- [配置指南](https://github.com/BeehiveInnovations/zen-mcp-server/blob/main/docs/configuration.md)
- [工具文档](https://github.com/BeehiveInnovations/zen-mcp-server/tree/main/docs/tools)
- [高级用法](https://github.com/BeehiveInnovations/zen-mcp-server/blob/main/docs/advanced-usage.md)

---

## 🛠️ 技术细节

### 与上游的差异

| 组件 | 原版 | 此 Fork | 目的 |
|------|------|---------|------|
| 包名 | `zen-mcp-server` | `martin-mcp-server` | 避免安装冲突 |
| 虚拟环境 | `.zen_venv` | `.martin_venv` | 工作区隔离 |
| 自定义补丁 | ❌ | ✅ `martin_patches.py` | Base URL 和模型灵活性 |
| 模型验证 | 严格注册表检查 | 自定义 URL 时绕过 | 支持任意模型名称 |

### 修改的文件

```
server.py              # 3 行：导入 martin_patches
pyproject.toml         # 包名变更
run-server.sh          # 虚拟环境名变更
martin_patches.py      # 新增：自定义功能
NOTICE                 # 新增：Apache 2.0 归属
FORK_INFO.md          # 新增：Fork 文档
README_ZH.md          # 新增：中文文档
```

所有其他文件与上游保持同步。

---

## 🤝 致谢

**原始项目：** [Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server)
**原作者：** Fahad Gilani @ [Beehive Innovations](https://github.com/BeehiveInnovations)
**许可证：** Apache License 2.0

此 fork 是一个**衍生作品**，在保留所有原始功能的基础上添加了少量增强。所有荣誉归原作者所有。

---

## 📄 许可证

Apache License 2.0 - 详见 [LICENSE](LICENSE)

本项目包含对原始 Zen MCP Server 的修改。完整归属信息见 [NOTICE](NOTICE)。

---

## 🔗 相关链接

- **此 Fork：** https://github.com/Martinfeng/zen-mcp-server
- **上游项目：** https://github.com/BeehiveInnovations/zen-mcp-server
- **问题跟踪：** https://github.com/Martinfeng/zen-mcp-server/issues
- **上游问题：** https://github.com/BeehiveInnovations/zen-mcp-server/issues

---

## ⚠️ 免责声明

这是一个**用于个人使用的技术性 fork**，不是竞争或替代项目。如需官方、全面支持的版本，请使用[上游 Zen MCP Server](https://github.com/BeehiveInnovations/zen-mcp-server)。
