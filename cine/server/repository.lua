local Repository = Cine.Repository or {}
Cine.Repository = Repository

local RESOURCE_NAME = GetCurrentResourceName()
local SETUP_ROOT = 'data/setups'

local function setupPath(setupId)
    return ('%s/%s.json'):format(SETUP_ROOT, setupId)
end

function Repository.loadSetup(setupId)
    if type(setupId) ~= 'string' or setupId == '' then
        return nil, 'setupId is required'
    end

    local raw = LoadResourceFile(RESOURCE_NAME, setupPath(setupId))
    if not raw then
        return nil, ('Setup not found: %s'):format(setupId)
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        return nil, ('Setup JSON is invalid: %s'):format(setupId)
    end

    return Cine.Util.normalizeSetup(decoded, setupId)
end

function Repository.saveSetup(setupId, setupDoc)
    if type(setupId) ~= 'string' or setupId == '' then
        return false, 'setupId is required'
    end

    if type(setupDoc) ~= 'table' then
        return false, 'setupDoc must be a table'
    end

    local normalized = Cine.Util.normalizeSetup(setupDoc, setupId)
    local encoded = json.encode(normalized)
    local saved = SaveResourceFile(RESOURCE_NAME, setupPath(setupId), encoded, -1)

    if not saved then
        return false, ('Failed to save setup: %s'):format(setupId)
    end

    return true, normalized
end
