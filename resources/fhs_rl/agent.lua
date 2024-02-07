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
    self.lastActionTime = getTickCount()
    self.lastObservationTime = getTickCount()
    self.relativePositions = {}
    self.rewards = {}
    self.startTime = getTickCount()
    self.actions = 0
    self.observations = 0
    self.state = {}

    createColShapes(self.vehicle)
    addEventHandler("onClientVehicleCollision", self.vehicle, function(collider, force, bodyPart, x, y, z, nx, ny, nz)
        if self.done == 0 then
            table.insert(self.rewards, -1)
            --outputDebugString("collision, reward: " .. self.reward)
        end
        --cancelEvent()
    end)
    addEventHandler("onClientVehicleExplode", self.vehicle, function()
        if self.done == 0 then
            --self.done = 1
            --self.reward = self.reward - 100
            --outputDebugString("exploded, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
            table.insert(self.rewards, -100)
        end
    end)
    addEventHandler("onClientVehicleExit", self.vehicle, function()
        if self.done == 0 then
            --self.done = 1
            --self.reward = self.reward - 100
            --outputDebugString("exited, reward: " .. self.reward)
            --setElementFrozen(self.vehicle, true)
            table.insert(self.rewards, -100)
        end
    end)
    addEventHandler("onClientVehicleDamage", self.vehicle, function(loss)
        if self.done == 0 and self.vehicle.health < 100 then
            self.done = 1
            --outputDebugString("damage, reward: " .. self.reward)
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
    local delta = time - self.lastActionTime
    self.actions = self.actions + 1
    if delta > 1000 then
        local aps = self.actions / (delta / 1000)
        self.actions = 0
        outputDebugString("aps: " .. aps)
        self.lastActionTime = time
    end
end

function Agent:getReward()
    --return (self.reward) -- reward for driving on road
         --- getDistanceBetweenPoints3D(self.vehicle.position, 318.94519, -54.14864, 1.57812)
         -- (getTickCount() - self.startTime) / 1000 -- time penalty
    --local reward = self.reward
    --self.reward = -1
    --return reward
    --local reward = -(getDistanceBetweenPoints3D(self.vehicle.position, destination.x, destination.y, destination.z)/300)
    local reward = -1
    for i, r in pairs(self.rewards) do
        reward = reward + r
    end
    --outputDebugString("reward: " .. reward)
    self.rewards = {}
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
    -- calculate observation per second
    --local time = getTickCount()
    --local delta = time - self.lastObservationTime
    --self.observations = self.observations + 1
    --if delta > 1000 then
    --    local ops = self.observations / (delta / 1000)
    --    self.observations = 0
    --    outputDebugString("ops: " .. ops)
    --    self.lastObservationTime = time
    --end
    return state
end

local agent = nil
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
    function doAction(data, info)
        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false or info ~= 0 then
            return
        end
        getAction()
        agent:doAction(data, info)
    end
    function getAction()
        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false then
            return
        end
        fetchRemote("http://127.0.0.1:8000/action", "agent_"..tostring(agent.id).."action", 10, 10000, doAction)
    end
    function sendState()
        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false then
            return
        end
        local json = toJSON(agent:getState(false))
        fetchRemote("http://127.0.0.1:8000/observation", "agent_"..tostring(agent.id).."observation", 10, 10000, sendState, json, false)
    end
    sendState()
    getAction()
end)
--setTimer(function()
--    outputDebugString("pending requests: " .. #getRemoteRequests(resourceRoot))
--end, 5000, 0)

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
        local done = getElementData(source, "done")
        destroyElement(source)
        --agent.reward = agent.reward + reward
        outputDebugString("colshape hit, reward: " .. reward)
        table.insert(agent.rewards, reward)
        if done ~= nil and done == true then
            agent.done = 1
            outputDebugString("done")
        end
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
