using ModSettingsMenu.Settings;

namespace DisableDurability
{
    /// <summary>
    /// Mod configuration adapter. `enabled` is now a live in-game setting from the Mod
    /// Settings Menu framework, bound once in DisableDurabilityMod.Init via Bind(). The
    /// getter is source-compatible (field -> property), so NoDurabilityLossPatch reads
    /// ModConfig.Instance.enabled unchanged. The RoslynCSharp sandbox blocks System.IO;
    /// the framework persists the value via CoreLib, so the mod's own code touches no
    /// file API.
    /// </summary>
    internal sealed class ModConfig
    {
        // Live handle set once by DisableDurabilityMod.Init via Bind(); null only in the brief
        // pre-Bind window at mod load -> the hardcoded default (true) applies. The patch fires
        // during gameplay, strictly after Bind, and the framework is a hard dependency (never absent).
        private SettingHandle<bool> _enabledHandle;

        public void Bind(SettingHandle<bool> enabled)
        {
            _enabledHandle = enabled;
        }

        // Master switch (default true). When false, NoDurabilityLossPatch falls through to vanilla.
        public bool enabled => _enabledHandle != null ? _enabledHandle.Value : true;

        private static readonly ModConfig _instance = new ModConfig();
        public static ModConfig Instance => _instance;
    }
}
