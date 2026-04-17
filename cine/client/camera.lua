local Camera = Cine.Camera or {}
Cine.Camera = Camera

Camera.enabled = Camera.enabled ~= false
Camera.playbackCam = Camera.playbackCam or nil

function Camera.stopPlaybackCamera()
    if Camera.playbackCam and DoesCamExist(Camera.playbackCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(Camera.playbackCam, false)
    end

    Camera.playbackCam = nil
end

function Camera.setEnabled(enabled)
    Camera.enabled = enabled == true

    if not Camera.enabled then
        Camera.stopPlaybackCamera()
    end

    return Camera.enabled
end

function Camera.applyPlaybackSample(sample)
    if not Camera.enabled or type(sample) ~= 'table' then
        Camera.stopPlaybackCamera()
        return
    end

    if not Camera.playbackCam or not DoesCamExist(Camera.playbackCam) then
        Camera.playbackCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        RenderScriptCams(true, false, 0, true, true)
    end

    local x, y, z = Cine.Util.vectorParts(sample.pos)
    local rx, ry, rz = Cine.Util.rotationParts(sample.rot)

    SetCamCoord(Camera.playbackCam, x, y, z)
    SetCamRot(Camera.playbackCam, rx, ry, rz, 2)

    if sample.fov then
        SetCamFov(Camera.playbackCam, sample.fov)
    end
end

exports('SetCinematicCameraEnabled', function(enabled)
    return Camera.setEnabled(enabled)
end)

exports('IsCinematicCameraEnabled', function()
    return Camera.enabled
end)

RegisterCommand('cinecam', function()
    local enabled = Camera.setEnabled(not Camera.enabled)
    print(('[cine] Scripted camera %s'):format(enabled and 'enabled' or 'disabled'))
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Camera.stopPlaybackCamera()
end)
