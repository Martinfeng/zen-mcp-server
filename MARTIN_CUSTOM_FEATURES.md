# Martin's Custom Features

本文档说明此 fork 中添加的自定义功能，这些功能通过插件方式实现，最小化与上游代码的冲突。

## 功能列表

### 1. 自定义 Base URL 支持

**问题背景：**
原项目中，OpenAI、XAI、DIAL 等提供商的 base URL 是硬编码的，无法通过环境变量配置。这导致无法使用：
- API 代理服务（如国内加速代理）
- 企业内部网关
- 区域性端点
- 测试环境

**解决方案：**
通过 `martin_patches.py` 实现运行时 Monkey Patch，添加对自定义 base URL 的支持。

**支持的环境变量：**

| 环境变量 | 提供商 | 默认值 | 说明 |
|---------|--------|--------|------|
| `GEMINI_BASE_URL` | Google Gemini | (Google API) | 原生支持，无需 patch |
| `OPENAI_BASE_URL` | OpenAI | `https://api.openai.com/v1` | **新增支持** |
| `XAI_BASE_URL` | X.AI | `https://api.x.ai/v1` | **新增支持** |
| `DIAL_BASE_URL` | DIAL | `https://core.dialx.ai` | **新增支持** |
| `CUSTOM_API_URL` | Custom/Ollama | (必需) | 原生支持，无需 patch |

**配置示例：**

```bash
# .env 文件

# 使用 OpenAI 代理（例如国内加速）
OPENAI_API_KEY=sk-your-key
OPENAI_BASE_URL=https://api.openai-proxy.com/v1

# 使用企业内部 XAI 网关
XAI_API_KEY=your-xai-key
XAI_BASE_URL=https://internal-gateway.company.com/xai/v1

# 使用自定义 DIAL 端点
DIAL_API_KEY=your-dial-key
DIAL_BASE_URL=https://dial.yourdomain.com
```

**实现原理：**

1. **martin_patches.py** - 插件文件
   - 使用 Monkey Patch 拦截 `ModelProviderRegistry.get_provider` 方法
   - 在初始化提供商时注入自定义 base_url 参数
   - 保留原有逻辑，仅扩展功能

2. **server.py** - 最小修改（仅 3 行）
   ```python
   # Apply Martin's custom patches (must be first, before any provider imports)
   try:
       import martin_patches  # noqa: F401
   except ImportError:
       pass  # Patches not available, continue with default behavior
   ```

3. **.env.example** - 配置说明
   - 添加新环境变量的文档
   - 说明使用场景和示例

**优点：**
- ✅ **最小侵入** - 只修改了 server.py 的 3 行代码
- ✅ **易于维护** - patch 逻辑独立在 martin_patches.py 中
- ✅ **易于禁用** - 删除或重命名 martin_patches.py 即可禁用
- ✅ **兼容上游** - 合并上游更新时几乎不会产生冲突
- ✅ **向后兼容** - 如果不设置环境变量，行为与原版完全一致

**技术细节：**

```python
# martin_patches.py 核心逻辑

# 定义支持自定义 base URL 的提供商
CUSTOM_BASE_URL_PROVIDERS = {
    ProviderType.OPENAI: "OPENAI_BASE_URL",
    ProviderType.XAI: "XAI_BASE_URL",
    ProviderType.DIAL: "DIAL_BASE_URL",
}

# 拦截 get_provider 方法
@classmethod
def patched_get_provider(cls, provider_type, force_new=False):
    if provider_type in CUSTOM_BASE_URL_PROVIDERS:
        # 读取自定义 base_url
        env_var = CUSTOM_BASE_URL_PROVIDERS[provider_type]
        custom_base_url = get_env(env_var)

        # 如果设置了自定义 URL，传递给提供商
        if custom_base_url:
            provider = provider_class(api_key=api_key, base_url=custom_base_url)
        else:
            provider = provider_class(api_key=api_key)
    else:
        # 其他提供商使用原始逻辑
        return original_get_provider(cls, provider_type, force_new)
```

## 使用指南

### 启用功能

**方法 1：自动启用（默认）**
- patch 文件已经存在，server.py 已包含导入语句
- 只需配置 .env 文件中的环境变量即可

**方法 2：手动启用**
1. 确保 `martin_patches.py` 文件存在于项目根目录
2. 确保 `server.py` 中包含导入语句：
   ```python
   import martin_patches
   ```
3. 配置 .env 文件

### 禁用功能

**方法 1：临时禁用**
```bash
# 重命名 patch 文件
mv martin_patches.py martin_patches.py.disabled
```

**方法 2：永久移除**
```bash
# 删除 patch 文件
rm martin_patches.py

# 从 server.py 中移除导入（可选，不移除也不会报错）
```

### 验证配置

**检查 patch 是否生效：**
```bash
# 启动服务器并查看日志
./run-server.sh -f

# 应该看到类似的日志：
# 🔧 Applying Martin's custom patches...
# ✅ Martin's custom patches applied successfully
# ✓ Patched ModelProviderRegistry.get_provider to support custom base URLs
```

**检查自定义 URL 是否使用：**
```bash
# 当提供商初始化时，应该看到：
# 🌐 Using custom OpenAI endpoint: https://your-proxy.com/v1
# 🌐 Using custom XAI endpoint: https://your-xai-gateway.com
```

## 故障排查

### 问题 1：Patch 未生效

**症状：** 日志中没有看到 "Applying Martin's custom patches"

**原因：**
- martin_patches.py 文件不存在或路径错误
- server.py 中没有导入 martin_patches

**解决：**
```bash
# 检查文件是否存在
ls -la martin_patches.py

# 检查 server.py 是否导入
grep "import martin_patches" server.py
```

### 问题 2：自定义 URL 未使用

**症状：** 仍然使用默认 URL

**原因：**
- 环境变量未设置或拼写错误
- .env 文件未加载

**解决：**
```bash
# 检查环境变量
grep OPENAI_BASE_URL .env

# 确保 .env 文件在项目根目录
ls -la .env

# 检查日志确认 URL
tail -f logs/mcp_server.log | grep "Using custom"
```

### 问题 3：与上游合并冲突

**症状：** git merge 时 server.py 产生冲突

**原因：** server.py 的导入部分被上游修改

**解决：**
```bash
# 接受上游的修改
git checkout --theirs server.py

# 手动重新添加导入语句（在文件开头，import 之前）
# Apply Martin's custom patches (must be first, before any provider imports)
try:
    import martin_patches  # noqa: F401
except ImportError:
    pass  # Patches not available, continue with default behavior
```

## 测试

### 单元测试

```bash
# 测试 patch 是否正常加载
python -c "import martin_patches; print('Patches loaded successfully')"

# 测试环境变量是否生效
OPENAI_BASE_URL=https://test.com python -c "
from utils.env import get_env
print('OPENAI_BASE_URL:', get_env('OPENAI_BASE_URL'))
"
```

### 集成测试

```bash
# 使用 Ollama 本地模型测试（无需真实 API key）
export OPENAI_API_KEY=sk-test-key
export OPENAI_BASE_URL=http://localhost:11434/v1

# 启动服务器
./run-server.sh
```

## 贡献与反馈

如果你发现 bug 或有改进建议：

1. **Fork 项目**
2. **创建 Issue** 描述问题
3. **提交 Pull Request**（如果你有解决方案）

---

**最后更新：** 2025-10-21
**维护者：** Martin (Feng)
