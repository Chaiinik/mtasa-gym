-- globals
local render = false
local relativePositions = {}
local maxDistance = 100
local step = 360/48
for i = 0, 360-step, step do
    --for z = -10, 10, 10 do
        local x = math.cos(math.rad(i)) * maxDistance
        local y = math.sin(math.rad(i)) * maxDistance
        local z = 0
        table.insert(relativePositions, Vector3(x, y, z))
    --end
end
outputDebugString("relativePositions: " .. #relativePositions)

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

Agent = {}

function Agent:constructor(i, ped, vehicle, destination)
    outputDebugString("Agent:constructor(" .. tostring(i) .. ", " .. tostring(ped) .. ", " .. tostring(vehicle) .. ")")
    self.id = i
    self.ped = ped
    self.vehicle = vehicle
    self.destination = destination

    self.done = 0
    self.lastActionTime = getTickCount()
    self.lastObservationTime = getTickCount()
    self.relativePositions = {}
    self.rewards = {}
    self.startTime = getTickCount()
    self.actions = 0
    self.observations = 0
    self.state = {}
    self.collision = 0

    --[[
    addEventHandler("onClientVehicleCollision", self.vehicle, function(collider, force, bodyPart, x, y, z, nx, ny, nz)
        self.done = 1
    end)
    addEventHandler("onClientVehicleExplode", self.vehicle, function()
        self.done = 1
    end)
    addEventHandler("onClientVehicleExit", self.vehicle, function()
        self.done = 1
    end)
    addEventHandler("onClientVehicleDamage", self.vehicle, function(loss)
        if self.done == 0 and self.vehicle.health < 100 then
            self.done = 1
        end
    end)]]
    local collisionDamageMultiplier = getVehicleHandling(self.vehicle).collisionDamageMultiplier
    addEventHandler("onClientVehicleCollision", self.vehicle, function(collider, force, bodyPart, x, y, z, nx, ny, nz)
        self.collision = force * collisionDamageMultiplier
        --self.collision = 1
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

    self:doAction(toJSON({0, 0}), 0)
end

function Agent:destructor()
    outputDebugString("Agent:destructor()")
    self.vehicle = nil
    self.ped = nil
end


function Agent:doAction(data, info)
    --outputDebugString("Agent:doAction(" .. tostring(data) .. ", " .. tostring(info) .. ")")

    local action = fromJSON(data)
    accelerate_reverse = action[1]
    steer = action[2]
    --handbrake = action[3]

    if accelerate_reverse > 0 then
        setPedAnalogControlState(self.ped, "brake_reverse", 0)
        setPedAnalogControlState(self.ped, "accelerate", accelerate_reverse)
    else
        setPedAnalogControlState(self.ped, "accelerate", 0)
        setPedAnalogControlState(self.ped, "brake_reverse", -accelerate_reverse)
    end
    --setPedAnalogControlState(self.ped, "accelerate", accelerate_reverse > 0 and accelerate_reverse or 0)
    --setPedAnalogControlState(self.ped, "brake_reverse", accelerate_reverse < 0 and -accelerate_reverse or 0)
    if steer > 0 then
        setPedAnalogControlState(self.ped, "vehicle_left", 0)
        setPedAnalogControlState(self.ped, "vehicle_right", steer)
    else
        setPedAnalogControlState(self.ped, "vehicle_right", 0)
        setPedAnalogControlState(self.ped, "vehicle_left", -steer)
    end
    --setPedControlState(self.ped, "handbrake", handbrake > 0)

    -- send state to server
    local state = toJSON(self:getState())
    fetchRemote("http://127.0.0.1:8000/step/"..self.id, "agent_"..tostring(self.id).."step", 1, 1000, function(data, info)
        if self.vehicle == nil or self.vehicle == false then
            outputDebugString("aborting request")
            return
        end
        if info ~= 0 then
            data = toJSON({0, 0})
        end
        local nextAction = fromJSON(data)
        self:doAction(data, info)
    end, state, false)

    -- calculate actions per second
    local time = getTickCount()
    local delta = time - self.lastActionTime
    self.actions = self.actions + 1
    if delta > 5000 then
        local aps = self.actions / (delta / 1000)
        self.actions = 0
        outputDebugString("aps: " .. aps)
        self.lastActionTime = time
    end
end

local materialIdType = {
    -- Default
    [0] = 1,
    [1] = 1,
    [2] = 1,
    [3] = 1,
    -- Concrete
    [4] = 2,
    [5] = 2,
    [7] = 2,
    [8] = 2,
    [34] = 2,
    [89] = 2,
    [127] = 2,
    [135] = 2,
    [136] = 2,
    [137] = 2,
    [138] = 2,
    [139] = 2,
    [144] = 2,
    [165] = 2,
    -- Gravel
    [6] = 3,
    [85] = 3,
    [101] = 3,
    [134] = 3,
    [140] = 3,
    -- Grass
    [9] = 4,
    [10] = 4,
    [11] = 4,
    [12] = 4,
    [13] = 4,
    [14] = 4,
    [15] = 4,
    [16] = 4,
    [17] = 4,
    [20] = 4,
    [80] = 4,
    [81] = 4,
    [82] = 4,
    [115] = 4,
    [116] = 4,
    [117] = 4,
    [118] = 4,
    [119] = 4,
    [120] = 4,
    [121] = 4,
    [122] = 4,
    [125] = 4,
    [146] = 4,
    [147] = 4,
    [148] = 4,
    [149] = 4,
    [150] = 4,
    [151] = 4,
    [152] = 4,
    [153] = 4,
    [160] = 4,
    -- Dirt
    [19] = 5,
    [21] = 5,
    [22] = 5,
    [24] = 5,
    [25] = 5,
    [26] = 5,
    [27] = 5,
    [40] = 5,
    [83] = 5,
    [84] = 5,
    [87] = 5,
    [88] = 5,
    [100] = 5,
    [110] = 5,
    [123] = 5,
    [124] = 5,
    [126] = 5,
    [128] = 5,
    [129] = 5,
    [130] = 5,
    [132] = 5,
    [133] = 5,
    [141] = 5,
    [142] = 5,
    [145] = 5,
    [155] = 5,
    [156] = 5,
    -- Sand
    [28] = 6,
    [29] = 6,
    [30] = 6,
    [31] = 6,
    [32] = 6,
    [33] = 6,
    [74] = 6,
    [75] = 6,
    [76] = 6,
    [77] = 6,
    [78] = 6,
    [79] = 6,
    [86] = 6,
    [96] = 6,
    [97] = 6,
    [98] = 6,
    [99] = 6,
    [131] = 6,
    [143] = 6,
    [157] = 6,
    -- Glass
    [45] = 7,
    [46] = 7,
    [47] = 7,
    [175] = 7,
    -- Wood
    [42] = 8,
    [43] = 8,
    [44] = 8,
    [70] = 8,
    [72] = 8,
    [73] = 8,
    [172] = 8,
    [173] = 8,
    [174] = 8,
    -- Metal
    [50] = 9,
    [51] = 9,
    [52] = 9,
    [53] = 9,
    [54] = 9,
    [55] = 9,
    [56] = 9,
    [57] = 9,
    [58] = 9,
    [59] = 9,
    [63] = 9,
    [64] = 9,
    [65] = 9,
    [162] = 9,
    [164] = 9,
    [167] = 9,
    [168] = 9,
    [171] = 9,
    -- Stone
    [18] = 11,
    [35] = 11,
    [36] = 11,
    [37] = 11,
    [69] = 11,
    [109] = 11,
    [154] = 11,
    [161] = 11,
    -- Vegetation
    [23] = 12,
    [41] = 12,
    [111] = 12,
    [112] = 12,
    [113] = 12,
    [114] = 12,
    -- Water
    [38] = 13,
    [39] = 13,
    -- Misc
    [48] = 14,
    [49] = 14,
    [60] = 14,
    [61] = 14,
    [62] = 14,
    [66] = 14,
    [67] = 14,
    [68] = 14,
    [71] = 14,
    [90] = 14,
    [91] = 14,
    [92] = 14,
    [93] = 14,
    [94] = 14,
    [95] = 14,
    [102] = 14,
    [103] = 14,
    [104] = 14,
    [105] = 14,
    [106] = 14,
    [107] = 14,
    [108] = 14,
    [158] = 14,
    [159] = 14,
    [163] = 14,
    [166] = 14,
    [169] = 14,
    [170] = 14,
    [176] = 14,
    [177] = 14,
    [178] = 14
}

function Agent:getState()
    --local nextCheckpoint = getNearestCheckpoint(self.vehicle)
    local observation = {
        --reward = self:getReward(),
        --done = self.done,
        health = {self.vehicle.health-250},
        --position = {self.vehicle.position.x, self.vehicle.position.y, self.vehicle.position.z},
        --destination = {destination.x, destination.y, destination.z},
        --next_checkpoint = {nextCheckpoint.x, nextCheckpoint.y, nextCheckpoint.z},
        rotation = {self.vehicle.rotation.x, self.vehicle.rotation.y, self.vehicle.rotation.z},
        velocity = {self.vehicle.velocity.x,self.vehicle.velocity.y,self.vehicle.velocity.z},
        angular_velocity = {self.vehicle.angularVelocity.x, self.vehicle.angularVelocity.y, self.vehicle.angularVelocity.z},
        --wheel_friction = {self.vehicle:getWheelFrictionState(0), self.vehicle:getWheelFrictionState(1), self.vehicle:getWheelFrictionState(2), self.vehicle:getWheelFrictionState(3)},
        wheel_on_ground = {
            self.vehicle:isWheelOnGround(0) and 1 or 0,
            self.vehicle:isWheelOnGround(1) and 1 or 0,
            self.vehicle:isWheelOnGround(2) and 1 or 0,
            self.vehicle:isWheelOnGround(3) and 1 or 0
        },
        -- wheel_control = {
        --     getPedAnalogControlState(self.ped, "accelerate") - getPedAnalogControlState(self.ped, "brake_reverse"), -- forward/backward
        --     getPedAnalogControlState(self.ped, "vehicle_right") - getPedAnalogControlState(self.ped, "vehicle_left"), -- left/right
        --     --getPedControlState(self.ped, "handbrake") and 1 or 0 -- handbrake
        -- },
        in_water = { self.vehicle.inWater and 1 or 0 },
        collision = { self.collision },
        lidar = {},
        --lidar_materialType = {},
    }
    --print("state: " .. toJSON(state))
    for k, relPos in pairs(relativePositions) do
        --local startPos = self.vehicle.matrix:transformPosition(self.relativeStartPositions[k])
        local startPos = self.vehicle.position
        local endPos = self.vehicle.matrix:transformPosition(relPos)
        local hit, x, y, z, hitElement, normalX, normalY, normalZ, material = processLineOfSight(startPos, endPos, checkBuildings, checkVehicles, checkPlayers, checkObjects, checkDummies, seeThroughStuff, ignoreSomeObjectsForCamera, shootThroughStuff, self.vehicle, includeWorldModelInformation, bIncludeCarTyres)
        if hit then
            table.insert(observation["lidar"], getDistanceBetweenPoints3D(startPos, x, y, z))
            --table.insert(observation["lidar_materialType"], materialIdType[material] or 15)
        else
            table.insert(observation["lidar"], maxDistance)
            --table.insert(observation["lidar_materialType"], 0)
        end
        if render then
            if hit then
                dxDrawLine3D(startPos, Vector3(x, y, z), tocolor(255, 0, 0))
            else
                dxDrawLine3D(startPos, endPos, tocolor(0, 255, 0))
            end
        end
    end

    local state = {
        observation = observation,
        desired_goal = {self.destination.x, self.destination.y, self.destination.z},
        achieved_goal = {self.vehicle.position.x, self.vehicle.position.y, self.vehicle.position.z},
        --done = self.done,
        --info = {}
    }
    self.collision = 0
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
addEventHandler("onClientAgentCreated", resourceRoot, function(agentId, ped, vehicle, destX, destY, destZ)
    if agent ~= nil then
        outputDebugString("agent already exists")
        delete(agent)
    end
    if getRemoteRequests(resourceRoot) then
        for i, request in pairs(getRemoteRequests(resourceRoot)) do
            abortRemoteRequest(request)
        end
    end
    local newAgent = new(Agent, agentId, ped, vehicle, Vector3(destX, destY, destZ))
    agent = newAgent
end)
setTimer(function()
    outputDebugString("pending requests: " .. #getRemoteRequests(resourceRoot))
end, 5000, 0)

addEventHandler("onClientPreRender", root, function()
    setTime(12, 0)
    setWeather(0)
--
--    if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false then
--        return
--    end
--    if #getRemoteRequests(resourceRoot) > 1 then
--    --if getGameSpeed() == 0 then
--    --if runningStep then
--        return
--    end
--    --runningStep = true
--    local state = toJSON(agent:getState())
--    --setGameSpeed(0)
--    fetchRemote("http://127.0.0.1:8000/step/"..agent.id, "agent_"..tostring(agent.id).."step", 1, 1000, function(data, info)
--        --setGameSpeed(2)
--        --runningStep = false
--        if agent == nil or agent == false or agent.vehicle == nil or agent.vehicle == false or info ~= 0 then
--            return
--        end
--        local action = fromJSON(data)
--        agent:doAction(data, info)
--    end, state, false)
end)

addEvent("onClientAgentDestroyed", true)
addEventHandler("onClientAgentDestroyed", resourceRoot, function(agentId)
    outputDebugString("onClientAgentDestroyed(" .. tostring(agentId) .. ")")
    local oldAgent = agent
    agent = nil
    delete(oldAgent)
    if getRemoteRequests(resourceRoot) then
        for i, request in pairs(getRemoteRequests(resourceRoot)) do
            abortRemoteRequest(request)
        end
    end
    triggerServerEvent("onServerAgentDestroyed", resourceRoot, agentId)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    outputDebugString("onClientResourceStop()")
    --delete(agent)
    -- remove all pending fetchRemote requests
    for i, request in pairs(getRemoteRequests(resourceRoot)) do
        abortRemoteRequest(request)
    end
end)

addEventHandler("onClientPlayerDamage", root, cancelEvent)
addEventHandler("onClientPlayerWasted", root, cancelEvent)
addEventHandler("onClientVehicleExplode", root, cancelEvent)
addEventHandler("onClientVehicleDamage", root, cancelEvent)
addEventHandler("onClientObjectBreak", root, cancelEvent)
addEventHandler("onClientObjectDamage", root, cancelEvent)

setDevelopmentMode(true)
showChat(false)
setPlayerHudComponentVisible("all", true)
setAmbientSoundEnabled("general", false)
setAmbientSoundEnabled("gunfire", false)
for i=0, 50 do
    setWorldSoundEnabled(i, false)
end
setWindVelocity(0, 0, 0)
setRainLevel(0)
setCloudsEnabled(false)
