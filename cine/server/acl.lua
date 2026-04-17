local ACL = Cine.ACL or {}
Cine.ACL = ACL

local function hasPermission(src, ace, oxRole)
    if not src or src == 0 then
        return true
    end

    if IsPlayerAceAllowed(src, ace) then
        return true
    end

    if GetResourceState('ox_core') == 'started' then
        local player = exports.ox_core:GetPlayer(src)
        if player and (player.hasRole and player:hasRole(oxRole) or player.hasGroup and player:hasGroup('admin')) then
            return true
        end
    end

    return false
end

function ACL.canUse(src)
    return hasPermission(src, 'cine.use', 'cine_use') or hasPermission(src, 'cine.manage', 'cine_manage')
end

function ACL.canManage(src)
    return hasPermission(src, 'cine.manage', 'cine_manage')
end

function ACL.requireUse(src)
    if ACL.canUse(src) then
        return true
    end

    return false, 'Missing permission: cine.use'
end

function ACL.requireManage(src)
    if ACL.canManage(src) then
        return true
    end

    return false, 'Missing permission: cine.manage'
end
