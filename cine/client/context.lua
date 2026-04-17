local Client = Cine.Client or {}
Cine.Client = Client

Client.state = Client.state or {
    stageId = nil,
    stage = nil,
    setupId = nil,
    setup = nil,
    setupManifest = nil,
    entityMap = {},
    playback = {
        active = false,
        payload = nil
    }
}

function Client.getAuthoritativeStageId()
    return LocalPlayer.state['cine:stageId']
end

function Client.acceptStageEvent(stageId)
    local liveStageId = Client.getAuthoritativeStageId()
    if liveStageId ~= nil then
        return liveStageId == stageId
    end

    return Client.state.stageId == nil or Client.state.stageId == stageId
end

function Client.resetStageState()
    Client.state.stage = nil
    Client.state.setupId = nil
    Client.state.setup = nil
    Client.state.setupManifest = nil
    Client.state.entityMap = {}
    Client.state.playback = {
        active = false,
        payload = nil
    }

    if Cine.Timeline then
        Cine.Timeline.stop()
    end

    if Cine.Camera then
        Cine.Camera.stopPlaybackCamera()
    end
end

function Client.resolveEntity(targetId)
    local netId = Client.state.entityMap[targetId]
    if not netId then
        return 0
    end

    if not NetworkDoesNetworkIdExist(netId) then
        return 0
    end

    return NetToEnt(netId)
end

RegisterNetEvent('cine:cl:stageState', function(snapshot)
    if type(snapshot) ~= 'table' then
        return
    end

    if not Client.acceptStageEvent(snapshot.stageId) then
        return
    end

    Client.state.stage = snapshot
end)

RegisterNetEvent('cine:cl:setupLoaded', function(stageId, setupId, setupDoc, manifest)
    if not Client.acceptStageEvent(stageId) then
        return
    end

    Client.state.setupId = setupId
    Client.state.setup = setupDoc
    Client.state.setupManifest = manifest or Cine.Util.extractManifest(setupDoc)
end)

RegisterNetEvent('cine:cl:setupCleared', function(stageId)
    if not Client.acceptStageEvent(stageId) then
        return
    end

    Client.state.setupId = nil
    Client.state.setup = nil
    Client.state.setupManifest = nil
    Client.state.entityMap = {}
    Client.state.playback = {
        active = false,
        payload = nil
    }

    if Cine.Timeline then
        Cine.Timeline.stop()
    end
end)

RegisterNetEvent('cine:cl:entityMap', function(stageId, entityMap)
    if not Client.acceptStageEvent(stageId) then
        return
    end

    Client.state.entityMap = type(entityMap) == 'table' and entityMap or {}
end)

CreateThread(function()
    local lastStageId = Client.getAuthoritativeStageId()
    Client.state.stageId = lastStageId

    while true do
        local currentStageId = Client.getAuthoritativeStageId()
        if currentStageId ~= lastStageId then
            lastStageId = currentStageId
            Client.state.stageId = currentStageId
            Client.resetStageState()
        end

        Wait(250)
    end
end)
