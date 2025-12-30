-- Initialize config values in TUNING
GLOBAL.TUNING.SLEEPING_ADVANCES_TIME = {
    HEALTH_MULT = GetModConfigData("HEALTH_MULT") or 1,
    SANITY_MULT = GetModConfigData("SANITY_MULT") or 1,
    HUNGER_MULT = GetModConfigData("HUNGER_MULT") or 1,
    CROP_GROWTH_MULT = GetModConfigData("CROP_GROWTH_MULT") or 1,
    TIME_ADVANCE_MODE = GetModConfigData("TIME_ADVANCE_MODE") or "instant",
    SPEEDUP_MULTIPLIER = GetModConfigData("SPEEDUP_MULTIPLIER") or 10,
    SPEEDUP_DELAY = GetModConfigData("SPEEDUP_DELAY") or 2,
    MULTIPLAYER_SLEEP_MODE = GetModConfigData("MULTIPLAYER_SLEEP_MODE") or "all",
    DEBUG_MODE = GetModConfigData("DEBUG_MODE") or false
}

-- Helper function for debug logging
local function DebugPrint(...)
    if GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.DEBUG_MODE then
        print(...)
    end
end

-- Helper function to apply stat changes
local function ApplyStatChanges(sleeper, time_delta, health_mult, sanity_mult, hunger_mult)
    if sleeper.components.sanity then
        sleeper.components.sanity:DoDelta(time_delta * TUNING.SLEEP_SANITY_PER_TICK * sanity_mult)
    end
    if sleeper.components.hunger then
        sleeper.components.hunger:DoDelta(time_delta * TUNING.SLEEP_HUNGER_PER_TICK * hunger_mult, false, true)
    end
    if sleeper.components.health then
        sleeper.components.health:DoDelta(time_delta * TUNING.SLEEP_HEALTH_PER_TICK * 2 * health_mult, false, "tent", true)
    end
    if sleeper.components.temperature then
        local Temperature = (time_delta * TUNING.SLEEP_TEMP_PER_TICK)
        if ((sleeper.components.temperature:GetCurrent() + Temperature) > TUNING.SLEEP_TARGET_TEMP_TENT) then
            Temperature = TUNING.SLEEP_TARGET_TEMP_TENT
        end
        sleeper.components.temperature:SetTemperature(Temperature)
    end
    if sleeper.components.moisture then
        sleeper.components.moisture:DoDelta(time_delta * TUNING.SLEEP_WETNESS_PER_TICK)
    end
end

