outputDebugString("Loaded client.lua")

if localPlayer.vehicle then

    -- precalculate the relative positions
    local relativePositions = {}
    local maxDistance = 5
    for i = 0, 360, 1 do
        --for j = -10, 10, 10 do
            j=0
            local x = math.cos(math.rad(i)) * maxDistance
            local y = math.sin(math.rad(i)) * maxDistance
            table.insert(relativePositions, Vector3(x, y, j))
        --end
    end

    -- create peds
    local peds = {}
    for k, relativePos in pairs(relativePositions) do
        local ped = createPed(0, 0, 0, 0, 0, false)
        setPedAimTarget(ped, 10, 10, 3)
        setPedControlState(ped, "aim_weapon", true)
        setElementAlpha(ped, 0)
        setElementCollisionsEnabled(ped, false)
        setElementFrozen(ped, true)

        -- attach the ped to the vehicle
        attachElements(ped, localPlayer.vehicle, relativePos)

        table.insert(peds, ped)
    end

    addEventHandler("onClientRender", root, function()
        for i, ped in ipairs(peds) do
            local relativePos = relativePositions[i]
            local absPos = localPlayer.vehicle.matrix:transformPosition(relativePos*10)
            setPedAimTarget(ped, absPos)

            if getPedTargetStart(ped) then
                local startX, startY, startZ = getPedTargetStart(ped)
                if getPedTargetEnd(ped) then
                    local endX, endY, endZ = getPedTargetEnd(ped)
                    dxDrawLine3D(startX, startY, startZ, endX, endY, endZ, tocolor(255, 0, 0, 255), 5)
                end
                if getPedTargetCollision(ped) then
                    local endX, endY, endZ = getPedTargetCollision(ped)
                    dxDrawLine3D(startX, startY, startZ, endX, endY, endZ, tocolor(0, 255, 0, 255), 5)
                end
            end
        end
    end)
end

