setGameSpeed(2)
setFPSLimit(51)

Agent = {}

function getAgentPlayer()
    return getPlayerFromName("agent")
end

function findRotation3D(x1, y1, z1, x2, y2, z2)
    local rotx = math.atan2 (z2 - z1, getDistanceBetweenPoints2D (x2, y2, x1, y1))
    rotx = math.deg(rotx)
    local rotz = -math.deg(math.atan2(x2 - x1, y2 - y1))
    rotz = rotz < 0 and rotz + 360 or rotz
    return rotx, 0, rotz
end

function findRandomPath(minDistance, maxDistance)
    outputDebugString("findRandomPath")
    local path = nil
    repeat
        repeat
            local sx, sy, sz = math.random(-2700, -1600), math.random(0, 1300), 0
            repeat
                ex, ey, ez = sx + math.random(-500, 500), sy + math.random(-500, 500), 0
            until ex < 3000 and ex > -3000 and ey < 3000 and ey > -3000

            path = calculatePathByCoords(sx, sy, sz, ex, ey, ez)
            distance = 0
            if path then
                for i,node in ipairs(path) do
                    if i > 1 then
                        distance = distance + getDistanceBetweenPoints3D(path[i-1].x, path[i-1].y, path[i-1].z, node.x, node.y, node.z)
                    end
                end
            end
        until distance > minDistance and distance < maxDistance
        outputDebugString("distance: "..distance)

        startNode = path[1]
        endNode = path[#path]

        --outputDebugString("startNode: "..startNode.x..", "..startNode.y..", "..startNode.z)
        --outputDebugString("endNode: "..endNode.x..", "..endNode.y..", "..endNode.z)
    until startNode.z > 0 and endNode.z > 0

    --local rotX, rotY, rotZ = findRotation3D(path[1].x, path[1].y, path[1].z, path[2].x, path[2].y, path[2].z)
    --return Vector3(startNode.x, startNode.y, startNode.z), Vector3(endNode.x, endNode.y, endNode.z), Vector3(rotX, rotY, rotZ)
    return path
end

function Agent:constructor(i, path)
    local start = Vector3(path[1].x, path[1].y, path[2].z) + Vector3(0, 0, 1)
    local next = Vector3(path[2].x, path[2].y, path[2].z) + Vector3(0, 0, 1)
    local destination = Vector3(path[#path].x, path[#path].y, path[#path].z) + Vector3(0, 0, 1)
    local rotX, rotY, rotZ = findRotation3D(path[1].x, path[1].y, path[1].z, path[2].x, path[2].y, path[2].z)
    local rotation = Vector3(rotX, rotY, rotZ)
    table.remove(path, 1)
    --outputDebugString("Agent:constructor("..i..")")
    spawnPlayer(getAgentPlayer(), start.x, start.y, start.z + 5)
    fadeCamera(getAgentPlayer(), true)
    setCameraTarget(getAgentPlayer(), getAgentPlayer())

    self.id = i
    self.ped = createPed(250, start)
    self.vehicle = createVehicle(411, start, rotation)
    self.blipStart = createBlip(start, 0, 2, 255, 0, 0, 255, 0, 99999.0)
    self.blipEnd = createBlip(destination, 0, 2, 0, 255, 0, 255, 0, 99999.0)
    self.blipVehicle = createBlipAttachedTo(self.vehicle, 0, 2, 255, 255, 255, 255, 0, 99999.0)
    setVehiclePlateText(self.vehicle, "AGENT "..self.id)
    --setElementFrozen(self.vehicle, true)
    --setElementAlpha(self.vehicle, 0)
    --setElementAlpha(self.ped, 0)
    --setElementCollisionsEnabled(self.vehicle, false)
    for i=0,3 do
        setVehicleLightState(self.vehicle, i, 1)
    end
    warpPedIntoVehicle(self.ped, self.vehicle, 0)
    --warpPedIntoVehicle(client, self.vehicle, 1)
    setElementCollisionsEnabled(getAgentPlayer(), false)
    warpPedIntoVehicle(getAgentPlayer(), self.vehicle, 1)
    triggerClientEvent(getAgentPlayer(), "onClientAgentCreated", resourceRoot, self.id, self.ped, self.vehicle, destination.x, destination.y, destination.z, path)
end

function Agent:destructor()
    destroyElement(self.ped)
    destroyElement(self.vehicle)
    destroyElement(self.blipStart)
    destroyElement(self.blipEnd)
    destroyElement(self.blipVehicle)
    triggerClientEvent(getAgentPlayer(), "onClientAgentDestroyed", resourceRoot, self.id)
end

local agents = {}
local stopped = true
local resetting = false
local lastAgentId = nil
function resetEnvironment(args)
    outputDebugString("resetEnvironment("..tostring(args['agent_id'])..")")
    if resetting then return end

    resetting = true
    stopEnvironment()
    if lastAgentId == nil then
        startEnvironment(tonumber(args['agent_id']))
    end
    lastAgentId = tonumber(args['agent_id']) or 1
end

function startEnvironment(agent_id)
    outputDebugString("startEnvironment")
    math.randomseed(48)
    resetting = false
    agent_id = tonumber(agent_id) or 1
    --local path = findRandomPath(10, 200)
    local path = calculatePathByCoords(-1536.50354, 508.85898, 7.17969,  -2616.15674, 1390.70276, 7.11378)
    local agent = new(Agent, agent_id, path)
    agents[agent_id] = agent
end

function stopEnvironment()
    outputDebugString("stopEnvironment")
    for i,agent in pairs(agents) do
        delete(agent)
    end
end

addEvent("onServerAgentDestroyed", true)
addEventHandler("onServerAgentDestroyed", resourceRoot, function(id)
    outputDebugString("onServerAgentDestroyed("..id..")")
    outputDebugString("resetting: "..tostring(resetting))
    if resetting then
        startEnvironment(lastAgentId)
    end
end)

addCommandHandler("rl_reset", function(player, commandName, agent_id)
    outputDebugString("rl_reset("..tostring(agent_id)..")")
    resetting = false
    resetEnvironment({agent_id=tonumber(agent_id)})
end)

addEventHandler("onPlayerQuit", root, function()
    if source == getAgentPlayer() then
        stopEnvironment()
    end
end)
addEventHandler("onPlayerJoin", root, function()
    if source == getAgentPlayer() and lastAgentId then
        startEnvironment(lastAgentId)
    end
end)

debug.sethook(nil)
