local Playback = Cine.Playback or {}
Cine.Playback = Playback

local function stageTargets(stage, memberList)
    if type(memberList) == 'table' and #memberList > 0 then
        return memberList
    end

    return Cine.Util.sortedKeys(stage.members)
end

local function allReady(stage, token, members)
    for _, src in ipairs(stageTargets(stage, members)) do
        local entry = stage.readiness[src]
        if not entry or entry.token ~= token or entry.ready ~= true then
            return false
        end
    end

    return true
end

local function collectUnready(stage, token, members)
    local unready = {}

    for _, src in ipairs(stageTargets(stage, members)) do
        local entry = stage.readiness[src]
        if not entry or entry.token ~= token or entry.ready ~= true then
            unready[#unready + 1] = src
        end
    end

    return unready
end

function Playback.requestPreload(stage, memberList)
    if not stage.loadedSetupDoc then
        return nil
    end

    local targets = stageTargets(stage, memberList)
    if #targets == 0 then
        return nil
    end

    stage.preloadSequence = stage.preloadSequence + 1

    local token = ('%d:%d'):format(stage.stageId, stage.preloadSequence)
    local manifest = stage.setupManifest or Cine.Util.extractManifest(stage.loadedSetupDoc)
    stage.setupManifest = manifest

    for _, src in ipairs(targets) do
        stage.readiness[src] = {
            token = token,
            ready = false,
            missing = {}
        }

        TriggerClientEvent('cine:cl:preloadRequest', src, stage.stageId, token, manifest)
    end

    return token
end

function Playback.markReady(src, stageId, token, ready, missing)
    local stage = Cine.StageManager.get(stageId)
    if not stage or not stage.members[src] then
        return
    end

    stage.readiness[src] = {
        token = token,
        ready = ready == true,
        missing = type(missing) == 'table' and missing or {}
    }
end

function Playback.waitForReady(stage, token, timeoutMs, memberList)
    if not token then
        return true, {}
    end

    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline do
        if allReady(stage, token, memberList) then
            return true, {}
        end

        Wait(50)
    end

    return false, collectUnready(stage, token, memberList)
end

function Playback.stop(stage, suppressBroadcast)
    if not stage.playback.active and not stage.playback.payload then
        return false
    end

    stage.playback.active = false
    stage.playback.payload = nil
    stage.playback.sequence = (stage.playback.sequence or 0) + 1

    if not suppressBroadcast then
        Cine.StageManager.broadcast(stage, 'cine:cl:playbackStop', stage.stageId)
        Cine.StageManager.broadcastStageState(stage)
    end

    return true
end

function Playback.start(stage, opts)
    if not stage.loadedSetupDoc then
        return nil, 'No setup is loaded on this stage'
    end

    opts = type(opts) == 'table' and opts or {}

    local requireReady = opts.requireReady ~= false
    local delayMs = math.max(0, Cine.Util.num(opts.delayMs, 1000))
    local readyTimeoutMs = math.max(0, Cine.Util.num(opts.readyTimeoutMs, 15000))
    local startOffsetMs = math.max(0, Cine.Util.num(opts.startOffsetMs, 0))
    local loop = opts.loop == true

    local unreadyMembers = {}

    if requireReady then
        local token = Playback.requestPreload(stage)
        local ready, timedOut = Playback.waitForReady(stage, token, readyTimeoutMs)

        if not ready then
            unreadyMembers = timedOut
            print(('[cine] Playback start timed out waiting for ready on stage %d'):format(stage.stageId))
        end
    end

    local serverNow = GetGameTimer()
    stage.playback.sequence = (stage.playback.sequence or 0) + 1

    local payload = {
        setupId = stage.loadedSetupId,
        setupVersion = stage.loadedSetupDoc.meta.version,
        startAtMs = serverNow + delayMs,
        serverSentAtMs = serverNow,
        startOffsetMs = startOffsetMs,
        loop = loop,
        lengthMs = Cine.Util.num(stage.loadedSetupDoc.timeline.lengthMs, 0),
        unreadyMembers = unreadyMembers
    }

    stage.playback.active = true
    stage.playback.payload = payload

    Cine.StageManager.broadcast(stage, 'cine:cl:playbackStart', stage.stageId, payload)
    Cine.StageManager.broadcastStageState(stage)

    if not loop and payload.lengthMs > 0 then
        local stageId = stage.stageId
        local sequence = stage.playback.sequence
        local autoStopAfter = delayMs + math.max(0, payload.lengthMs - startOffsetMs) + 50

        CreateThread(function()
            Wait(autoStopAfter)

            local currentStage = Cine.StageManager.get(stageId)
            if not currentStage then
                return
            end

            if currentStage.playback.active and currentStage.playback.sequence == sequence then
                Playback.stop(currentStage)
            end
        end)
    end

    return payload
end

RegisterNetEvent('cine:sv:preloadReady', function(stageId, token, ready, missing)
    Playback.markReady(source, stageId, token, ready, missing)
end)
