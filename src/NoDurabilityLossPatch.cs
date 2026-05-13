using HarmonyLib;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Harmony Prefix that suppresses durability decrement on equipped items.
    /// Target identified via PermaBreak inspection — see
    /// <c>docs/research/permabreak-patch-target.md</c>.
    ///
    /// Returning <c>false</c> from the Prefix skips the original method;
    /// returning <c>true</c> lets it run normally (used when the mod is disabled).
    /// </summary>
    [HarmonyPatch(typeof(PlayerController), nameof(PlayerController.ReduceDurabilityOfEquipment))]
    [HarmonyPriority(Priority.Last)]
    public static class NoDurabilityLossPatch
    {
        static NoDurabilityLossPatch()
        {
            Debug.Log(
                $"[DisableDurability] Patch loaded. " +
                $"Enabled={ModConfig.Instance.enabled}");
        }

        [HarmonyPrefix]
        private static bool Prefix()
        {
            if (!ModConfig.Instance.enabled) return true;  // run original
            return false;                                   // skip original
        }
    }
}
