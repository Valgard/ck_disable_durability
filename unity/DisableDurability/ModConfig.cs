namespace DisableDurability
{
    /// <summary>
    /// Mod configuration. V1 ships with a hardcoded <c>enabled = true</c>
    /// because Pugstorm's mod-loader compiles mod scripts with the RoslynCSharp
    /// sandbox, which blocks <see cref="System.IO"/> by default. Reading a
    /// <c>config.json</c> next to the mod requires either
    /// <c>skipSafetyChecks: true</c> in the manifest (security-trade-off) or
    /// a Pugstorm-provided safe file API. Both are V2 candidates; V1 keeps
    /// the API shape stable (<c>ModConfig.Instance.enabled</c>) so a future
    /// config-loader can drop in without changing consumers.
    /// </summary>
    internal sealed class ModConfig
    {
        public bool enabled = true;

        private static readonly ModConfig _instance = new ModConfig();
        public static ModConfig Instance => _instance;
    }
}
