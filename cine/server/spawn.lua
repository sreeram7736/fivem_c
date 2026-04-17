local Spawn = Cine.Spawn or {}
Cine.Spawn = Spawn

local function registerEntity(stage, entityType, targetId, entity)
    if not entity or entity == 0 then
        return nil, ('Failed to create %s %s'):format(entityType, tostring(targetId or '?'))
    end

    SetEntityRoutingBucket(entity, stage.bucketId)

    local netId = NetworkGetNetworkIdFromEntity(entity)
    stage.entities[#stage.entities + 1] = {
        id = targetId,
        type = entityType,
        entity = entity,
        netId = netId
    }

    if targetId then
        stage.namedEntities[targetId] = netId
    end

    local state = Entity(entity).state
    if state then
        state:set('cine:stageId', stage.stageId, true)

        if targetId then
            state:set('cine:targetId', targetId, true)
        end
    end

    return entity
end

local function spawnProp(stage, entry)
    local modelHash = Cine.Util.modelHash(entry.model)
    if not modelHash then
        return nil, ('Invalid prop model for %s'):format(tostring(entry.id))
    end

    local x, y, z = Cine.Util.vectorParts(entry.pos)
    local entity = CreateObjectNoOffset(modelHash, x, y, z, true, true, false)
    if not entity or entity == 0 then
        return nil, ('CreateObjectNoOffset failed for %s'):format(tostring(entry.id))
    end

    local rx, ry, rz = Cine.Util.rotationParts(entry.rot)
    SetEntityRotation(entity, rx, ry, rz, 2, true)
    FreezeEntityPosition(entity, entry.freeze == true)

    return registerEntity(stage, 'prop', entry.id, entity)
end

local function spawnPed(stage, entry)
    local modelHash = Cine.Util.modelHash(entry.model)
    if not modelHash then
        return nil, ('Invalid ped model for %s'):format(tostring(entry.id))
    end

    local x, y, z = Cine.Util.vectorParts(entry.pos)
    local heading = Cine.Util.num(entry.heading, 0.0)
    local pedType = Cine.Util.num(entry.pedType, 4)
    local entity = CreatePed(pedType, modelHash, x, y, z, heading, true, true)
    if not entity or entity == 0 then
        return nil, ('CreatePed failed for %s'):format(tostring(entry.id))
    end

    SetEntityHeading(entity, heading)
    FreezeEntityPosition(entity, entry.freeze == true)
    SetBlockingOfNonTemporaryEvents(entity, true)

    if entry.invincible == true then
        SetEntityInvincible(entity, true)
    end

    local registeredEntity = registerEntity(stage, 'ped', entry.id, entity)

    if registeredEntity and entry.appearance then
        local state = Entity(registeredEntity).state
        if state then
            state:set('cine:appearance', entry.appearance, true)
        end
    end

    return registeredEntity
end

local function spawnVehicle(stage, entry)
    local modelHash = Cine.Util.modelHash(entry.model)
    if not modelHash then
        return nil, ('Invalid vehicle model for %s'):format(tostring(entry.id))
    end

    local x, y, z = Cine.Util.vectorParts(entry.pos)
    local heading = Cine.Util.num(entry.heading, 0.0)
    local entity = CreateVehicle(modelHash, x, y, z, heading, true, true)
    if not entity or entity == 0 then
        return nil, ('CreateVehicle failed for %s'):format(tostring(entry.id))
    end

    FreezeEntityPosition(entity, entry.freeze == true)

    if entry.engineOn ~= nil then
        SetVehicleEngineOn(entity, entry.engineOn == true, true, true)
    end

    return registerEntity(stage, 'vehicle', entry.id, entity)
end

function Spawn.clearStage(stage)
    for _, entry in ipairs(stage.entities) do
        if entry.entity and DoesEntityExist(entry.entity) then
            DeleteEntity(entry.entity)
        end
    end

    stage.entities = {}
    stage.namedEntities = {}
end

function Spawn.spawnStage(stage)
    if not stage.loadedSetupDoc then
        return nil, 'No setup is loaded on this stage'
    end

    Spawn.clearStage(stage)

    local spawns = stage.loadedSetupDoc.spawns or {}

    for _, entry in ipairs(spawns.props or {}) do
        local _, err = spawnProp(stage, entry)
        if err then
            print(('[cine] %s'):format(err))
        end
    end

    for _, entry in ipairs(spawns.peds or {}) do
        local _, err = spawnPed(stage, entry)
        if err then
            print(('[cine] %s'):format(err))
        end
    end

    for _, entry in ipairs(spawns.vehicles or {}) do
        local _, err = spawnVehicle(stage, entry)
        if err then
            print(('[cine] %s'):format(err))
        end
    end

    return stage.namedEntities
end
