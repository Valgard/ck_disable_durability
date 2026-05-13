using System;
using System.IO;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Lazy-loaded mod configuration. Reads <c>config.json</c> from the
    /// directory containing this assembly. Falls back to defaults if the
    /// file is missing or malformed.
    /// </summary>
    [Serializable]
    internal sealed class ModConfig
    {
        // Public field (not property) because Unity's JsonUtility populates
        // fields, not properties. Default value matches the "missing file"
        // fallback — a user who installed the mod presumably wants it active.
        public bool enabled = true;

        private static ModConfig _instance;
        public static ModConfig Instance => _instance ??= Load();

        private static ModConfig Load()
        {
            var cfg = new ModConfig();
            var dllPath = typeof(ModConfig).Assembly.Location;
            var dllDir = Path.GetDirectoryName(dllPath);
            if (string.IsNullOrEmpty(dllDir)) return cfg;

            var cfgPath = Path.Combine(dllDir, "config.json");
            if (!File.Exists(cfgPath)) return cfg;

            try
            {
                var json = File.ReadAllText(cfgPath);
                var parsed = JsonUtility.FromJson<ModConfig>(json);
                if (parsed != null) cfg = parsed;
            }
            catch (Exception e)
            {
                Debug.LogWarning(
                    $"[DisableDurability] Config parse failed: {e.Message} — using defaults.");
            }
            return cfg;
        }
    }
}
