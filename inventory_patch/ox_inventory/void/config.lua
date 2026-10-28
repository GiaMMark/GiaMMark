-- Optional native companion for the VOID inventory UI.
-- These settings are local presentation settings, never inventory permissions.
VoidInventoryConfig = {
    StatusIntervalMs = 250,
    Preview = {
        Enabled = true,
        -- ox's full-screen game blur would also blur the 3D clone. This changes
        -- only this resource's existing screenblur setting while the addon runs.
        DisableNativeBlur = true,
        Distance = 4.5,
        Fov = 40.0,
        Height = 0.9,
        TargetHeight = 0.85,
        SideOffset = 1.7,
        RotateStep = 15.0,
        MaxMovement = 2.0
    },
    Hotkeys = {
        -- Original ox bindings 1..5 stay untouched. Enable only after checking
        -- your server's existing number-key bindings. UI clicks always work.
        ExtraEnabled = false,
        Keys = { [6] = '6', [7] = '7', [8] = '8', [9] = '9', [10] = '0' }
    }
}
