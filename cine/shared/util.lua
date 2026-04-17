Cine = rawget(_G, 'Cine') or {}

local Util = Cine.Util or {}
Cine.Util = Util

local function pushUnique(list, seen, value)
    if value == nil then
        return
    end

    local key = tostring(value)
    if seen[key] then
        return
    end

    seen[key] = true
    list[#list + 1] = value
end

function Util.copy(value)
    if type(value) ~= 'table' then
        return value
    end

    local clone = {}
    for key, inner in pairs(value) do
        clone[key] = Util.copy(inner)
    end

    return clone
end

function Util.num(value, default)
    local parsed = tonumber(value)
    if parsed == nil then
        return default
    end

    return parsed
end

function Util.bool(value, default)
    if value == nil then
        return default
    end

    return value == true
end

function Util.vectorParts(data)
    data = data or {}

    return Util.num(data.x, 0.0), Util.num(data.y, 0.0), Util.num(data.z, 0.0)
end

function Util.rotationParts(data)
    return Util.vectorParts(data)
end

function Util.modelHash(model)
    if type(model) == 'number' then
        return model
    end

    if type(model) == 'string' then
        return joaat(model)
    end

    return nil
end

function Util.normalizeSetup(setup, setupId)
    local normalized = Util.copy(setup or {})

    normalized.meta = normalized.meta or {}
    normalized.meta.id = normalized.meta.id or setupId
    normalized.meta.name = normalized.meta.name or setupId
    normalized.meta.version = Util.num(normalized.meta.version, 1)

    normalized.worldLock = normalized.worldLock or {}

    normalized.spawns = normalized.spawns or {}
    normalized.spawns.props = normalized.spawns.props or {}
    normalized.spawns.peds = normalized.spawns.peds or {}
    normalized.spawns.vehicles = normalized.spawns.vehicles or {}

    normalized.timeline = normalized.timeline or {}
    normalized.timeline.fps = Util.num(normalized.timeline.fps, 30)
    normalized.timeline.lengthMs = Util.num(normalized.timeline.lengthMs, 0)
    normalized.timeline.tracks = normalized.timeline.tracks or {}

    return normalized
end

function Util.extractManifest(setup)
    local manifest = {
        models = {},
        animDicts = {},
        ptfxAssets = {}
    }

    local seen = {
        models = {},
        animDicts = {},
        ptfxAssets = {}
    }

    local spawns = (setup or {}).spawns or {}

    for _, entry in ipairs(spawns.props or {}) do
        pushUnique(manifest.models, seen.models, entry.model)
    end

    for _, entry in ipairs(spawns.peds or {}) do
        pushUnique(manifest.models, seen.models, entry.model)
    end

    for _, entry in ipairs(spawns.vehicles or {}) do
        pushUnique(manifest.models, seen.models, entry.model)
    end

    for _, track in ipairs((((setup or {}).timeline or {}).tracks) or {}) do
        if track.type == 'ped_anim' then
            for _, clip in ipairs(track.clips or {}) do
                pushUnique(manifest.animDicts, seen.animDicts, clip.dict)
            end
        elseif track.type == 'ptfx' then
            pushUnique(manifest.ptfxAssets, seen.ptfxAssets, track.asset)

            for _, cue in ipairs(track.cues or {}) do
                pushUnique(manifest.ptfxAssets, seen.ptfxAssets, cue.asset)
            end
        elseif track.type == 'prop_attach' then
            pushUnique(manifest.models, seen.models, track.model)
        end
    end

    return manifest
end

function Util.sortedKeys(source)
    local keys = {}

    for key in pairs(source or {}) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    return keys
end

function Util.interpolate(a, b, alpha)
    return a + ((b - a) * alpha)
end

function Util.clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end
