-- Initialize config values in TUNING
GLOBAL.TUNING.SLEEPING_ADVANCES_TIME = {
    HEALTH_MULT = GetModConfigData("HEALTH_MULT") or 1,
    SANITY_MULT = GetModConfigData("SANITY_MULT") or 1,
    HUNGER_MULT = GetModConfigData("HUNGER_MULT") or 1,
    CROP_GROWTH_MULT = GetModConfigData("CROP_GROWTH_MULT") or 1,
    TIME_ADVANCE_MODE = GetModConfigData("TIME_ADVANCE_MODE") or "instant",
    SPEEDUP_MULTIPLIER = GetModConfigData("SPEEDUP_MULTIPLIER") or 10,
    SPEEDUP_DELAY = GetModConfigData("SPEEDUP_DELAY") or 2,
    MULTIPLAYER_SLEEP_MODE = GetModConfigData("MULTIPLAYER_SLEEP_MODE") or "all"
}

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
        local current_temp = sleeper.components.temperature:GetCurrent()
        local temp_delta = time_delta * TUNING.SLEEP_TEMP_PER_TICK
        local new_temp = math.min(current_temp + temp_delta, TUNING.SLEEP_TARGET_TEMP_TENT)
        sleeper.components.temperature:SetTemperature(new_temp)
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

    print(string.format("[SleepingAdvancesTime] Multiplayer check: %d/%d players sleeping", sleeping_count, living_count)) -- DEBUG

    -- If no living players, return false (shouldn't happen, but safety check)
    if living_count == 0 then
        return false
    end

    -- All living players must be sleeping
    return sleeping_count == living_count
end

-- Instant skip mode (original behavior)
local function SleepingAdvancesTimeInstant(inst, sleeper)
    print("[SleepingAdvancesTime] Instant mode - Function called for sleeper: " .. (sleeper and sleeper.prefab or "nil")) -- DEBUG
    if (not GLOBAL.TheWorld.ismastersim) then
        print("[SleepingAdvancesTime] Not master sim, returning.") -- DEBUG
        return
    end

    -- Get the sleep delay from config
    local sleep_delay = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_DELAY

    inst:DoTaskInTime(sleep_delay, function()
        print("[SleepingAdvancesTime] DoTaskInTime callback started.") -- DEBUG

        -- Check if all players are sleeping (multiplayer requirement)
        if not AreAllPlayersSleeping() then
            print("[SleepingAdvancesTime] Not all players are sleeping, skipping time advance.") -- DEBUG
            return
        end

        -- Get config values from TUNING
        local health_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HEALTH_MULT
        local sanity_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SANITY_MULT
        local hunger_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HUNGER_MULT
        local crop_growth_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.CROP_GROWTH_MULT
        
        print(string.format("[SleepingAdvancesTime] Multipliers: Health=%.2f, Sanity=%.2f, Hunger=%.2f, CropGrowth=%.2f", health_mult, sanity_mult, hunger_mult, crop_growth_mult)) -- DEBUG

        local Time          = 0
        local PhaseTimeLeft = (1 - GLOBAL.TheWorld.state.timeinphase)
        local Length_Day    = (TUNING.SEG_TIME * TUNING.DAY_SEGS_DEFAULT)
        local Length_Dusk   = (TUNING.SEG_TIME * TUNING.DUSK_SEGS_DEFAULT)
        local Length_Night  = (TUNING.SEG_TIME * TUNING.NIGHT_SEGS_DEFAULT)
        local is_siesta     = (GLOBAL.TheWorld.state.phase == "day") -- Track if this is a daytime siesta

        if (GLOBAL.TheWorld.state.phase == "day") then
            -- Siesta: remaining day time until dusk
            Time = (Length_Day * PhaseTimeLeft)

        elseif (GLOBAL.TheWorld.state.phase == "dusk") then
            -- Remaining dusk time plus full night duration
            Time = (Length_Dusk * PhaseTimeLeft) + Length_Night

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

        -- Apply stat changes (health, sanity, temperature, moisture use capped Time)
        -- Hunger uses TotalSleepDuration since it should drain based on actual time skipped
        ApplyStatChanges(sleeper, Time, health_mult, sanity_mult, 0) -- No hunger here

        -- Apply hunger drain separately based on total sleep duration
        -- Use the sleeping item's hunger_tick rate (varies per item - siesta is slower than tent/bedroll)
        local hunger_tick = inst.components.sleepingbag and inst.components.sleepingbag.hunger_tick or TUNING.SLEEP_HUNGER_PER_TICK
        if sleeper.components.hunger and hunger_mult > 0 then
            sleeper.components.hunger:DoDelta(TotalSleepDuration * hunger_tick * hunger_mult, false, true)
        end

        -- Crop Growth Logic
        local effectiveCropGrowthDuration = TotalSleepDuration * crop_growth_mult
        if effectiveCropGrowthDuration > 0 and GLOBAL.TheWorld and sleeper then -- Keep GLOBAL.TheWorld check for safety, ensure sleeper is available
            print("[SleepingAdvancesTime] TotalSleepDuration (original): " .. tostring(TotalSleepDuration) .. ", EffectiveCropGrowthDuration (after mult): " .. tostring(effectiveCropGrowthDuration)) -- DEBUG
            local sx, sy, sz = sleeper.Transform:GetWorldPosition()
            local search_radius = 100 -- A large radius to find nearby plants
            local plants_found = GLOBAL.TheSim:FindEntities(sx, sy, sz, search_radius, {"plant"}) -- Find entities with "plant" tag

            if plants_found and #plants_found > 0 then
                for i, ent in ipairs(plants_found) do
                    if ent and ent.components.growable and ent.prefab and string.sub(ent.prefab, 1, 11) == "farm_plant_" then
                        print("[SleepingAdvancesTime] Processing plant: " .. ent.prefab .. " using FindEntities") -- DEBUG
                        local stage_before = ent.components.growable:GetStage()
                        local debug_string_before = ent.components.growable:GetDebugString()
                        print("[SleepingAdvancesTime]   Stage before LongUpdate for " .. ent.prefab .. ": " .. tostring(stage_before) .. " | Debug: " .. tostring(debug_string_before)) -- DEBUG
                        
                        ent.components.growable:LongUpdate(effectiveCropGrowthDuration)
                        
                        local stage_after = ent.components.growable:GetStage()
                        local debug_string_after = ent.components.growable:GetDebugString()
                        print("[SleepingAdvancesTime]   Stage after LongUpdate for " .. ent.prefab .. ": " .. tostring(stage_after) .. " | Debug: " .. tostring(debug_string_after)) -- DEBUG
                    end
                end
            end
        else
            -- DEBUG: Log why crop growth might be skipped
            if not (effectiveCropGrowthDuration > 0) then
                print("[SleepingAdvancesTime] Crop growth skipped: effectiveCropGrowthDuration was not > 0. Original: " .. tostring(TotalSleepDuration) .. ", Multiplier: " .. tostring(crop_growth_mult)) -- DEBUG
            end
            if not GLOBAL.TheWorld then
                print("[SleepingAdvancesTime] Crop growth skipped: GLOBAL.TheWorld is nil.") -- DEBUG
            end
            if not sleeper then
                print("[SleepingAdvancesTime] Crop growth skipped: sleeper object is nil.") -- DEBUG
            end
        end

        -- Note: We don't call finiteuses:Use() here because the vanilla onwake
        -- callback handles durability consumption when GoToState("wakeup") triggers

        -- Siesta advances to dusk, regular sleep advances to next day
        if is_siesta then
            GLOBAL.TheWorld:PushEvent("ms_nextphase") -- Advance to dusk
        else
            GLOBAL.TheWorld:PushEvent("ms_nextcycle") -- Advance to next day
        end

        sleeper.sg:GoToState("wakeup")
    end)
end

-- Time speedup mode (speeds up time instead of instant skip)
local function SleepingAdvancesTimeSpeedup(inst, sleeper)
    print("[SleepingAdvancesTime] Speedup mode - Function called for sleeper: " .. (sleeper and sleeper.prefab or "nil")) -- DEBUG
    if (not GLOBAL.TheWorld.ismastersim) then
        print("[SleepingAdvancesTime] Not master sim, returning.") -- DEBUG
        return
    end

    -- Store the original onwake callback
    local original_onwake = inst.components.sleepingbag.onwake

    -- Get the speedup delay from config
    local speedup_delay = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_DELAY

    inst:DoTaskInTime(speedup_delay, function()
        print("[SleepingAdvancesTime] Speedup mode - DoTaskInTime callback started.") -- DEBUG

        -- Check if all players are sleeping (multiplayer requirement)
        if not AreAllPlayersSleeping() then
            print("[SleepingAdvancesTime] Not all players are sleeping, skipping time speedup.") -- DEBUG
            return
        end

        -- Get config values from TUNING
        local health_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HEALTH_MULT
        local sanity_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SANITY_MULT
        local hunger_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HUNGER_MULT
        local crop_growth_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.CROP_GROWTH_MULT
        local speedup_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SPEEDUP_MULTIPLIER

        print(string.format("[SleepingAdvancesTime] Speedup: %dx, Multipliers: Health=%.2f, Sanity=%.2f, Hunger=%.2f, CropGrowth=%.2f",
            speedup_mult, health_mult, sanity_mult, hunger_mult, crop_growth_mult)) -- DEBUG

        local starting_phase = GLOBAL.TheWorld.state.phase
        local is_siesta = (starting_phase == "day") -- Track if this is a daytime siesta
        local target_phase = is_siesta and "dusk" or "day" -- Siesta wakes at dusk, regular sleep wakes at day
        local original_timescale = GLOBAL.TheSim:GetTimeScale()

        -- Set the time scale to speed up time
        GLOBAL.TheSim:SetTimeScale(speedup_mult)
        print("[SleepingAdvancesTime] Time scale set to " .. speedup_mult) -- DEBUG

        -- Override the hunger_tick to reduce hunger drain during speedup
        local original_hunger_tick = inst.components.sleepingbag.hunger_tick
        if original_hunger_tick then
            inst.components.sleepingbag.hunger_tick = original_hunger_tick / speedup_mult
            print("[SleepingAdvancesTime] Adjusted hunger_tick from " .. tostring(original_hunger_tick) .. " to " .. tostring(inst.components.sleepingbag.hunger_tick)) -- DEBUG
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

            print("[SleepingAdvancesTime] Cleaning up speedup mode") -- DEBUG

            -- Restore time scale
            GLOBAL.TheSim:SetTimeScale(original_timescale)
            print("[SleepingAdvancesTime] Time scale restored to " .. original_timescale) -- DEBUG

            -- Restore original hunger_tick
            if original_hunger_tick then
                inst.components.sleepingbag.hunger_tick = original_hunger_tick
                print("[SleepingAdvancesTime] Restored hunger_tick to " .. tostring(original_hunger_tick)) -- DEBUG
            end

            -- Restore original onwake callback
            inst.components.sleepingbag.onwake = original_onwake

            -- Apply crop growth for total elapsed time
            local effectiveCropGrowthDuration = sleep_data.total_elapsed * crop_growth_mult
            if effectiveCropGrowthDuration > 0 and sleeper and sleeper:IsValid() then
                print("[SleepingAdvancesTime] Total sleep time: " .. tostring(sleep_data.total_elapsed) .. ", Effective crop growth: " .. tostring(effectiveCropGrowthDuration)) -- DEBUG
                local sx, sy, sz = sleeper.Transform:GetWorldPosition()
                local search_radius = 100
                local plants_found = GLOBAL.TheSim:FindEntities(sx, sy, sz, search_radius, {"plant"})

                if plants_found and #plants_found > 0 then
                    for i, ent in ipairs(plants_found) do
                        if ent and ent.components.growable and ent.prefab and string.sub(ent.prefab, 1, 11) == "farm_plant_" then
                            print("[SleepingAdvancesTime] Processing plant: " .. ent.prefab) -- DEBUG
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
                print("[SleepingAdvancesTime] Sleeper woke up or is invalid, stopping speedup") -- DEBUG
                sleep_data.active = false
                return
            end

            -- Calculate elapsed time since last update
            local current_time = GLOBAL.GetTime()
            local delta_time = (current_time - sleep_data.last_update_time)
            sleep_data.last_update_time = current_time
            sleep_data.total_elapsed = sleep_data.total_elapsed + delta_time

            -- Check if phase has changed to target (day for regular sleep, dusk for siesta)
            if GLOBAL.TheWorld.state.phase == target_phase then
                print("[SleepingAdvancesTime] Phase changed to " .. target_phase .. ", waking up sleeper") -- DEBUG
                sleep_data.active = false
            end

            -- Check if player is out of hunger
            if sleeper.components.hunger and sleeper.components.hunger.current <= 0 then
                print("[SleepingAdvancesTime] Sleeper out of hunger, waking up") -- DEBUG
                sleep_data.active = false
            end

            -- If we should stop, clean up and wake the player
            if not sleep_data.active then
                CleanupSpeedup()

                -- Note: We don't call finiteuses:Use() here because the vanilla onwake
                -- callback handles durability consumption when GoToState("wakeup") triggers

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

    local periodic_task = nil

    -- Check if sleepingbag component has been added and apply our logic
    local function CheckAndApplySleepLogic(inst)
        if inst.components.sleepingbag ~= nil then
            if inst.components.sleepingbag.onsleep ~= SleepingAdvancesTime then
                print("[SleepingAdvancesTime] Applying sleep logic to spider den") -- DEBUG
                inst.components.sleepingbag.onsleep = SleepingAdvancesTime
            end
            -- Cancel the periodic task once we've applied the logic
            if periodic_task ~= nil then
                periodic_task:Cancel()
                periodic_task = nil
            end
        end
    end

    -- Initial check after a delay
    Prefab:DoTaskInTime(0, CheckAndApplySleepLogic)

    -- Periodic check in case den grows to tier 3 later (cancelled once sleepingbag is found)
    periodic_task = Prefab:DoPeriodicTask(5, function()
        CheckAndApplySleepLogic(Prefab)
    end)

    -- Clean up the periodic task if the spider den is removed
    Prefab:ListenForEvent("onremove", function()
        if periodic_task ~= nil then
            periodic_task:Cancel()
            periodic_task = nil
        end
    end)
end

AddPrefabPostInit("tent", ApplySleepLogic)
AddPrefabPostInit("portabletent", ApplySleepLogic)
AddPrefabPostInit("siestahut", ApplySleepLogic)
AddPrefabPostInit("bedroll_straw", ApplySleepLogic)
AddPrefabPostInit("bedroll_furry", ApplySleepLogic)

-- Spider dens for Webber (all 3 tiers, sleeping bag is only added at tier 3)
AddPrefabPostInit("spiderden", ApplySleepLogicDelayed)
AddPrefabPostInit("spiderden_2", ApplySleepLogicDelayed)
AddPrefabPostInit("spiderden_3", ApplySleepLogicDelayed)