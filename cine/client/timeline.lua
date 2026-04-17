local Timeline = Cine.Timeline or {}
Cine.Timeline = Timeline

Timeline.plugins = Timeline.plugins or {}
Timeline.runtime = Timeline.runtime or {
    active = false,
    stageId = nil,
    payload = nil,
    localStartAtMs = 0,
    trackStates = {}
}

local function isLocalController()
    local stage = Cine.Client.state.stage
    if not stage or not stage.owner then
        return false
    end

    return stage.owner == GetPlayerServerId(PlayerId())
end

local function requestControl(entity)
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)
    return NetworkHasControlOfEntity(entity)
end

local function buildContext()
    return {
        stage = Cine.Client.state.stage,
        setup = Cine.Client.state.setup,
        canControlNetworked = isLocalController(),
        resolveEntity = function(targetId)
            return Cine.Client.resolveEntity(targetId)
        end,
        requestControl = requestControl
    }
end

local function activeClipAtTime(clips, timeMs)
    for index, clip in ipairs(clips or {}) do
        local startMs = Cine.Util.num(clip.startMs, 0)
        local endMs = Cine.Util.num(clip.endMs, 0)
        if timeMs >= startMs and (endMs == 0 or timeMs <= endMs) then
            return index, clip
        end
    end

    return nil, nil
end

