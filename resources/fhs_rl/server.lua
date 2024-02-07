setGameSpeed(1)
setFPSLimit(25)

Agent = {}

function getAgentPlayer()
    return getPlayerFromName("agent")
end

function Agent:constructor(i)
    --outputDebugString("Agent:constructor("..i..")")
    self.id = i
    self.ped = createPed(250, 232.72765, 33.47713, 2.42969)
    self.vehicle = createVehicle(411, 232.72765, 33.47713, 2.42969, 0, 0, 180)
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
    triggerClientEvent(getAgentPlayer(), "onClientAgentCreated", resourceRoot, self.id, self.ped, self.vehicle)
end

function Agent:destructor()
    destroyElement(self.ped)
    destroyElement(self.vehicle)
    triggerClientEvent(getAgentPlayer(), "onClientAgentDestroyed", resourceRoot, self.id)
end

local agent_id = 0
local agents = {}
local stopped = true
local resetting = false
function resetEnvironment()
    outputDebugString("resetEnvironment")
    resetting = true
    stopEnvironment()
    startEnvironment()
    resetting = false
end

function startEnvironment()
    outputDebugString("startEnvironment")
    stopped = false
    local agent = new(Agent, agent_id)
    agent_id = agent_id + 1
    agents[agent_id] = agent
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
    if stopped and resetting then
        startEnvironment()
    end
end)

addCommandHandler("rl_start", startEnvironment)
addCommandHandler("rl_stop", stopEnvironment)
addCommandHandler("rl_reset", resetEnvironment)