-- Helper function to check if all players are sleeping (for multiplayer)
local function AreAllPlayersSleeping()
    local multiplayer_mode = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.MULTIPLAYER_SLEEP_MODE

    -- If mode is "any", then we don't need to check all players
    if multiplayer_mode == "any" then
        return true
    end

    -- Get all players in the game
    local all_players = GLOBAL.AllPlayers or {}
    local sleeping_count = 0
    local living_count = 0

    for _, player in ipairs(all_players) do
        -- Only count living players (not ghosts or invalid players)
        if player and player:IsValid() and not player:HasTag("playerghost") then
            living_count = living_count + 1

            -- Check if player is sleeping
            if player.sleepingbag ~= nil then
                sleeping_count = sleeping_count + 1
            end
        end
    end

    DebugPrint(string.format("[SleepingAdvancesTime] Multiplayer check: %d/%d players sleeping", sleeping_count, living_count))

    -- If no living players, return false (shouldn't happen, but safety check)
    if living_count == 0 then
        return false
    end

    -- All living players must be sleeping
    return sleeping_count == living_count
end

-- Instant skip mode (original behavior)
local function SleepingAdvancesTimeInstant(inst, sleeper)
    DebugPrint("[SleepingAdvancesTime] Instant mode - Function called for sleeper: " .. (sleeper and sleeper.prefab or "nil"))
    if (not GLOBAL.TheWorld.ismastersim) then
        DebugPrint("[SleepingAdvancesTime] Not master sim, returning.")
        return
    end

    -- Get the sleep delay from config
    local sleep_delay = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_DELAY

    inst:DoTaskInTime(sleep_delay, function()
        DebugPrint("[SleepingAdvancesTime] DoTaskInTime callback started.")

        -- Check if all players are sleeping (multiplayer requirement)
        if not AreAllPlayersSleeping() then
            DebugPrint("[SleepingAdvancesTime] Not all players are sleeping, skipping time advance.")
            return
        end

        -- Get config values from TUNING
        local health_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HEALTH_MULT
        local sanity_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SANITY_MULT
        local hunger_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HUNGER_MULT
        local crop_growth_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.CROP_GROWTH_MULT

        DebugPrint(string.format("[SleepingAdvancesTime] Multipliers: Health=%.2f, Sanity=%.2f, Hunger=%.2f, CropGrowth=%.2f", health_mult, sanity_mult, hunger_mult, crop_growth_mult))

        local Time          = 0
        local PhaseTimeLeft = (1 - GLOBAL.TheWorld.state.timeinphase)
        local Length_Dusk   = (TUNING.SEG_TIME * TUNING.DUSK_SEGS_DEFAULT)
        local Length_Night  = (TUNING.SEG_TIME * TUNING.NIGHT_SEGS_DEFAULT)

        if (GLOBAL.TheWorld.state.phase == "dusk") then
            Time = (Length_Dusk * PhaseTimeLeft)
            Time = Time + (Length_Night * PhaseTimeLeft)

        elseif (GLOBAL.TheWorld.state.phase == "night") then
            Time = (Length_Night * PhaseTimeLeft)
        end

        local TotalSleepDuration = Time -- Store the original, uncapped time for crop growth

        local MinStatPercentage = 0
        local MaxStat           = 0
        local TickRate          = 0

        if (sleeper.components.health:GetPercentWithPenalty() < sleeper.components.sanity:GetPercentWithPenalty()) then
            MinStatPercentage = sleeper.components.health:GetPercentWithPenalty()
            MaxStat = sleeper.components.health:GetMaxWithPenalty()
            TickRate = TUNING.SLEEP_HEALTH_PER_TICK
        else
            MinStatPercentage = sleeper.components.sanity:GetPercentWithPenalty()
            MaxStat = sleeper.components.sanity:GetMaxWithPenalty()
            TickRate = TUNING.SLEEP_SANITY_PER_TICK
        end

        local TicksNeeded = ((MaxStat * (1 - MinStatPercentage)) * TickRate)

        local TicksAvailable = (sleeper.components.hunger.current / -TUNING.SLEEP_HUNGER_PER_TICK)

        if (not GLOBAL.TheWorld:HasTag("cave")) then
            if (Time > TicksAvailable) then
                Time = TicksAvailable
            end
            if (Time > TicksNeeded) then
                Time = TicksNeeded
            end
        else
            if (TicksAvailable > TicksNeeded) then
                TicksAvailable = TicksNeeded
            end

            Time = TicksAvailable
        end

        -- Apply stat changes
        ApplyStatChanges(sleeper, Time, health_mult, sanity_mult, hunger_mult)

        -- Crop Growth Logic
        local effectiveCropGrowthDuration = TotalSleepDuration * crop_growth_mult
        if effectiveCropGrowthDuration > 0 and GLOBAL.TheWorld and sleeper then -- Keep GLOBAL.TheWorld check for safety, ensure sleeper is available
            DebugPrint("[SleepingAdvancesTime] TotalSleepDuration (original): " .. tostring(TotalSleepDuration) .. ", EffectiveCropGrowthDuration (after mult): " .. tostring(effectiveCropGrowthDuration))
            local sx, sy, sz = sleeper.Transform:GetWorldPosition()
            local search_radius = 100 -- A large radius to find nearby plants
            local plants_found = GLOBAL.TheSim:FindEntities(sx, sy, sz, search_radius, {"plant"}) -- Find entities with "plant" tag

            if plants_found and #plants_found > 0 then
                for i, ent in ipairs(plants_found) do
                    if ent and ent.components.growable and ent.prefab and string.sub(ent.prefab, 1, 11) == "farm_plant_" then
                        DebugPrint("[SleepingAdvancesTime] Processing plant: " .. ent.prefab .. " using FindEntities")
                        local stage_before = ent.components.growable:GetStage()
                        local debug_string_before = ent.components.growable:GetDebugString()
                        DebugPrint("[SleepingAdvancesTime]   Stage before LongUpdate for " .. ent.prefab .. ": " .. tostring(stage_before) .. " | Debug: " .. tostring(debug_string_before))

                        ent.components.growable:LongUpdate(effectiveCropGrowthDuration)

                        local stage_after = ent.components.growable:GetStage()
                        local debug_string_after = ent.components.growable:GetDebugString()
                        DebugPrint("[SleepingAdvancesTime]   Stage after LongUpdate for " .. ent.prefab .. ": " .. tostring(stage_after) .. " | Debug: " .. tostring(debug_string_after))
                    end
                end
            end
        else
            -- DEBUG: Log why crop growth might be skipped
            if not (effectiveCropGrowthDuration > 0) then
                DebugPrint("[SleepingAdvancesTime] Crop growth skipped: effectiveCropGrowthDuration was not > 0. Original: " .. tostring(TotalSleepDuration) .. ", Multiplier: " .. tostring(crop_growth_mult))
            end
            if not GLOBAL.TheWorld then
                DebugPrint("[SleepingAdvancesTime] Crop growth skipped: GLOBAL.TheWorld is nil.")
            end
            if not sleeper then
                DebugPrint("[SleepingAdvancesTime] Crop growth skipped: sleeper object is nil.")
            end
        end

        if (inst.components.finiteuses ~= nil) then
            inst.components.finiteuses:Use()
        end

        GLOBAL.TheWorld:PushEvent("ms_nextcycle")

        sleeper.sg:GoToState("wakeup")
    end)
end

-- Time speedup mode (speeds up time instead of instant skip)
local function SleepingAdvancesTimeSpeedup(inst, sleeper)
    DebugPrint("[SleepingAdvancesTime] Speedup mode - Function called for sleeper: " .. (sleeper and sleeper.prefab or "nil"))
    if (not GLOBAL.TheWorld.ismastersim) then
        DebugPrint("[SleepingAdvancesTime] Not master sim, returning.")
        return
    end

    -- Store the original onwake callback
    local original_onwake = inst.components.sleepingbag.onwake

    -- Get the speedup delay from config
    local speedup_delay = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_DELAY

    inst:DoTaskInTime(speedup_delay, function()
        DebugPrint("[SleepingAdvancesTime] Speedup mode - DoTaskInTime callback started.")

        -- Check if all players are sleeping (multiplayer requirement)
        if not AreAllPlayersSleeping() then
            DebugPrint("[SleepingAdvancesTime] Not all players are sleeping, skipping time speedup.")
            return
        end

        -- Get config values from TUNING
        local health_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HEALTH_MULT
        local sanity_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SANITY_MULT
        local hunger_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HUNGER_MULT
        local crop_growth_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.CROP_GROWTH_MULT
        local speedup_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_MULTIPLIER

        DebugPrint(string.format("[SleepingAdvancesTime] Speedup: %dx, Multipliers: Health=%.2f, Sanity=%.2f, Hunger=%.2f, CropGrowth=%.2f",
            speedup_mult, health_mult, sanity_mult, hunger_mult, crop_growth_mult))

        local starting_phase = GLOBAL.TheWorld.state.phase
        local original_timescale = GLOBAL.TheSim:GetTimeScale()

        -- Set the time scale to speed up time
        GLOBAL.TheSim:SetTimeScale(speedup_mult)
        DebugPrint("[SleepingAdvancesTime] Time scale set to " .. speedup_mult)

        -- Override the hunger_tick to reduce hunger drain during speedup
        local original_hunger_tick = inst.components.sleepingbag.hunger_tick
        if original_hunger_tick then
            inst.components.sleepingbag.hunger_tick = original_hunger_tick / speedup_mult
            DebugPrint("[SleepingAdvancesTime] Adjusted hunger_tick from " .. tostring(original_hunger_tick) .. " to " .. tostring(inst.components.sleepingbag.hunger_tick))
        end

        -- Track state changes
        local sleep_data = {
            active = true,
            last_update_time = GLOBAL.GetTime(),
            total_elapsed = 0,
            update_task = nil,  -- Will store the task reference
            cleaned_up = false  -- Flag to prevent double cleanup
        }

        -- Cleanup function that restores everything
        local function CleanupSpeedup()
            if sleep_data.cleaned_up then
                return  -- Already cleaned up
            end
            sleep_data.cleaned_up = true

            DebugPrint("[SleepingAdvancesTime] Cleaning up speedup mode")

            -- Restore time scale
            GLOBAL.TheSim:SetTimeScale(original_timescale)
            DebugPrint("[SleepingAdvancesTime] Time scale restored to " .. original_timescale)

            -- Restore original hunger_tick
            if original_hunger_tick then
                inst.components.sleepingbag.hunger_tick = original_hunger_tick
                DebugPrint("[SleepingAdvancesTime] Restored hunger_tick to " .. tostring(original_hunger_tick))
            end

            -- Restore original onwake callback
            inst.components.sleepingbag.onwake = original_onwake

            -- Apply crop growth for total elapsed time
            local effectiveCropGrowthDuration = sleep_data.total_elapsed * crop_growth_mult
            if effectiveCropGrowthDuration > 0 and sleeper and sleeper:IsValid() then
                DebugPrint("[SleepingAdvancesTime] Total sleep time: " .. tostring(sleep_data.total_elapsed) .. ", Effective crop growth: " .. tostring(effectiveCropGrowthDuration))
                local sx, sy, sz = sleeper.Transform:GetWorldPosition()
                local search_radius = 100
                local plants_found = GLOBAL.TheSim:FindEntities(sx, sy, sz, search_radius, {"plant"})

                if plants_found and #plants_found > 0 then
                    for i, ent in ipairs(plants_found) do
                        if ent and ent.components.growable and ent.prefab and string.sub(ent.prefab, 1, 11) == "farm_plant_" then
                            DebugPrint("[SleepingAdvancesTime] Processing plant: " .. ent.prefab)
                            ent.components.growable:LongUpdate(effectiveCropGrowthDuration)
                        end
                    end
                end
            end

            -- Cancel the update task
            if sleep_data.update_task ~= nil then
                sleep_data.update_task:Cancel()
                sleep_data.update_task = nil
            end
        end

        -- Override onwake to ensure cleanup happens when vanilla sleep ends
        inst.components.sleepingbag.onwake = function(inst, sleeper, nostatechange)
            CleanupSpeedup()
            -- Call original onwake if it exists
            if original_onwake then
                original_onwake(inst, sleeper, nostatechange)
            end
        end

        -- Periodic task to apply stat changes and check conditions
        sleep_data.update_task = inst:DoPeriodicTask(1, function()
            if not sleep_data.active then
                return
            end

            -- Check if sleeper is still sleeping
            if not sleeper or not sleeper:IsValid() or sleeper.sg:HasStateTag("waking") or not sleeper.sleepingbag then
                DebugPrint("[SleepingAdvancesTime] Sleeper woke up or is invalid, stopping speedup")
                sleep_data.active = false
                return
            end

            -- Calculate elapsed time since last update
            local current_time = GLOBAL.GetTime()
            local delta_time = (current_time - sleep_data.last_update_time)
            sleep_data.last_update_time = current_time
            sleep_data.total_elapsed = sleep_data.total_elapsed + delta_time

            -- Note: We don't manually apply stat changes in speedup mode because
            -- the vanilla sleepingbaguser component handles stat changes automatically,
            -- and it will run faster due to the time speedup.
            -- Our stat multipliers won't apply in speedup mode (vanilla rates only)

            -- Check if phase has changed to day
            if GLOBAL.TheWorld.state.phase ~= starting_phase and GLOBAL.TheWorld.state.phase == "day" then
                DebugPrint("[SleepingAdvancesTime] Phase changed to day, waking up sleeper")
                sleep_data.active = false
            end

            -- Check if player is out of hunger
            if sleeper.components.hunger and sleeper.components.hunger.current <= 0 then
                DebugPrint("[SleepingAdvancesTime] Sleeper out of hunger, waking up")
                sleep_data.active = false
            end

            -- If we should stop, clean up and wake the player
            if not sleep_data.active then
                CleanupSpeedup()

                -- Use tent durability
                if (inst.components.finiteuses ~= nil) then
                    inst.components.finiteuses:Use()
                end

                -- Wake up the sleeper
                if sleeper and sleeper:IsValid() and sleeper.sg then
                    sleeper.sg:GoToState("wakeup")
                end
            end
        end)
    end)
end

-- Wrapper function that chooses which mode to use
local function SleepingAdvancesTime(inst, sleeper)
    local mode = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.TIME_ADVANCE_MODE
    if mode == "speedup" then
        SleepingAdvancesTimeSpeedup(inst, sleeper)
    else
        SleepingAdvancesTimeInstant(inst, sleeper)
    end
end


local function ApplySleepLogic(Prefab)
    if Prefab.components.sleepingbag ~= nil then
        Prefab.components.sleepingbag.onsleep = SleepingAdvancesTime
    end
end

-- For spider dens, the sleepingbag component is added with a delay,
-- so we need to apply our logic after it's been added
local function ApplySleepLogicDelayed(Prefab)
    if not GLOBAL.TheWorld.ismastersim then
        return
    end

    -- Check periodically if sleepingbag component has been added and apply our logic
    local function CheckAndApplySleepLogic(inst)
        if inst.components.sleepingbag ~= nil and inst.components.sleepingbag.onsleep ~= SleepingAdvancesTime then
            DebugPrint("[SleepingAdvancesTime] Applying sleep logic to spider den")
            inst.components.sleepingbag.onsleep = SleepingAdvancesTime
        end
    end

    -- Initial check after a delay
    Prefab:DoTaskInTime(0, CheckAndApplySleepLogic)

    -- Periodic check in case den grows to tier 3 later
    Prefab:DoPeriodicTask(5, CheckAndApplySleepLogic)
end

AddPrefabPostInit("tent", ApplySleepLogic)
AddPrefabPostInit("portabletent", ApplySleepLogic)
AddPrefabPostInit("siestahut", ApplySleepLogic)
AddPrefabPostInit("bedroll_straw", ApplySleepLogic)
--Seems to be an error where it uses 66% of the furry bedroll in one use, so disabled for now.
--AddPrefabPostInit("bedroll_furry", ApplySleepLogic)

-- Spider dens for Webber (all 3 tiers, sleeping bag is only added at tier 3)
AddPrefabPostInit("spiderden", ApplySleepLogicDelayed)
AddPrefabPostInit("spiderden_2", ApplySleepLogicDelayed)
AddPrefabPostInit("spiderden_3", ApplySleepLogicDelayed)