RegisterNetEvent('cine:cl:requestResult', function(requestId, ok, payload)
    if ok then
        return
    end

    if type(payload) == 'table' and payload.message then
        print(('[cine] request %s failed: %s'):format(tostring(requestId), payload.message))
    end
end)

RegisterNetEvent('cine:cl:notify', function(message)
    print(('[cine] %s'):format(tostring(message)))
end)

AddStateBagChangeHandler('cine:appearance', nil, function(bagName, key, value, _reserved, replicated)
    if not value then return end

    local netId = tonumber(bagName:gsub('entity:', ''), 10)
    if not netId then return end

    CreateThread(function()
        local entity = 0
        local deadline = GetGameTimer() + 5000
        
        while GetGameTimer() < deadline do
            if NetworkDoesNetworkIdExist(netId) then
                entity = NetToEnt(netId)
                if entity ~= 0 and DoesEntityExist(entity) then
                    break
                end
            end
            Wait(100)
        end

        if entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity) then
            if GetResourceState('illenium-appearance') == 'started' then
                exports['illenium-appearance']:setPedAppearance(entity, value)
            end
        end
    end)
end)
