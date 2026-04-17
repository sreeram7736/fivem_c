local WorldLock = Cine.WorldLock or {}
Cine.WorldLock = WorldLock

local function applyWorldLock(worldLock)
    local time = worldLock.time or {}
    NetworkOverrideClockTime(Cine.Util.num(time.h, 12), Cine.Util.num(time.m, 0), 0)
    PauseClock(true)

    if worldLock.weather then
        SetWeatherTypeNow(worldLock.weather)
        SetWeatherTypeNowPersist(worldLock.weather)
        SetWeatherTypePersist(worldLock.weather)
    end

    if worldLock.blackout ~= nil then
        SetArtificialLightsState(worldLock.blackout == true)
        SetArtificialLightsStateAffectsVehicles(worldLock.blackout == true)
    end

    local ambientDensity = Cine.Util.clamp(Cine.Util.num(worldLock.ambientDensity, 0.0), 0.0, 1.0)
    SetVehicleDensityMultiplierThisFrame(ambientDensity)
    SetRandomVehicleDensityMultiplierThisFrame(ambientDensity)
    SetParkedVehicleDensityMultiplierThisFrame(ambientDensity)
    SetPedDensityMultiplierThisFrame(ambientDensity)
    SetScenarioPedDensityMultiplierThisFrame(ambientDensity, ambientDensity)
    SetDispatchCopsForPlayer(PlayerId(), false)
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetPlayerWantedLevel(PlayerId(), 0, false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
end

local function resetWorldLock()
    PauseClock(false)
    ClearWeatherTypePersist()
    ClearOverrideWeather()
    SetArtificialLightsState(false)
    SetArtificialLightsStateAffectsVehicles(false)
end

CreateThread(function()
    local active = false

    while true do
        local setup = Cine.Client.state.setup
        local worldLock = setup and setup.worldLock

        if Cine.Client.state.stageId and worldLock then
            active = true
            applyWorldLock(worldLock)
            Wait(0)
        else
            if active then
                active = false
                resetWorldLock()
            end

            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    resetWorldLock()
end)
