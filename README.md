# Martin's PAL MCP Server Fork

> A enhanced fork of [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server) (formerly Zen MCP Server) by Beehive Innovations

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-9.8.2-green.svg)](https://github.com/Martinfeng/zen-mcp-server)
[![Upstream](https://img.shields.io/badge/upstream-v9.8.2-blue.svg)](https://github.com/BeehiveInnovations/pal-mcp-server)

English | [简体中文](README_ZH.md)

## 📌 About This Fork

This is a **technical fork** of the excellent [PAL MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server) (formerly Zen MCP Server) project, with the following key enhancements:

### 🎯 Main Purposes

1. **Package Name Isolation** - Renamed to `martin-mcp-server` to avoid conflicts when installing alongside the original package
2. **Custom Base URL Support** - Added flexible endpoint configuration for enterprise/proxy environments
3. **Model Validation Bypass** - Use any model name with custom endpoints (Ollama, vLLM, self-hosted)

### ✨ Key Enhancements

#### 1. Custom Base URL Support 🌐

Configure custom API endpoints via environment variables without code changes:

```bash
# Use API proxy or enterprise gateway
OPENAI_BASE_URL=https://your-proxy.com/v1

# Use local Ollama
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy

# Other providers
XAI_BASE_URL=https://your-xai-gateway.com/v1
DIAL_BASE_URL=https://your-dial-endpoint.com
GEMINI_BASE_URL=https://your-gemini-endpoint.com
```

**Use Cases:**
- 🏢 Enterprise API gateways
- 🌍 Regional endpoints
- 🔒 API proxies and rate limiters
- 🏠 Local model servers (Ollama, vLLM)
- 🧪 Development/testing environments
- 🔧 Custom Gemini-compatible endpoints

#### 2. Unrestricted Model Names 🔓

When using custom base URLs, **any model name is allowed** - no need to register in `conf/openai_models.json` or `conf/gemini_models.json`:

```bash
# Example: Use Ollama with any local model
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy
DEFAULT_MODEL=llama3.2  # ✅ Works! No registry needed

# Or use custom Gemini endpoint
GEMINI_BASE_URL=http://localhost:8088/v1
GEMINI_API_KEY=dummy
DEFAULT_MODEL=gemini-3.0-pro  # ✅ Any Gemini model!

# Or qwen, mistral, deepseek, etc.
DEFAULT_MODEL=qwen2.5-coder
```

**Benefits:**
- ✅ Use local models instantly
- ✅ Test custom models without configuration files
- ✅ Support bleeding-edge models before they're in the registry
- ✅ Work with self-hosted OpenAI/Gemini-compatible endpoints

#### 3. Non-Invasive Implementation 🎨

All enhancements are implemented via `martin_patches.py` using monkey patching:
- ✅ Minimal changes to original codebase (only 3 lines in `server.py`)
- ✅ Easy to sync with upstream updates
- ✅ Can be disabled by removing the import
- ✅ All original functionality preserved

---

## 📖 What is Zen MCP Server?

**Zen MCP** is a Model Context Protocol (MCP) server that connects AI tools like Claude Code, Codex CLI, and Cursor to **multiple AI models** for enhanced development workflows.

### Core Features (from Upstream)

- 🤖 **Multi-Model Orchestration** - Coordinate Gemini, OpenAI, Anthropic, local models in one workflow
- 🔄 **Conversation Threading** - Context flows seamlessly across tools and models
- 🛠️ **Specialized Workflows** - Code review, debugging, planning, security audit, test generation
- 🧠 **Extended Thinking** - Deep analysis with Gemini Pro's extended thinking capability
- 📊 **CLI-to-CLI Bridge** - Launch Codex/Gemini/Claude subagents from within your CLI
- 🎯 **Smart Model Selection** - Automatic or manual model picking per task
- 🖼️ **Vision Support** - Analyze screenshots and diagrams
- 🏠 **Local Model Support** - Llama, Mistral, etc. for privacy and zero cost

👉 **[View upstream documentation](https://github.com/BeehiveInnovations/pal-mcp-server)** for full feature details, examples, and videos.

---

## 🚀 Quick Start

### Installation

```bash
# Clone this fork
git clone https://github.com/Martinfeng/zen-mcp-server.git
cd zen-mcp-server

# Run setup (creates virtual environment, installs dependencies, configures MCP)
./run-server.sh

# Follow the prompts to configure API keys
```

### Basic Configuration

Edit `.env` file:

```bash
# Required: At least one AI provider
GEMINI_API_KEY=your_gemini_key
OPENAI_API_KEY=your_openai_key

# Optional: Custom endpoint (Martin's enhancement)
OPENAI_BASE_URL=http://localhost:11434/v1  # For Ollama

# Model selection
DEFAULT_MODEL=auto  # Let Claude pick the best model
# Or specify: gemini-2.5-pro, gpt-5, o3, llama3.2, etc.
```

### Usage with Claude Code

```bash
# Multi-model code review
codereview this PR using gemini-pro and o3

# Debug with extended thinking
debug this authentication issue with gemini-pro using extended thinking

# Plan implementation with multiple perspectives
use consensus with gpt-5 and gemini-pro to decide the architecture approach

# Local model (if using custom base URL)
chat with llama3.2 - analyze this code for security issues
```

### Usage with Ollama (Local Models)

```bash
# 1. Install and start Ollama
ollama serve

# 2. Pull a model
ollama pull llama3.2

# 3. Configure .env
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_API_KEY=dummy
DEFAULT_MODEL=llama3.2

# 4. Use it!
# Now all Zen MCP tools work with your local model - completely free!
```

---

## 🔄 Syncing with Upstream

This fork stays synchronized with the upstream Zen MCP Server:

```bash
# Automatic sync (recommended)
./sync-upstream.sh

# Manual sync
git fetch upstream
git merge upstream/main
```

The sync script automatically:
- ✅ Merges upstream updates
- ✅ Preserves package name (`martin-mcp-server`)
- ✅ Maintains custom patches (`martin_patches.py`)
- ✅ Detects and helps resolve conflicts

---

## 📚 Documentation

### Fork-Specific Docs
- [FORK_INFO.md](FORK_INFO.md) - Detailed fork information and sync procedures
- [NOTICE](NOTICE) - Apache 2.0 license notice and attribution

### Upstream Docs (Full Features)
- [Getting Started](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/getting-started.md)
- [Configuration Guide](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/configuration.md)
- [Tool Documentation](https://github.com/BeehiveInnovations/pal-mcp-server/tree/main/docs/tools)
- [Advanced Usage](https://github.com/BeehiveInnovations/pal-mcp-server/blob/main/docs/advanced-usage.md)

---

## 🛠️ Technical Details

### Changes from Upstream

| Component | Original | This Fork | Purpose |
|-----------|----------|-----------|---------|
| Package Name | `zen-mcp-server` | `martin-mcp-server` | Avoid installation conflicts |
| Virtual Env | `.zen_venv` | `.martin_venv` | Workspace isolation |
| Custom Patches | ❌ | ✅ `martin_patches.py` | Base URL & model flexibility |
| Model Validation | Strict registry check | Bypassed with custom URLs | Support any model name |

### Files Modified

```
server.py              # 3 lines: import martin_patches
pyproject.toml         # Package name change
run-server.sh          # Virtual env name change
martin_patches.py      # NEW: Custom functionality
NOTICE                 # NEW: Apache 2.0 attribution
FORK_INFO.md          # NEW: Fork documentation
```

All other files remain synced with upstream.

---

## 🤝 Credits

**Original Project:** [Zen MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server)
**Original Author:** Fahad Gilani @ [Beehive Innovations](https://github.com/BeehiveInnovations)
**License:** Apache License 2.0

This fork is a **derivative work** that adds minor enhancements while preserving all original functionality. All credit for the core project goes to the upstream authors.

---

## 📄 License

Apache License 2.0 - See [LICENSE](LICENSE)

This project includes modifications to the original Zen MCP Server. See [NOTICE](NOTICE) for full attribution.

---

## 🔗 Links

- **This Fork:** https://github.com/Martinfeng/zen-mcp-server
- **Upstream Project:** https://github.com/BeehiveInnovations/pal-mcp-server
- **Issue Tracker:** https://github.com/Martinfeng/zen-mcp-server/issues
- **Upstream Issues:** https://github.com/BeehiveInnovations/pal-mcp-server/issues

---

## ⚠️ Disclaimer

This is a **technical fork for personal use**, not a competing or replacement project. For the official, fully-supported version, please use the [upstream Zen MCP Server](https://github.com/BeehiveInnovations/pal-mcp-server).
