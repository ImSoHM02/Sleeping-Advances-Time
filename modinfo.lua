description =
[[
-V1.2.0-
Added time advancement mode selection:
- Instant Skip: Instantly skip to the next day (original behavior)
- Time Speedup: Speed up time while sleeping (configurable 2x-100x)
Added support for Siesta Lean-to and Webber's spider den sleeping.
Added configurable sleep delay (0-5 seconds) for both modes.
Added multiplayer sleep requirement options:
- All Players: Time advances only when all living players are asleep (default, prevents disruption in multiplayer)
- Any Player: Original behavior where any player can trigger time advance
Added debug logging toggle for troubleshooting (off by default).

-V1.1.0-
Added configuration options to multiply the effects of sleeping:
- Health Regeneration
- Sanity Regeneration
- Hunger Drain
- Crop Growth Speed
Each can be set from x0 (Off) to x5.

-V1.0.0-
Sleeping in a Tent, Portable Tent, or Straw Roll at dusk/night will advance time after a couple of seconds to the next day. Regen and hunger is calculated from time slept. Crops also grow during this time.
]]

name                        = "Sleeping advances time"
author                      = "Im So HM02"
version                     = "1.2.0"
forumthread                 = ""
icon                        = "modicon.tex"
icon_atlas                  = "modicon.xml"
api_version                 = 10
all_clients_require_mod     = true
dst_compatible              = true
client_only_mod             = false
priority 					= 0

--Configs

local Empty = {{description = "", data = 0}}

local function Title(title) --Allows use of an empty label as a header
    return {name=title, label = title, options=Empty, default=0,} -- label added for clarity in UI
end

local SEPARATOR = Title("") -- Though not used in this specific config, kept for consistency with example

local OptionEffectMultiplier = {
    {description = "Off (x0)", data = 0, hover = "The effect is disabled."},
    {description = "Normal (x1)", data = 1, hover = "Standard effect rate."},
    {description = "x2", data = 2, hover = "Effect is 2 times stronger/faster."},
    {description = "x3", data = 3, hover = "Effect is 3 times stronger/faster."},
    {description = "x4", data = 4, hover = "Effect is 4 times stronger/faster."},
    {description = "x5", data = 5, hover = "Effect is 5 times stronger/faster."}
}

configuration_options =
{
    {
        name    = "TIME_ADVANCE_MODE",
        label   = "Time Advancement Mode",
        hover   = "Choose how time advances while sleeping.",
        options = {
            {description = "Instant Skip", data = "instant", hover = "Instantly skip to the next day."},
            {description = "Time Speedup", data = "speedup", hover = "Speed up time while sleeping."}
        },
        default = "instant",
    },
    {
        name    = "SPEEDUP_MULTIPLIER",
        label   = "Time Speedup Multiplier",
        hover   = "How much faster time passes during sleep (only applies if Time Speedup mode is selected).",
        options = {
            {description = "x2", data = 2, hover = "Time passes 2 times faster."},
            {description = "x5", data = 5, hover = "Time passes 5 times faster."},
            {description = "x10", data = 10, hover = "Time passes 10 times faster."},
            {description = "x20", data = 20, hover = "Time passes 20 times faster."},
            {description = "x50", data = 50, hover = "Time passes 50 times faster."},
            {description = "x100", data = 100, hover = "Time passes 100 times faster."}
        },
        default = 10,
    },
    {
        name    = "SPEEDUP_DELAY",
        label   = "Sleep Delay",
        hover   = "How long to wait after going to sleep before time advances (applies to both Instant Skip and Time Speedup modes).",
        options = {
            {description = "No delay", data = 0, hover = "Time advances immediately."},
            {description = "1 second", data = 1, hover = "Wait 1 second before time advances."},
            {description = "2 seconds", data = 2, hover = "Wait 2 seconds before time advances."},
            {description = "3 seconds", data = 3, hover = "Wait 3 seconds before time advances."},
            {description = "5 seconds", data = 5, hover = "Wait 5 seconds before time advances."}
        },
        default = 2,
    },
    {
        name    = "MULTIPLAYER_SLEEP_MODE",
        label   = "Multiplayer Sleep Requirement",
        hover   = "How many players must be sleeping for time to advance in multiplayer games. (Solo play is unaffected)",
        options = {
            {description = "All Players", data = "all", hover = "All living players must be asleep for time to advance."},
            {description = "Any Player", data = "any", hover = "Any player can trigger time advance (original behavior)."}
        },
        default = "all",
    },
    {
        name    = "DEBUG_MODE",
        label   = "Debug Logging",
        hover   = "Enable or disable debug messages in the console log.",
        options = {
            {description = "Off", data = false, hover = "No debug messages."},
            {description = "On", data = true, hover = "Show debug messages in console."}
        },
        default = false,
    },
    Title("Sleep Effect Multipliers"),
    {
        name    = "HEALTH_MULT",
        label   = "Health Regeneration Multiplier",
        hover   = "Multiplier for health gained while sleeping.",
        options = OptionEffectMultiplier,
        default = 1,
    },
    {
        name    = "SANITY_MULT",
        label   = "Sanity Regeneration Multiplier",
        hover   = "Multiplier for sanity gained while sleeping.",
        options = OptionEffectMultiplier,
        default = 1,
    },
    {
        name    = "HUNGER_MULT",
        label   = "Hunger Drain Multiplier",
        hover   = "Multiplier for hunger lost while sleeping. Higher values mean faster hunger drain.",
        options = OptionEffectMultiplier,
        default = 1,
    },
    {
        name    = "CROP_GROWTH_MULT",
        label   = "Crop Growth Speed Multiplier",
        hover   = "Multiplier for how much crop growth is advanced during sleep.",
        options = OptionEffectMultiplier,
        default = 1,
    }
}