local function interpolateKeyframes(keyframes, timeMs)
    if #keyframes == 0 then
        return nil
    end

    if #keyframes == 1 or timeMs <= Cine.Util.num(keyframes[1].timeMs, 0) then
        return keyframes[1]
    end

    for index = 1, #keyframes - 1 do
        local current = keyframes[index]
        local nextFrame = keyframes[index + 1]
        local currentTime = Cine.Util.num(current.timeMs, 0)
        local nextTime = Cine.Util.num(nextFrame.timeMs, currentTime)

        if timeMs <= nextTime then
            local duration = math.max(1, nextTime - currentTime)
            local alpha = Cine.Util.clamp((timeMs - currentTime) / duration, 0.0, 1.0)

            return {
                pos = {
                    x = Cine.Util.interpolate(Cine.Util.num(current.pos and current.pos.x, 0.0), Cine.Util.num(nextFrame.pos and nextFrame.pos.x, 0.0), alpha),
                    y = Cine.Util.interpolate(Cine.Util.num(current.pos and current.pos.y, 0.0), Cine.Util.num(nextFrame.pos and nextFrame.pos.y, 0.0), alpha),
                    z = Cine.Util.interpolate(Cine.Util.num(current.pos and current.pos.z, 0.0), Cine.Util.num(nextFrame.pos and nextFrame.pos.z, 0.0), alpha)
                },
                rot = {
                    x = Cine.Util.interpolate(Cine.Util.num(current.rot and current.rot.x, 0.0), Cine.Util.num(nextFrame.rot and nextFrame.rot.x, 0.0), alpha),
                    y = Cine.Util.interpolate(Cine.Util.num(current.rot and current.rot.y, 0.0), Cine.Util.num(nextFrame.rot and nextFrame.rot.y, 0.0), alpha),
                    z = Cine.Util.interpolate(Cine.Util.num(current.rot and current.rot.z, 0.0), Cine.Util.num(nextFrame.rot and nextFrame.rot.z, 0.0), alpha)
                },
                fov = Cine.Util.interpolate(Cine.Util.num(current.fov, 50.0), Cine.Util.num(nextFrame.fov, 50.0), alpha)
            }
        end
    end

    return keyframes[#keyframes]
end

function Timeline.registerTrack(trackType, plugin)
    Timeline.plugins[trackType] = plugin
end

function Timeline.stop()
    if not Timeline.runtime.active then
        Cine.Camera.stopPlaybackCamera()
        return
    end

    for index, trackState in pairs(Timeline.runtime.trackStates) do
        local track = Timeline.runtime.payload.tracks[index]
        local plugin = track and Timeline.plugins[track.type]
        if plugin and plugin.stop then
            plugin.stop(track, trackState, buildContext())
        end
    end

    Timeline.runtime = {
        active = false,
        stageId = nil,
        payload = nil,
        localStartAtMs = 0,
        trackStates = {}
    }

    Cine.Camera.stopPlaybackCamera()
end

function Timeline.start(stageId, playbackPayload)
    local setup = Cine.Client.state.setup
    if not setup or not setup.timeline then
        return
    end

    Timeline.stop()

    local serverSentAtMs = Cine.Util.num(playbackPayload.serverSentAtMs, 0)
    local startAtMs = Cine.Util.num(playbackPayload.startAtMs, serverSentAtMs)
    local localDelay = math.max(0, startAtMs - serverSentAtMs)

    Timeline.runtime = {
        active = true,
        stageId = stageId,
        payload = {
            tracks = setup.timeline.tracks or {},
            lengthMs = Cine.Util.num(playbackPayload.lengthMs, 0),
            loop = playbackPayload.loop == true,
            startOffsetMs = Cine.Util.num(playbackPayload.startOffsetMs, 0)
        },
        localStartAtMs = GetGameTimer() + localDelay,
        trackStates = {}
    }

    Cine.Client.state.playback = {
        active = true,
        payload = playbackPayload
    }
end

Timeline.registerTrack('camera_keyframes', {
    evaluate = function(track, state, context, timeMs)
        local sample = interpolateKeyframes(track.keyframes or {}, timeMs)
        if sample then
            Cine.Camera.applyPlaybackSample(sample)
        else
            Cine.Camera.stopPlaybackCamera()
        end
    end,
    stop = function()
        Cine.Camera.stopPlaybackCamera()
    end
})

Timeline.registerTrack('ped_anim', {
    evaluate = function(track, state, context, timeMs)
        if not context.canControlNetworked then
            return
        end

        local entity = context.resolveEntity(track.target)
        if entity == 0 or not DoesEntityExist(entity) or not IsEntityAPed(entity) then
            return
        end

        local clipIndex, clip = activeClipAtTime(track.clips or {}, timeMs)
        if not clip then
            if state.activeClip then
                if context.requestControl(entity) then
                    ClearPedTasks(entity)
                end

                state.activeClip = nil
            end

            return
        end

        if state.activeClip == clipIndex and state.entity == entity then
            return
        end

        if not context.requestControl(entity) then
            return
        end

        RequestAnimDict(clip.dict)
        if not HasAnimDictLoaded(clip.dict) then
            return
        end

        TaskPlayAnim(
            entity,
            clip.dict,
            clip.name,
            Cine.Util.num(clip.blendInSpeed, 8.0),
            Cine.Util.num(clip.blendOutSpeed, -8.0),
            -1,
            Cine.Util.num(clip.flag, 1),
            Cine.Util.num(clip.playbackRate, 1.0),
            false,
            false,
            false
        )

        state.activeClip = clipIndex
        state.entity = entity
    end,
    stop = function(track, state, context)
        if not context.canControlNetworked or not state.entity or not DoesEntityExist(state.entity) then
            return
        end

        if context.requestControl(state.entity) then
            ClearPedTasks(state.entity)
        end
    end
})

Timeline.registerTrack('prop_attach', {
    evaluate = function(track, state, context, timeMs)
        if not context.canControlNetworked then
            return
        end

        local startMs = Cine.Util.num(track.startMs, 0)
        local endMs = Cine.Util.num(track.endMs, 0)
        local inWindow = timeMs >= startMs and (endMs == 0 or timeMs <= endMs)
        local target = context.resolveEntity(track.target)
        local prop = context.resolveEntity(track.prop)

        if target == 0 or prop == 0 or not DoesEntityExist(target) or not DoesEntityExist(prop) then
            return
        end

        if not inWindow then
            if state.attached and context.requestControl(prop) then
                DetachEntity(prop, true, true)
                state.attached = false
            end

            return
        end

        if state.attached then
            return
        end

        if not context.requestControl(prop) then
            return
        end

        local ox, oy, oz = Cine.Util.vectorParts(track.offsetPos)
        local rx, ry, rz = Cine.Util.rotationParts(track.offsetRot)
        AttachEntityToEntity(
            prop,
            target,
            Cine.Util.num(track.bone, 0),
            ox,
            oy,
            oz,
            rx,
            ry,
            rz,
            false,
            false,
            track.collision == true,
            false,
            2,
            true
        )

        state.attached = true
    end,
    stop = function(track, state, context)
        local prop = context.resolveEntity(track.prop)
        if prop ~= 0 and DoesEntityExist(prop) and context.requestControl(prop) then
            DetachEntity(prop, true, true)
        end
    end
})

RegisterNetEvent('cine:cl:playbackStart', function(stageId, payload)
    if not Cine.Client.acceptStageEvent(stageId) then
        return
    end

    Timeline.start(stageId, payload)
end)

RegisterNetEvent('cine:cl:playbackStop', function(stageId)
    if not Cine.Client.acceptStageEvent(stageId) then
        return
    end

    Cine.Client.state.playback = {
        active = false,
        payload = nil
    }

    Timeline.stop()
end)

CreateThread(function()
    while true do
        if not Timeline.runtime.active then
            Wait(250)
        else
            local runtime = Timeline.runtime
            local elapsedMs = (GetGameTimer() - runtime.localStartAtMs) + runtime.payload.startOffsetMs

            if elapsedMs < 0 then
                Wait(0)
            else
                if runtime.payload.lengthMs > 0 then
                    if runtime.payload.loop then
                        elapsedMs = elapsedMs % runtime.payload.lengthMs
                    elseif elapsedMs > runtime.payload.lengthMs then
                        Timeline.stop()
                        Wait(0)
                        goto continue
                    end
                end

                local context = buildContext()

                for index, track in ipairs(runtime.payload.tracks) do
                    if track.enabled ~= false then
                        local plugin = Timeline.plugins[track.type]
                        if plugin and plugin.evaluate then
                            local state = runtime.trackStates[index] or {}
                            runtime.trackStates[index] = state
                            plugin.evaluate(track, state, context, elapsedMs)
                        end
                    end
                end

                Wait(0)
            end
        end

        ::continue::
    end
end)
