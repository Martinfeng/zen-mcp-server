"""
Martin's Custom Patches for Zen MCP Server

This module applies runtime patches to enable custom base URL configuration
for OpenAI and other providers without modifying the original source code.

Features:
1. Custom Base URL Support - Use alternative API endpoints
2. Model Validation Bypass - Use any model name when custom base URL is set

Usage:
    Import this module at the very beginning of server.py:
        import martin_patches  # Apply custom patches

    Configure via environment variables:
        OPENAI_BASE_URL=https://your-proxy.com/v1
        XAI_BASE_URL=https://your-xai-proxy.com/v1
        DIAL_BASE_URL=https://your-dial-endpoint.com

    When a custom base URL is set, you can use ANY model name:
        - Local models: llama3.2, qwen2.5, mistral, etc.
        - Custom endpoints: your-custom-model-name
        - vLLM/Ollama: any model available on your endpoint

    Example with Ollama:
        OPENAI_BASE_URL=http://localhost:11434/v1
        OPENAI_API_KEY=dummy
        # Now can use: llama3.2, mistral, qwen2.5, etc.

Author: Martin (Feng)
Date: 2025-10-21
Updated: 2025-10-23 - Added model validation bypass
"""

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Track if patches have been applied
_PATCHES_APPLIED = False


def apply_patches():
    """Apply all custom patches to the MCP server."""
    global _PATCHES_APPLIED

    if _PATCHES_APPLIED:
        logger.debug("Martin patches already applied, skipping")
        return

    logger.info("🔧 Applying Martin's custom patches...")

    # Apply unified patch for all providers
    success1 = _patch_provider_base_urls()

    # Apply model validation bypass for custom endpoints
    success2 = _patch_model_validation_bypass()

    if success1 and success2:
        _PATCHES_APPLIED = True
        logger.info("✅ Martin's custom patches applied successfully")
    else:
        if not success1:
            logger.error("❌ Failed to apply custom base URL patch")
        if not success2:
            logger.error("❌ Failed to apply model validation bypass patch")
        logger.error("   Some custom features may NOT be available")


def _patch_provider_base_urls():
    """
    Unified patch to support custom base URLs for multiple providers.

    Supported environment variables:
    - OPENAI_BASE_URL: Custom OpenAI API endpoint
    - XAI_BASE_URL: Custom XAI API endpoint
    - DIAL_BASE_URL: Custom DIAL API endpoint (takes precedence over DIAL_API_HOST)

    Returns:
        bool: True if patch was successfully applied, False otherwise
    """
    # Lazy import to avoid circular dependencies and early initialization issues
    import importlib

    try:
        registry_module = importlib.import_module('providers.registry')
        shared_module = importlib.import_module('providers.shared')
        env_module = importlib.import_module('utils.env')

        ModelProviderRegistry = registry_module.ModelProviderRegistry
        ProviderType = shared_module.ProviderType
        get_env = env_module.get_env
    except Exception as e:
        logger.error(f"Failed to import required modules for patches: {e}")
        return False

    # Store original method
    original_get_provider = ModelProviderRegistry.get_provider.__func__

    @classmethod
    def patched_get_provider(cls, provider_type: ProviderType, force_new: bool = False):
        """
        Patched version of get_provider that adds custom base_url support
        for OpenAI, XAI, and DIAL providers.
        """

        # Define providers that support custom base URLs
        CUSTOM_BASE_URL_PROVIDERS = {
            ProviderType.OPENAI: "OPENAI_BASE_URL",
            ProviderType.XAI: "XAI_BASE_URL",
            ProviderType.DIAL: "DIAL_BASE_URL",
        }

        # Check if this provider supports custom base URL
        if provider_type in CUSTOM_BASE_URL_PROVIDERS:
            instance = cls()

            # Return cached instance if available and not forcing new
            if not force_new and provider_type in instance._initialized_providers:
                return instance._initialized_providers[provider_type]

            # Check if provider class is registered
            if provider_type not in instance._providers:
                return None

            # Get API key
            api_key = cls._get_api_key_for_provider(provider_type)
            if not api_key:
                return None

            # Get custom base URL from environment
            env_var = CUSTOM_BASE_URL_PROVIDERS[provider_type]
            custom_base_url = get_env(env_var)

            # For DIAL, also check legacy DIAL_API_HOST variable
            if provider_type == ProviderType.DIAL and not custom_base_url:
                custom_base_url = get_env("DIAL_API_HOST")

            # Get provider class
            provider_class = instance._providers[provider_type]

            # Initialize with custom base_url if provided
            if custom_base_url:
                # Use WARNING level to ensure visibility even without DEBUG
                logger.warning(f"🌐 CUSTOM BASE URL ACTIVE: {provider_type.value} -> {custom_base_url}")
                provider = provider_class(api_key=api_key, base_url=custom_base_url)
            else:
                provider = provider_class(api_key=api_key)

            # Cache the instance
            instance._initialized_providers[provider_type] = provider
            return provider

        # For all other providers (including Gemini which already has native support),
        # use the original method
        return original_get_provider(cls, provider_type, force_new)

    # Apply the patch
    ModelProviderRegistry.get_provider = patched_get_provider
    logger.debug("✓ Patched ModelProviderRegistry.get_provider to support custom base URLs")
    logger.debug("  Supported: OPENAI_BASE_URL, XAI_BASE_URL, DIAL_BASE_URL")
    return True


