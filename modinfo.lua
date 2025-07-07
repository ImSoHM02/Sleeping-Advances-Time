description = 
[[
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
version                     = "1.1.0" -- Updated version
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