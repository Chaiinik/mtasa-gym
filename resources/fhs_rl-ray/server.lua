setGameSpeed(1)
setFPSLimit(60)

Agent = {}

function Agent:constructor(i)
    --outputDebugString("Agent:constructor("..i..")")
    self.id = i
    self.ped = createPed(250, 232.72765, 33.47713, 2.42969)
    self.vehicle = createVehicle(411, 232.72765, 33.47713, 2.42969, 0, 0, 180)
    --setElementFrozen(self.vehicle, true)
    --setElementAlpha(self.vehicle, 0)
    --setElementAlpha(self.ped, 0)
    --setElementCollisionsEnabled(self.vehicle, false)
    for i=0,3 do
        setVehicleLightState(self.vehicle, i, 1)
    end
    warpPedIntoVehicle(self.ped, self.vehicle, 0)
    --warpPedIntoVehicle(client, self.vehicle, 1)
    setElementCollisionsEnabled(getPlayerFromName("agent"), false)
    warpPedIntoVehicle(getPlayerFromName("agent"), self.vehicle, 1)
    triggerClientEvent(root, "onClientAgentCreated", resourceRoot, self.id, self.ped, self.vehicle)
end

function Agent:destructor()
    destroyElement(self.ped)
    destroyElement(self.vehicle)
    triggerClientEvent(root, "onClientAgentDestroyed", resourceRoot, self.id)
end

local agents = {}
local stopped = true
function resetEnvironment()
    outputDebugString("resetEnvironment")
    stopEnvironment()
    startEnvironment()
end

function startEnvironment()
    outputDebugString("startEnvironment")
    stopped = false
    local agent = new(Agent, math.random(0, 1000000))
    agents[agent.id] = agent
end

function stopEnvironment()
    outputDebugString("stopEnvironment")
    if stopped then return end
    stopped = true
    for i,agent in pairs(agents) do
        delete(agent)
    end
end

addEvent("onServerAgentDestroyed", true)
addEventHandler("onServerAgentDestroyed", resourceRoot, function(id)
    outputDebugString("onServerAgentDestroyed("..id..")")
    resetEnvironment()
end)

setTimer(startEnvironment, 1000, 1)
addEventHandler("onResourceStop", resourceRoot, stopEnvironment)