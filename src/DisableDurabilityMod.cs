using PugMod;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Mod bootstrap. The Pugstorm mod loader instantiates this class on
    /// game start and calls the IMod lifecycle methods. We don't need
    /// custom logic here — Harmony patches in this assembly are discovered
    /// automatically — but having an IMod implementation matches the
    /// pattern used by other published Core Keeper mods (e.g., PermaBreak).
    /// </summary>
    public sealed class DisableDurabilityMod : IMod
    {
        public void EarlyInit()
        {
        }

        public void Init()
        {
            Debug.Log(
                $"[DisableDurability] Mod initialized. Enabled={ModConfig.Instance.enabled}");
        }

        public void ModObjectLoaded(Object obj)
        {
        }

        public void Shutdown()
        {
        }

        public void Update()
        {
        }
    }
}
