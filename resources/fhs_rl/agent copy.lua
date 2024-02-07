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
    self.relativePositions = {}
    self.reward = 0
    self.startTime = getTickCount()
    self.actions = 0
    self.state = {}

    createColShapes()
    addEventHandler("onClientVehicleCollision", self.vehicle, function(collider, force, bodyPart, x, y, z, nx, ny, nz)
        if self.done == 0 then
            self.done = 1
            self.reward = self.reward - 100
            outputDebugString("collision, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
        end
        --cancelEvent()
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

    setElementCollisionsEnabled(localPlayer, false)

    -- disable collisions with other vehicles
    --setTimer(function()
    --    for i, veh in pairs(getElementsByType("vehicle")) do
    --        setElementCollidableWith(self.vehicle, veh, false)
    --    end
    --    setElementCollidableWith(self.vehicle, localPlayer, false)
    --    setElementCollisionsEnabled(self.vehicle, true)
    --    setElementFrozen(self.vehicle, false)
    --end, 1000, 1)
end

function Agent:destructor()
    destroyColShapes()
    outputDebugString("Agent:destructor()")
end

-- cast raycasts to get relative positions from vehicle
function Agent:calibratePositions()
    if #self.relativePositions > 0 then
        return
    end
    local oldPos = self.vehicle.position
    self.vehicle:setFrozen(true)
    self.vehicle:setPosition(oldPos+Vector3(0, 0, 100))

    setTimer(function()
        local positions = {}
        for k, relPos in pairs(relativePositions) do
            local startPos = self.vehicle.position + offset
            local endPos = self.vehicle.matrix:transformPosition(relPos)
            local hit, x, y, z = processLineOfSight(endPos, startPos, false, true, false, false, false, false, false, false, false, false, true)
            if hit then
                positions[#positions+1] = Vector3(x, y, z) - startPos
            else
                positions[#positions+1] = Vector3(0, 0, 0)
            end
        end
        self.relativeStartPositions = positions

        outputDebugString("calibrated positions: " .. #self.relativeStartPositions)
        self.vehicle:setPosition(oldPos)
        self.vehicle:setFrozen(false)
    end, 1000, 1)
end

function Agent:doAction(data, info)
    --outputDebugString("Agent:doAction(" .. tostring(data) .. ", " .. tostring(info) .. ")")

    local action = fromJSON(data)
    accelerate_reverse = action[1]
    steer = action[2]
    handbrake = action[3]

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
    if delta > 1000 then
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
    local nextCheckpoint = getNearestCheckpoint(self.vehicle)
    local state = {
        reward = self:getReward(),
        done = self.done,
        health = {self.vehicle.health},
        position = {self.vehicle.position.x, self.vehicle.position.y, self.vehicle.position.z},
        destination = {destination.x, destination.y, destination.z},
        next_checkpoint = {nextCheckpoint.x, nextCheckpoint.y, nextCheckpoint.z},
        rotation = {self.vehicle.rotation.x, self.vehicle.rotation.y, self.vehicle.rotation.z},
        velocity = {self.vehicle.velocity.x,self.vehicle.velocity.y,self.vehicle.velocity.z},
        angular_velocity = {self.vehicle.angularVelocity.x, self.vehicle.angularVelocity.y, self.vehicle.angularVelocity.z},
        --wheel-friction = {self.vehicle:getWheelFrictionState(0), self.vehicle:getWheelFrictionState(1), self.vehicle:getWheelFrictionState(2), self.vehicle:getWheelFrictionState(3)},
        --wheel-on-ground = {self.vehicle:isWheelOnGround(0), self.vehicle:isWheelOnGround(1), self.vehicle:isWheelOnGround(2), self.vehicle:isWheelOnGround(3)},
        lidar = {}
    }
    --print("state: " .. toJSON(state))
    for k, relPos in pairs(relativePositions) do
        --local startPos = self.vehicle.matrix:transformPosition(self.relativeStartPositions[k])
        local startPos = self.vehicle.position
        local endPos = self.vehicle.matrix:transformPosition(relPos)
        local hit, x, y, z = processLineOfSight(startPos, endPos, checkBuildings, checkVehicles, checkPlayers, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, self.vehicle, includeWorldModelInformation, bIncludeCarTyres)
        if hit then
            table.insert(state["lidar"], getDistanceBetweenPoints3D(self.vehicle.position, x, y, z))
        else
            table.insert(state["lidar"], maxDistance)
        end
        if render then
            if hit then
                dxDrawLine3D(startPos, Vector3(x, y, z), tocolor(255, 0, 0))
            else
                dxDrawLine3D(startPos, endPos, tocolor(0, 255, 0))
            end
        end
    end
    return state
end

local agent = nil
function doAction(data, info)
    --local time = getTickCount() - start
    --outputDebugString("data: " .. data .. ", time: " .. time)
    if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false or info ~= 0 then
        return
    end

    sendState()
    agent:doAction(data, info)
    --setTimer(sendState, 0, 1)
    --local time2 = getTickCount() - start
    --outputDebugString("time2: " .. time2)
end

function sendState()
    local json = toJSON(agent:getState(false))
    --outputDebugString(json)
    --local start = getTickCount()
    fetchRemote("http://127.0.0.1:8000/step", "agent_"..tostring(agent.id), doAction, json, false)
end
addEvent("onClientAgentCreated", true)
addEventHandler("onClientAgentCreated", resourceRoot, function(agentId, ped, vehicle)
    if agent ~= nil then
        outputDebugString("agent already exists")
        delete(agent)
    end
    agent = new(Agent, agentId, ped, vehicle)
    --agent:calibratePositions()
    if getRemoteRequests(resourceRoot) then
        for i, request in pairs(getRemoteRequests(resourceRoot)) do
            abortRemoteRequest(request)
        end
    end
    sendState()
end)
--[[addEventHandler("onClientRender", root, function(msSinceLastFrame)
    if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false then
        return
    end
    sendState()
end)]]--
setTimer(function()
    outputDebugString("pending requests: " .. #getRemoteRequests(resourceRoot))
end, 1000, 0)

addEvent("onClientAgentDestroyed", true)
addEventHandler("onClientAgentDestroyed", resourceRoot, function(agentId)
    outputDebugString("onClientAgentDestroyed(" .. tostring(agentId) .. ")")
    delete(agent)
    agent = nil
    if getRemoteRequests(resourceRoot) then
        for i, request in pairs(getRemoteRequests(resourceRoot)) do
            abortRemoteRequest(request)
        end
    end
    triggerServerEvent("onServerAgentDestroyed", resourceRoot, agentId)
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
    --delete(agent)
    -- remove all pending fetchRemote requests
    for i, request in pairs(getRemoteRequests(resourceRoot)) do
        abortRemoteRequest(request)
    end
end)

addEventHandler("onClientPlayerDamage", localPlayer, function(attacker, weapon, bodypart, loss)
    cancelEvent()
end)

setDevelopmentMode(true)
