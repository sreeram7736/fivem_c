local StageManager = Cine.StageManager or {}
Cine.StageManager = StageManager

StageManager.stages = StageManager.stages or {}
StageManager.playerStage = StageManager.playerStage or {}
StageManager.nextStageId = StageManager.nextStageId or 1
StageManager.bucketBase = StageManager.bucketBase or 5000

local function setPlayerStageState(src, stageId)
    local player = Player(src)
    if not player or not player.state then
        return
    end

    player.state:set('cine:stageId', stageId, true)
end

local function copyNamedEntityMap(stage)
    local entityMap = {}

    for targetId, netId in pairs(stage.namedEntities or {}) do
        entityMap[targetId] = netId
    end

    return entityMap
end

function StageManager.get(stageId)
    return StageManager.stages[tonumber(stageId)]
end

function StageManager.getPlayerStage(src)
    return StageManager.get(StageManager.playerStage[src])
end

function StageManager.snapshot(stage)
    return {
        stageId = stage.stageId,
        bucketId = stage.bucketId,
        owner = stage.owner,
        setupId = stage.loadedSetupId,
        setupVersion = stage.loadedSetupDoc and stage.loadedSetupDoc.meta.version or nil,
        members = Cine.Util.sortedKeys(stage.members),
        playback = {
            active = stage.playback.active == true,
            payload = stage.playback.payload
        }
    }
end

function StageManager.broadcast(stage, eventName, ...)
    for src in pairs(stage.members) do
        TriggerClientEvent(eventName, src, ...)
    end
end

function StageManager.broadcastStageState(stage)
    StageManager.broadcast(stage, 'cine:cl:stageState', StageManager.snapshot(stage))
end

function StageManager.broadcastSetup(stage)
    if stage.loadedSetupDoc then
        StageManager.broadcast(stage, 'cine:cl:setupLoaded', stage.stageId, stage.loadedSetupId, stage.loadedSetupDoc, stage.setupManifest)
        return
    end

    StageManager.broadcast(stage, 'cine:cl:setupCleared', stage.stageId)
end

function StageManager.broadcastEntityMap(stage)
    StageManager.broadcast(stage, 'cine:cl:entityMap', stage.stageId, copyNamedEntityMap(stage))
end

function StageManager.syncPlayer(src, stage)
    TriggerClientEvent('cine:cl:stageState', src, StageManager.snapshot(stage))

    if stage.loadedSetupDoc then
        TriggerClientEvent('cine:cl:setupLoaded', src, stage.stageId, stage.loadedSetupId, stage.loadedSetupDoc, stage.setupManifest)
    else
        TriggerClientEvent('cine:cl:setupCleared', src, stage.stageId)
    end

    TriggerClientEvent('cine:cl:entityMap', src, stage.stageId, copyNamedEntityMap(stage))

    if stage.playback.active and stage.playback.payload then
        TriggerClientEvent('cine:cl:playbackStart', src, stage.stageId, stage.playback.payload)
    else
        TriggerClientEvent('cine:cl:playbackStop', src, stage.stageId)
    end
end

function StageManager.syncStage(stage)
    for src in pairs(stage.members) do
        StageManager.syncPlayer(src, stage)
    end
end

function StageManager.create(ownerSrc)
    local stageId = StageManager.nextStageId
    StageManager.nextStageId = stageId + 1

    local stage = {
        stageId = stageId,
        bucketId = StageManager.bucketBase + stageId,
        owner = ownerSrc and ownerSrc > 0 and ownerSrc or nil,
        members = {},
        entities = {},
        namedEntities = {},
        readiness = {},
        loadedSetupId = nil,
        loadedSetupDoc = nil,
        setupManifest = nil,
        playback = {
            active = false,
            payload = nil,
            sequence = 0
        },
        preloadSequence = 0
    }

    StageManager.stages[stageId] = stage

    SetRoutingBucketPopulationEnabled(stage.bucketId, false)
    SetRoutingBucketEntityLockdownMode(stage.bucketId, 'strict')

    return stage
end

function StageManager.claimControl(stage, src)
    if not src or src == 0 then
        return true
    end

    if stage.owner == nil then
        stage.owner = src
        StageManager.broadcastStageState(stage)
        return true
    end

    if stage.owner == src then
        return true
    end

    return false, ('Stage %d is currently controlled by %d'):format(stage.stageId, stage.owner)
end

function StageManager.join(src, stageId)
    local stage = StageManager.get(stageId)
    if not stage then
        return nil, ('Unknown stage: %s'):format(stageId)
    end

    local currentStage = StageManager.getPlayerStage(src)
    if currentStage and currentStage.stageId == stage.stageId then
        StageManager.syncPlayer(src, stage)
        return stage
    end

    if currentStage then
        StageManager.leave(src)
    end

    stage.members[src] = true
    stage.readiness[src] = stage.readiness[src] or {
        token = nil,
        ready = false,
        missing = {}
    }

    if not stage.owner then
        stage.owner = src
    end

    StageManager.playerStage[src] = stage.stageId
    SetPlayerRoutingBucket(src, stage.bucketId)
    setPlayerStageState(src, stage.stageId)

    CreateThread(function()
        Wait(50)

        if StageManager.playerStage[src] ~= stage.stageId then
            return
        end

        StageManager.syncPlayer(src, stage)
        StageManager.broadcastStageState(stage)
    end)

    return stage
end

function StageManager.leave(src)
    local stage = StageManager.getPlayerStage(src)
    local playerStillPresent = GetPlayerName(src) ~= nil

    if not stage then
        if playerStillPresent then
            setPlayerStageState(src, nil)
            SetPlayerRoutingBucket(src, 0)
        end

        return false, 'Player is not in a stage'
    end

    stage.members[src] = nil
    stage.readiness[src] = nil
    StageManager.playerStage[src] = nil

    if playerStillPresent then
        setPlayerStageState(src, nil)
        SetPlayerRoutingBucket(src, 0)
        TriggerClientEvent('cine:cl:playbackStop', src, stage.stageId)
        TriggerClientEvent('cine:cl:setupCleared', src, stage.stageId)
    end

    if stage.owner == src then
        local members = Cine.Util.sortedKeys(stage.members)
        stage.owner = members[1]
    end

    StageManager.broadcastStageState(stage)

    return true, stage
end

function StageManager.setLoadedSetup(stage, setupId, setupDoc)
    stage.loadedSetupId = setupId
    stage.loadedSetupDoc = setupDoc
    stage.setupManifest = Cine.Util.extractManifest(setupDoc)
    stage.readiness = {}

    for src in pairs(stage.members) do
        stage.readiness[src] = {
            token = nil,
            ready = false,
            missing = {}
        }
    end
end

function StageManager.clearLoadedSetup(stage)
    stage.loadedSetupId = nil
    stage.loadedSetupDoc = nil
    stage.setupManifest = nil
    stage.readiness = {}
end

function StageManager.cleanupAll()
    for src in pairs(StageManager.playerStage) do
        if GetPlayerName(src) ~= nil then
            setPlayerStageState(src, nil)
            SetPlayerRoutingBucket(src, 0)
        end
    end

    for _, stage in pairs(StageManager.stages) do
        if Cine.Spawn then
            Cine.Spawn.clearStage(stage)
        end
    end

    StageManager.stages = {}
    StageManager.playerStage = {}
end
