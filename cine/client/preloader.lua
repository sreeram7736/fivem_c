local Preloader = Cine.Preloader or {}
Cine.Preloader = Preloader

local function requestModels(models, missing)
    for _, model in ipairs(models or {}) do
        local hash = Cine.Util.modelHash(model)
        if hash and IsModelValid(hash) then
            RequestModel(hash)
        else
            missing[#missing + 1] = ('model:%s'):format(tostring(model))
        end
    end
end

local function requestAnimDicts(animDicts, missing)
    for _, dict in ipairs(animDicts or {}) do
        if type(dict) == 'string' and dict ~= '' then
            RequestAnimDict(dict)
        else
            missing[#missing + 1] = ('anim:%s'):format(tostring(dict))
        end
    end
end

local function requestPtfxAssets(ptfxAssets, missing)
    for _, asset in ipairs(ptfxAssets or {}) do
        if type(asset) == 'string' and asset ~= '' then
            RequestNamedPtfxAsset(asset)
        else
            missing[#missing + 1] = ('ptfx:%s'):format(tostring(asset))
        end
    end
end

function Preloader.preloadManifest(manifest, timeoutMs)
    manifest = type(manifest) == 'table' and manifest or {}
    timeoutMs = timeoutMs or 15000

    local missing = {}
    requestModels(manifest.models, missing)
    requestAnimDicts(manifest.animDicts, missing)
    requestPtfxAssets(manifest.ptfxAssets, missing)

    local deadline = GetGameTimer() + timeoutMs

    while GetGameTimer() < deadline do
        local ready = true

        for _, model in ipairs(manifest.models or {}) do
            local hash = Cine.Util.modelHash(model)
            if hash and IsModelValid(hash) and not HasModelLoaded(hash) then
                ready = false
                break
            end
        end

        if ready then
            for _, dict in ipairs(manifest.animDicts or {}) do
                if type(dict) == 'string' and dict ~= '' and not HasAnimDictLoaded(dict) then
                    ready = false
                    break
                end
            end
        end

        if ready then
            for _, asset in ipairs(manifest.ptfxAssets or {}) do
                if type(asset) == 'string' and asset ~= '' and not HasNamedPtfxAssetLoaded(asset) then
                    ready = false
                    break
                end
            end
        end

        if ready then
            return #missing == 0, missing
        end

        Wait(0)
    end

    for _, model in ipairs(manifest.models or {}) do
        local hash = Cine.Util.modelHash(model)
        if hash and IsModelValid(hash) and not HasModelLoaded(hash) then
            missing[#missing + 1] = ('model:%s'):format(tostring(model))
        end
    end

    for _, dict in ipairs(manifest.animDicts or {}) do
        if type(dict) == 'string' and dict ~= '' and not HasAnimDictLoaded(dict) then
            missing[#missing + 1] = ('anim:%s'):format(dict)
        end
    end

    for _, asset in ipairs(manifest.ptfxAssets or {}) do
        if type(asset) == 'string' and asset ~= '' and not HasNamedPtfxAssetLoaded(asset) then
            missing[#missing + 1] = ('ptfx:%s'):format(asset)
        end
    end

    return false, missing
end

RegisterNetEvent('cine:cl:preloadRequest', function(stageId, token, manifest)
    if not Cine.Client.acceptStageEvent(stageId) then
        return
    end

    CreateThread(function()
        local ready, missing = Preloader.preloadManifest(manifest)
        TriggerServerEvent('cine:sv:preloadReady', stageId, token, ready, missing)
    end)
end)
