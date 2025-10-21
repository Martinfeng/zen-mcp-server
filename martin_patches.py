"""
Martin's Custom Patches for Zen MCP Server

This module applies runtime patches to enable custom base URL configuration
for OpenAI and other providers without modifying the original source code.

Usage:
    Import this module at the very beginning of server.py:
        import martin_patches  # Apply custom patches

    Then configure via environment variables:
        OPENAI_BASE_URL=https://your-proxy.com/v1
        XAI_BASE_URL=https://your-xai-proxy.com/v1
        DIAL_BASE_URL=https://your-dial-endpoint.com

Author: Martin (Feng)
Date: 2025-10-21
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
    success = _patch_provider_base_urls()

    if success:
        _PATCHES_APPLIED = True
        logger.info("✅ Martin's custom patches applied successfully")
    else:
        logger.error("❌ Failed to apply Martin's custom patches")
        logger.error("   Custom base URL support will NOT be available")


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
