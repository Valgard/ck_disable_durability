using ModSettingsMenu.Settings;
using PlayerEquipment;
using PugMod;
using Unity.Entities;
using UnityEngine;

namespace DisableDurability
{
    /// <summary>
    /// Mod bootstrap. The Pugstorm mod loader instantiates this class on
    /// game start and calls the IMod lifecycle methods.
    ///
    /// The <see cref="BurstDisabler"/> call in <see cref="Init"/> is required
    /// because Harmony cannot patch Burst-compiled job entry points. By
    /// disabling Burst for the <see cref="ChangeDurabilitySystem"/> group,
    /// the system's managed <c>OnUpdate</c> method becomes patchable.
    /// </summary>
    public sealed class DisableDurabilityMod : IMod
    {
        public void EarlyInit() { }

        public void Init()
        {
            BurstDisabler.DisableBurstForSystem<ChangeDurabilitySystem>();

            // Registering the system is only half the job: the Burst bypass is
            // armed per world by BurstDisabler.AddWorld, whose sole caller is
            // ECSManager.StartEcs, and which snapshots the systems registered
            // up to that moment. Through CK 1.2 a dedicated server ran
            // IMod.Init() *after* StartEcs, so that snapshot was taken while our
            // registration was still missing, ChangeDurabilitySystem.OnUpdate
            // kept running through the Burst path and the prefix was never
            // reached. Re-run it for the worlds that exist by now.
            //
            // A fresh 1.3.0.5 dedicated server runs Init() before the snapshot,
            // and since 1.3 StartEcs calls BurstDisabler.ResetWorlds() before
            // its own AddWorld loop, wiping and re-arming whatever this pass
            // armed earlier. The pass stays: the SDK promises no ordering, and
            // the mod is still tagged for 1.2. It is harmless where it is not
            // needed because AddWorld only inserts a handle for a world that
            // contains the system (on a client, World.All at Init() time holds
            // leftover conversion worlds only), not because the registry is a
            // set. See core_keeper docs/ck/harmony-and-ecs.md.
            //
            // EarlyInit is not an option: TypeManager is not initialised yet
            // there, and DisableBurstForSystem throws NullReferenceException.
            foreach (var world in World.All)
                BurstDisabler.AddWorld(world);

            ModSettings.Section(this).Toggle(out var en, "enabled", true).Build();
            ModConfig.Instance.Bind(en);

            Debug.Log($"[DisableDurability] Mod initialized. Enabled={ModConfig.Instance.enabled}");
        }

        public void ModObjectLoaded(Object obj) { }

        public void Shutdown() { }

        public void Update() { }
    }
}
