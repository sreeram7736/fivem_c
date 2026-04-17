local function sendRequestResult(src, requestId, ok, payload)
    if src > 0 and requestId ~= nil then
        TriggerClientEvent('cine:cl:requestResult', src, requestId, ok, payload)
    end
end

local function fail(src, requestId, message)
    sendRequestResult(src, requestId, false, {
        message = message
    })

    return nil, message
end

local function succeed(src, requestId, payload)
    sendRequestResult(src, requestId, true, payload)
    return payload
end

local function requireUse(src, requestId)
    local ok, err = Cine.ACL.requireUse(src)
    if ok then
        return true
    end

    return fail(src, requestId, err)
end

local function requireManage(src, requestId)
    local ok, err = Cine.ACL.requireManage(src)
    if ok then
        return true
    end

    return fail(src, requestId, err)
end

local function requireStage(src, requestId, stageId)
    local stage = Cine.StageManager.get(stageId)
    if stage then
        return stage
    end

    return fail(src, requestId, ('Unknown stage: %s'):format(tostring(stageId)))
end

local function requireControl(src, requestId, stage)
    local ok, err = Cine.StageManager.claimControl(stage, src)
    if ok then
        return true
    end

    return fail(src, requestId, err)
end

local loadSetupFor

local function createStageFor(src, requestId, setupId)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = Cine.StageManager.create(src)

    if src > 0 then
        local joined, joinErr = Cine.StageManager.join(src, stage.stageId)
        if not joined then
            return fail(src, requestId, joinErr)
        end
    end

    if setupId then
        local _, loadErr = loadSetupFor(src, nil, stage.stageId, setupId)
        if loadErr then
            return fail(src, requestId, loadErr)
        end
    end

    return succeed(src, requestId, {
        stageId = stage.stageId,
        bucketId = stage.bucketId
    })
end

loadSetupFor = function(src, requestId, stageId, setupId)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = requireStage(src, requestId, stageId)
    if not stage then
        return nil
    end

    if not requireControl(src, requestId, stage) then
        return nil
    end

    local setupDoc, loadErr = Cine.Repository.loadSetup(setupId)
    if not setupDoc then
        return fail(src, requestId, loadErr)
    end

    Cine.Playback.stop(stage)
    Cine.StageManager.setLoadedSetup(stage, setupId, setupDoc)
    Cine.StageManager.broadcastStageState(stage)
    Cine.StageManager.broadcastSetup(stage)
    Cine.Playback.requestPreload(stage)

    return succeed(src, requestId, {
        stageId = stage.stageId,
        setupId = stage.loadedSetupId,
        setupVersion = setupDoc.meta.version
    })
end

local function joinStageFor(src, requestId, stageId)
    if not requireUse(src, requestId) then
        return nil
    end

    local stage, err = Cine.StageManager.join(src, stageId)
    if not stage then
        return fail(src, requestId, err)
    end

    return succeed(src, requestId, {
        stageId = stage.stageId,
        bucketId = stage.bucketId
    })
end

local function leaveStageFor(src, requestId)
    if not requireUse(src, requestId) then
        return nil
    end

    local ok, result = Cine.StageManager.leave(src)
    if not ok then
        return fail(src, requestId, result)
    end

    return succeed(src, requestId, {
        leftStageId = result.stageId
    })
end

local function spawnFor(src, requestId, stageId)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = requireStage(src, requestId, stageId)
    if not stage then
        return nil
    end

    if not requireControl(src, requestId, stage) then
        return nil
    end

    Cine.Playback.stop(stage)

    local _, err = Cine.Spawn.spawnStage(stage)
    if err then
        return fail(src, requestId, err)
    end

    Cine.StageManager.broadcastEntityMap(stage)

    return succeed(src, requestId, {
        stageId = stage.stageId,
        entityMap = stage.namedEntities
    })
end