def _patch_model_validation_bypass():
    """
    Bypass model validation when using custom base URLs.

    When a custom base URL is configured (OPENAI_BASE_URL, XAI_BASE_URL, or DIAL_BASE_URL),
    allow any model name to be used without requiring it to be in the model registry.
    This enables using:
    - Local models (Ollama, vLLM)
    - Self-hosted OpenAI-compatible endpoints
    - Custom model names not in conf/openai_models.json

    For unknown models, reasonable default capabilities are provided based on
    typical OpenAI-compatible API behavior.

    Returns:
        bool: True if patch was successfully applied, False otherwise
    """
    import importlib

    try:
        env_module = importlib.import_module('utils.env')
        shared_module = importlib.import_module('providers.shared')

        get_env = env_module.get_env
        ModelCapabilities = shared_module.ModelCapabilities
        ProviderType = shared_module.ProviderType
    except Exception as e:
        logger.error(f"Failed to import required modules for model validation bypass: {e}")
        return False

    # Provider configurations: (provider_module, provider_class, env_var, provider_type)
    PROVIDERS_TO_PATCH = [
        ('providers.openai', 'OpenAIModelProvider', 'OPENAI_BASE_URL', ProviderType.OPENAI),
        ('providers.xai', 'XAIModelProvider', 'XAI_BASE_URL', ProviderType.XAI),
        ('providers.dial', 'DIALModelProvider', 'DIAL_BASE_URL', ProviderType.DIAL),
    ]

    patched_count = 0

    for module_name, class_name, env_var, provider_type in PROVIDERS_TO_PATCH:
        try:
            provider_module = importlib.import_module(module_name)
            provider_class = getattr(provider_module, class_name)

            # Store original method
            original_lookup = provider_class._lookup_capabilities

            def make_patched_lookup(original_method, env_var_name, prov_type):
                """Factory to create patched lookup with proper closure."""

                def patched_lookup(self, canonical_name: str, requested_name: Optional[str] = None):
                    """Patched _lookup_capabilities that allows any model when custom base_url is set."""

                    # First try the original lookup for known models
                    result = original_method(self, canonical_name, requested_name)
                    if result is not None:
                        return result

                    # If model not found and custom base URL is set, provide default capabilities
                    custom_base_url = get_env(env_var_name)

                    # For DIAL, also check legacy DIAL_API_HOST variable
                    if env_var_name == 'DIAL_BASE_URL' and not custom_base_url:
                        custom_base_url = get_env('DIAL_API_HOST')

                    if custom_base_url:
                        logger.info(
                            f"🔓 Model '{canonical_name}' not in registry, but {env_var_name} is set. "
                            f"Allowing with default capabilities."
                        )

                        # Provide reasonable default capabilities for unknown models
                        return ModelCapabilities(
                            model_name=canonical_name,
                            provider=prov_type,
                            friendly_name=f"{prov_type.value.title()} ({canonical_name})",
                            # Conservative defaults - most OpenAI-compatible APIs support these
                            context_window=128000,  # 128K is common for modern models
                            max_output_tokens=4096,  # Conservative default
                            supports_extended_thinking=False,  # Rare capability
                            supports_system_prompts=True,  # Almost all models support this
                            supports_streaming=True,  # Standard for OpenAI-compatible APIs
                            supports_function_calling=True,  # Common feature
                            supports_json_mode=True,  # Common feature
                            supports_images=False,  # Conservative - require explicit config
                            max_image_size_mb=0.0,
                            supports_temperature=True,  # Standard parameter
                            description=f"Custom model via {env_var_name}",
                            intelligence_score=10,  # Middle-of-the-road default
                        )

                    # If no custom base URL, return None to trigger the original error
                    return None

                return patched_lookup

            # Apply the patch
            provider_class._lookup_capabilities = make_patched_lookup(
                original_lookup, env_var, provider_type
            )
            patched_count += 1
            logger.debug(f"✓ Patched {class_name}._lookup_capabilities for unrestricted model access")

        except ImportError:
            # Provider module not available (e.g., XAI or DIAL might not be installed)
            logger.debug(f"⊘ Skipping {module_name} (not available)")
            continue
        except Exception as e:
            logger.warning(f"Failed to patch {module_name}.{class_name}: {e}")
            continue

    if patched_count > 0:
        logger.debug(f"✓ Model validation bypass applied to {patched_count} provider(s)")
        logger.debug("  When custom base URLs are set, any model name is now allowed")
        return True
    else:
        logger.warning("⚠ No providers were patched for model validation bypass")
        return False


# Auto-apply patches on import
# Note: Patches are applied immediately to ensure they're active before any provider initialization
# If import fails (e.g., missing dependencies), patches won't be applied but won't crash the server
if __name__ != "__main__":
    # Only auto-apply when imported as a module (not when run directly for testing)
    try:
        apply_patches()
    except Exception as e:
        logger.warning(f"Failed to apply Martin's patches: {e}")
        logger.warning("Continuing with default behavior")
