-- globals
local relativePositions = {}
local maxDistance = 100
local stepSize = 45/2
--for i = -45, 45*5, stepSize do
for i = 0, 360, 360/24 do
    local x = math.cos(math.rad(i)) * maxDistance
    local y = math.sin(math.rad(i)) * maxDistance
    table.insert(relativePositions, Vector3(x, y, 0))
end
outputDebugString("relativePositions: " .. #relativePositions-1)

local checkBuildings = true
local checkVehicles = false
local checkPlayers = false
local checkObjects = true
local checkDummies = false
local seeThroughStuff = false
local ignoreSomeObjectsForCamera = false
local shootThroughStuff = false
local includeWorldModelInformation = false
local bIncludeCarTyres = false
--------------------------------------------
-- reward settings
local hitColShapeReward = 10
--------------------------------------------

Agent = {}

function Agent:constructor(i, ped, vehicle)
    outputDebugString("Agent:constructor(" .. tostring(i) .. ", " .. tostring(ped) .. ", " .. tostring(vehicle) .. ")")
    self.id = i
    self.ped = ped
    self.vehicle = vehicle

    self.done = 0
    self.lastTime = getTickCount()
    self.reward = 0
    self.startTime = getTickCount()
    self.lastStateTime = getTickCount()
    self.actions = 0
    self.state = {}
    self.policyClient = new(PolicyClient, "http://127.0.0.1:8080")
    self.episodeId = tostring("agent-"..i)
    self.timesteps = 0

    createColShapes(self.vehicle)
    addEventHandler("onClientVehicleCollision", self.vehicle, function(collider, force, bodyPart, x, y, z, nx, ny, nz)
        if self.done == 0 then
            --self.done = 1
            self.reward = self.reward - 1
            outputDebugString("collision, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
        end
    end)
    addEventHandler("onClientVehicleExplode", self.vehicle, function()
        if self.done == 0 then
            self.done = 1
            self.reward = self.reward - 100
            outputDebugString("exploded, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
        end
    end)
    addEventHandler("onClientVehicleExit", self.vehicle, function()
        if self.done == 0 then
            self.done = 1
            self.reward = self.reward - 100
            outputDebugString("exited, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
        end
    end)
    addEventHandler("onClientVehicleDamage", self.vehicle, function(loss)
        if self.done == 0 and self.vehicle.health < 100 then
            self.done = 1
            outputDebugString("damage, reward: " .. self.reward)
        end
    end)

    setElementCollisionsEnabled(localPlayer, false)

    self.policyClient:StartEpisode(self.episodeId, true, function()
        outputDebugString("started episode")
    end)
end

function Agent:destructor()
    outputDebugString("Agent:destructor()")
    destroyColShapes()
    self.policyClient:GetAction(self.episodeId, self:getState(false), function()
        self.policyClient:EndEpisode(self.episodeId, self:getState())
        delete(self.policyClient)
        triggerServerEvent("onServerAgentDestroyed", resourceRoot, self.id)
    end) -- to not crash the server
end

function Agent:doAction(data)
    --outputDebugString("Agent:doAction(" .. tostring(data) .. ", " .. tostring(info) .. ")")
    --accelerate_reverse, steer, handbrake = fromJSON(fromJSON("["..data.."]")) -- WTF?
    --outputDebugString("accelerate_reverse: " .. tostring(accelerate_reverse) .. ", steer: " .. tostring(steer) .. ", handbrake: " .. tostring(handbrake))
    local action = fromJSON(data)
    local accelerate_reverse = action[1]
    local steer = action[2]
    local handbrake = action[3]

    setPedAnalogControlState(self.ped, "accelerate", accelerate_reverse > 0 and accelerate_reverse or 0)
    setPedAnalogControlState(self.ped, "brake_reverse", accelerate_reverse < 0 and -accelerate_reverse or 0)
    if steer > 0 then
        setPedAnalogControlState(self.ped, "vehicle_right", steer)
    else
        setPedAnalogControlState(self.ped, "vehicle_left", -steer)
    end
    setPedControlState(self.ped, "handbrake", handbrake > 0)

    -- calculate actions per second
    local time = getTickCount()
    local delta = time - self.lastTime
    self.actions = self.actions + 1
    if delta > 5000 then
        local aps = self.actions / (delta / 1000)
        self.actions = 0
        outputDebugString("aps: " .. aps)
        self.lastTime = time
    end
end

function Agent:getReward()
    --return (self.reward) -- reward for driving on road
         --- getDistanceBetweenPoints3D(self.vehicle.position, 318.94519, -54.14864, 1.57812)
         -- (getTickCount() - self.startTime) / 1000 -- time penalty
    local reward = self.reward
    self.reward = -1
    return reward
end

function Agent:getState(render)
    local now = getTickCount()
    local nextCheckpoint = getNearestCheckpoint(self.vehicle)
    local state = {
        (now - self.lastStateTime) / 1000,
        self.vehicle.health,
        self.vehicle.position.x, self.vehicle.position.y, self.vehicle.position.z,
        destination.x, destination.y, destination.z,
        nextCheckpoint.x, nextCheckpoint.y, nextCheckpoint.z,
        self.vehicle.rotation.x, self.vehicle.rotation.y, self.vehicle.rotation.z,
        self.vehicle.velocity.x,self.vehicle.velocity.y,self.vehicle.velocity.z,
        self.vehicle.angularVelocity.x, self.vehicle.angularVelocity.y, self.vehicle.angularVelocity.z,
    }
    --print("state: " .. toJSON(state))
    for k, relPos in pairs(relativePositions) do
        --local startPos = self.vehicle.matrix:transformPosition(self.relativeStartPositions[k])
        local startPos = self.vehicle.position
        local endPos = self.vehicle.matrix:transformPosition(relPos)
        local hit, x, y, z = processLineOfSight(startPos, endPos, checkBuildings, checkVehicles, checkPlayers, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, self.vehicle, includeWorldModelInformation, bIncludeCarTyres)
        if hit then
            table.insert(state, getDistanceBetweenPoints3D(self.vehicle.position, x, y, z))
        else
            table.insert(state, maxDistance)
        end
        --if render then
        --    if hit then
        --        dxDrawLine3D(startPos, Vector3(x, y, z), tocolor(255, 0, 0))
        --    else
        --        dxDrawLine3D(startPos, endPos, tocolor(0, 255, 0))
        --    end
        --end
    end
    self.lastStateTime = now
    return state
end

local agent = nil
addEvent("onClientAgentCreated", true)
addEventHandler("onClientAgentCreated", resourceRoot, function(agentId, ped, vehicle)
    outputDebugString("onClientAgentCreated(" .. tostring(agentId) .. ", " .. tostring(ped) .. ", " .. tostring(vehicle) .. ")")
    if agent ~= nil then
        outputDebugString("agent already exists")
        delete(agent)
    end
    agent = new(Agent, agentId, ped, vehicle)

    function doAction(data, info)
        --outputDebugString("doAction(" .. tostring(data) .. ", " .. tostring(info) .. ")")
        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false or not info.success then
            return
        end
        agent:doAction(data)

        --outputDebugString("reward: " .. agent.reward)
        agent.policyClient:LogReturns(agent.episodeId, agent.reward)
        agent.reward = -1

        if (getTickCount() - agent.startTime) > 60000 or agent.done == 1 then
            delete(agent)
            agent = nil
        else
            getAction()
        end
        --outputDebugString("getAction-doAction took " .. getTickCount() - start .. "ms")
    end
    function getAction()
        --local start = getTickCount()
        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false then
            return
        end
        agent.policyClient:GetAction(agent.episodeId, agent:getState(false), doAction)
        --outputDebugString("getAction took " .. getTickCount() - start .. "ms")
    end
    setTimer(getAction, 1000, 1)
end)
--setTimer(function()
--    outputDebugString("pending requests: " .. #getRemoteRequests(resourceRoot))
--end, 1000, 0)


addEvent("onClientAgentDestroyed", true)
addEventHandler("onClientAgentDestroyed", resourceRoot, function(agentId)
    outputDebugString("onClientAgentDestroyed(" .. tostring(agentId) .. ")")
    delete(agent)
    agent = nil
end)
addEventHandler("onClientResourceStop", resourceRoot, function()
    outputDebugString("onClientResourceStop()")
end)

addEventHandler("onClientColShapeHit", resourceRoot, function(element, matchingDimension)
    if element == agent.vehicle then
        local reward = getElementData(source, "reward")
        destroyElement(source)
        agent.reward = agent.reward + reward
        outputDebugString("reward: " .. agent.reward)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    outputDebugString("onClientResourceStop()")
    delete(agent)
    -- remove all pending fetchRemote requests
    for i, request in pairs(getRemoteRequests(resourceRoot)) do
        abortRemoteRequest(request)
    end
end)

addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    cancelEvent()
end)

setDevelopmentMode(true)
