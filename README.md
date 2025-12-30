# Sleeping Advances Time

A Don't Starve Together mod that allows players to skip or speed up time while sleeping, with configurable effects on health regeneration, sanity regeneration, hunger drain, and crop growth.

## Features

### Time Advancement Modes
- **Instant Skip**: Instantly skip to the next day (original behavior)
- **Time Speedup**: Speed up time while sleeping with configurable multiplier (2x-100x)

### Supported Sleeping Structures
- Tent
- Portable Tent
- Straw Roll
- Siesta Lean-to
- Webber's Spider Den (tier 3)

### Configurable Sleep Effects
Customize the multipliers for sleep effects (x0 to x5):
- **Health Regeneration**: Adjust how much health you gain while sleeping
- **Sanity Regeneration**: Adjust how much sanity you gain while sleeping
- **Hunger Drain**: Adjust how much hunger you lose while sleeping
- **Crop Growth Speed**: Adjust how much crops grow during sleep

### Multiplayer Support
- **All Players Mode** (default): Time advances only when all living players are asleep, preventing disruption in multiplayer games
- **Any Player Mode**: Original behavior where any player can trigger time advance
- Ghost players don't count toward the sleep requirement

### Additional Settings
- **Sleep Delay**: Configure delay before time advances (0-5 seconds, default 2)
- **Debug Logging**: Toggle debug messages in console for troubleshooting

## Configuration

All settings can be configured through the in-game mod configuration menu:

### Time Settings
- **Time Advancement Mode**: Choose between Instant Skip or Time Speedup
- **Time Speedup Multiplier**: How much faster time passes (2x to 100x, default 10x)
- **Sleep Delay**: How long to wait before time advances (0-5 seconds, default 2)
- **Multiplayer Sleep Requirement**: Whether all players or any player must be asleep

### Effect Multipliers
- **Health Regeneration Multiplier**: x0 to x5 (default x1)
- **Sanity Regeneration Multiplier**: x0 to x5 (default x1)
- **Hunger Drain Multiplier**: x0 to x5 (default x1)
- **Crop Growth Speed Multiplier**: x0 to x5 (default x1)

### Debug
- **Debug Logging**: Enable/disable debug console messages (default off)

## How It Works

### Instant Skip Mode
When a player goes to sleep at dusk or night:
1. After the configured delay, the mod checks if sleep requirements are met (multiplayer check)
2. Time instantly skips to the next day
3. Health, sanity, and hunger are adjusted based on calculated sleep time and multipliers
4. Nearby crops grow based on sleep time and crop growth multiplier

### Time Speedup Mode
When a player goes to sleep at dusk or night:
1. After the configured delay, the mod checks if sleep requirements are met
2. Game time is sped up by the configured multiplier
3. Vanilla sleep mechanics handle stat changes (runs faster due to time speedup)
4. Player wakes up when day arrives or hunger runs out
5. Crops grow based on total sleep time and crop growth multiplier

## Multiplayer Considerations

By default (v1.2.0+), the mod is configured for **All Players** mode to ensure fair multiplayer gameplay:
- Time will only advance when all living players are asleep
- Ghost players don't block time advancement
- Solo play works normally (you're the only player, so requirement is automatically met)

If you prefer the original behavior where any player can advance time, change the "Multiplayer Sleep Requirement" setting to "Any Player".

## Version History

### V1.2.0
- Added time advancement mode selection (Instant Skip / Time Speedup)
- Added configurable time speedup multiplier (2x-100x)
- Added support for Siesta Lean-to sleeping
- Added support for Webber's spider den sleeping
- Added configurable sleep delay (0-5 seconds) for both modes
- Added multiplayer sleep requirement options (All Players / Any Player)
- Added debug logging toggle for troubleshooting

### V1.1.0
- Added configuration options for sleep effect multipliers
- Health Regeneration multiplier (x0-x5)
- Sanity Regeneration multiplier (x0-x5)
- Hunger Drain multiplier (x0-x5)
- Crop Growth Speed multiplier (x0-x5)

### V1.0.0
- Initial release
- Sleeping in tent, portable tent, or straw roll advances time to next day
- Health, sanity, and hunger calculated from time slept
- Crops grow during sleep time

## Installation

1. Subscribe to the mod on the Steam Workshop, or
2. Download and extract to your Don't Starve Together mods folder:
   - Windows: `Documents/Klei/DoNotStarveTogether/mods/`
   - Mac: `~/Documents/Klei/DoNotStarveTogether/mods/`
   - Linux: `~/.klei/DoNotStarveTogether/mods/`
3. Enable the mod in the game's mod menu
4. Configure settings as desired
5. Start a new world or join a server with the mod enabled

## Compatibility

- **DST Compatible**: Yes
- **Client/Server**: All clients require the mod
- **Client Only Mod**: No

## Credits

**Author**: Im So HM02

## License

This mod is provided as-is for Don't Starve Together.
