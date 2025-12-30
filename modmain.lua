-- Initialize config values in TUNING
GLOBAL.TUNING.SLEEPING_ADVANCES_TIME = {
    HEALTH_MULT = GetModConfigData("HEALTH_MULT") or 1,
    SANITY_MULT = GetModConfigData("SANITY_MULT") or 1,
    HUNGER_MULT = GetModConfigData("HUNGER_MULT") or 1,
    CROP_GROWTH_MULT = GetModConfigData("CROP_GROWTH_MULT") or 1
}

local function SleepingAdvancesTime(inst, sleeper)
    print("[SleepingAdvancesTime] Function called for sleeper: " .. (sleeper and sleeper.prefab or "nil")) -- DEBUG
    if (not GLOBAL.TheWorld.ismastersim) then
        print("[SleepingAdvancesTime] Not master sim, returning.") -- DEBUG
        return
    end

    inst:DoTaskInTime(5, function()
        print("[SleepingAdvancesTime] DoTaskInTime callback started.") -- DEBUG

        -- Get config values from TUNING
        local health_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HEALTH_MULT
        local sanity_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.SANITY_MULT
        local hunger_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.HUNGER_MULT
        local crop_growth_mult = GLOBAL.TUNING.SLEEPING_ADVANCES_TIME.CROP_GROWTH_MULT
        
        print(string.format("[SleepingAdvancesTime] Multipliers: Health=%.2f, Sanity=%.2f, Hunger=%.2f, CropGrowth=%.2f", health_mult, sanity_mult, hunger_mult, crop_growth_mult)) -- DEBUG

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

        if sleeper.components.sanity then
            sleeper.components.sanity:DoDelta(Time * TUNING.SLEEP_SANITY_PER_TICK * sanity_mult)
        end
        if sleeper.components.hunger then
            -- Hunger drain: positive value for DoDelta means loss. TUNING.SLEEP_HUNGER_PER_TICK is negative.
            -- So, a higher multiplier means more hunger lost.
            sleeper.components.hunger:DoDelta(Time * TUNING.SLEEP_HUNGER_PER_TICK * hunger_mult, false, true)
        end
        if sleeper.components.health then
            sleeper.components.health:DoDelta(Time * TUNING.SLEEP_HEALTH_PER_TICK * 2 * health_mult, false, "tent", true)
        end
        if sleeper.components.temperature then
            local Temperature = (Time * TUNING.SLEEP_TEMP_PER_TICK)

            if ((sleeper.components.temperature:GetCurrent() + Temperature) > TUNING.SLEEP_TARGET_TEMP_TENT) then
                Temperature = TUNING.SLEEP_TARGET_TEMP_TENT
            end

            sleeper.components.temperature:SetTemperature(Temperature)
        end
        if sleeper.components.moisture then
            sleeper.components.moisture:DoDelta(Time * TUNING.SLEEP_WETNESS_PER_TICK)
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

        if (inst.components.finiteuses ~= nil) then
            inst.components.finiteuses:Use()
        end

        GLOBAL.TheWorld:PushEvent("ms_nextcycle")

        sleeper.sg:GoToState("wakeup")
    end)
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
            print("[SleepingAdvancesTime] Applying sleep logic to spider den") -- DEBUG
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