local function clearFor(src, requestId, stageId)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = requireStage(src, requestId, stageId)
    if not stage then
        return nil
    end

    if not requireControl(src, requestId, stage) then
        return nil
    end

    Cine.Playback.stop(stage)
    Cine.Spawn.clearStage(stage)
    Cine.StageManager.broadcastEntityMap(stage)

    return succeed(src, requestId, {
        stageId = stage.stageId
    })
end

local function playbackStartFor(src, requestId, stageId, opts)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = requireStage(src, requestId, stageId)
    if not stage then
        return nil
    end

    if not requireControl(src, requestId, stage) then
        return nil
    end

    local payload, err = Cine.Playback.start(stage, opts)
    if not payload then
        return fail(src, requestId, err)
    end

    return succeed(src, requestId, payload)
end

local function playbackStopFor(src, requestId, stageId)
    if not requireManage(src, requestId) then
        return nil
    end

    local stage = requireStage(src, requestId, stageId)
    if not stage then
        return nil
    end

    if not requireControl(src, requestId, stage) then
        return nil
    end

    Cine.Playback.stop(stage)

    return succeed(src, requestId, {
        stageId = stage.stageId
    })
end

exports('CreateStage', function(setupId, controllerSrc)
    local payload, err = createStageFor(controllerSrc or 0, nil, setupId)
    if not payload then
        return nil, err
    end

    return payload.stageId
end)

exports('JoinStage', function(playerSrc, stageId)
    local payload, err = joinStageFor(playerSrc, nil, stageId)
    if not payload then
        return nil, err
    end

    return true
end)

exports('LeaveStage', function(playerSrc)
    local payload, err = leaveStageFor(playerSrc, nil)
    if not payload then
        return nil, err
    end

    return true
end)

exports('LoadSetup', function(stageId, setupId, controllerSrc)
    local payload, err = loadSetupFor(controllerSrc or 0, nil, stageId, setupId)
    if not payload then
        return nil, err
    end

    return true
end)

exports('Spawn', function(stageId, controllerSrc)
    local payload, err = spawnFor(controllerSrc or 0, nil, stageId)
    if not payload then
        return nil, err
    end

    return payload.entityMap
end)

exports('Clear', function(stageId, controllerSrc)
    local payload, err = clearFor(controllerSrc or 0, nil, stageId)
    if not payload then
        return nil, err
    end

    return true
end)

exports('PlaybackStart', function(stageId, opts, controllerSrc)
    return playbackStartFor(controllerSrc or 0, nil, stageId, opts)
end)

exports('PlaybackStop', function(stageId, controllerSrc)
    local payload, err = playbackStopFor(controllerSrc or 0, nil, stageId)
    if not payload then
        return nil, err
    end

    return true
end)

exports('SaveSetup', function(setupId, setupDoc)
    return Cine.Repository.saveSetup(setupId, setupDoc)
end)

RegisterNetEvent('cine:sv:createStage', function(requestId, setupId)
    createStageFor(source, requestId, setupId)
end)

RegisterNetEvent('cine:sv:joinStage', function(requestId, stageId)
    joinStageFor(source, requestId, stageId)
end)

RegisterNetEvent('cine:sv:leaveStage', function(requestId)
    leaveStageFor(source, requestId)
end)

RegisterNetEvent('cine:sv:loadSetup', function(requestId, stageId, setupId)
    loadSetupFor(source, requestId, stageId, setupId)
end)

RegisterNetEvent('cine:sv:spawn', function(requestId, stageId)
    spawnFor(source, requestId, stageId)
end)

RegisterNetEvent('cine:sv:clear', function(requestId, stageId)
    clearFor(source, requestId, stageId)
end)

RegisterNetEvent('cine:sv:playbackStart', function(requestId, stageId, opts)
    playbackStartFor(source, requestId, stageId, opts)
end)

RegisterNetEvent('cine:sv:playbackStop', function(requestId, stageId)
    playbackStopFor(source, requestId, stageId)
end)

AddEventHandler('playerDropped', function()
    Cine.StageManager.leave(source)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Cine.StageManager.cleanupAll()
end)
