PolicyClient = {}

local function toJSON2(data)
    local result = toJSON(data, true)
    -- remove the outer brackets
    result = utf8.sub(result, 2, utf8.len(result) - 1)
    return result
end

function PolicyClient:constructor(base_url)
    self.base_url = base_url
    self.base_options = {
        queueName = "policy-client",
        connectTimeout = 1000,
        connectionAttempts = 1,
        headers = {
            ["Content-Type"] = "application/json"
        }
    }

    local base_url_domain = base_url:match("^%w+://([^/]+)")
    requestBrowserDomains({base_url_domain}, true)
end

function PolicyClient:destructor()
    for i, request in pairs(getRemoteRequests(resourceRoot)) do
        local info = getRemoteRequestInfo(request)
        if info and info.queueName == self.base_options.queueName then
            abortRemoteRequest(request)
        end
    end
end

--@app.post("/episode")
--def start_episode(episode_id: Optional[str] = Body(...), training_enabled: bool = Body(...)) -> str:
function PolicyClient:StartEpisode(episode_id, training_enabled, callback)
    outputDebugString("StartEpisode("..tostring(episode_id)..", "..tostring(training_enabled)..")")
    if episode_id == nil or training_enabled == nil then
        outputDebugString("StartEpisode: episode_id or training_enabled is nil")
        return
    end
    local url = self.base_url .. "/episode"
    local data = {
        episode_id = episode_id,
        training_enabled = training_enabled
    }
    local options = self.base_options
    options.method = "POST"
    options.postData = toJSON2(data)
    outputDebugString("StartEpisode: "..toJSON2(options))
    local request = fetchRemote(url, options, callback)
    outputDebugString("StartEpisode: "..tostring(request)) -- why do I need to do this? without it the request is never sent
    if not request then
        outputDebugString("StartEpisode: fetchRemote failed")
    end
end

--@app.get("/action")
--def get_action(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...)) -> Union[EnvActionType, MultiAgentDict]:
function PolicyClient:GetAction(episode_id, observation, callback)
    --outputDebugString("GetAction("..tostring(episode_id)..", "..toJSON2(observation)..")")
    if episode_id == nil or observation == nil then
        outputDebugString("GetAction: episode_id or observation is nil")
        return
    end
    local url = self.base_url .. "/action"
    local data = {
        episode_id = episode_id,
        observation = observation
    }
    local options = self.base_options
    options.method = "GET"
    options.postData = toJSON2(data)
    options.queueName = options.queueName .. "-GetAction"
    if not fetchRemote(url, options, callback) then
        outputDebugString("GetAction: fetchRemote failed")
    end
end

--@app.post("/action")
--def log_action(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...), action: Union[EnvActionType, MultiAgentDict] = Body(...))
function PolicyClient:LogAction(episode_id, observation, action)
    outputDebugString("LogAction("..tostring(episode_id)..", "..toJSON2(observation)..", "..tostring(action)..")")
    if episode_id == nil or observation == nil or action == nil then
        outputDebugString("LogAction: episode_id, observation or action is nil")
        return
    end
    local url = self.base_url .. "/action"
    local data = {
        episode_id = episode_id,
        observation = observation,
        action = action
    }
    local options = self.base_options
    options.method = "POST"
    options.postData = toJSON2(data)
    options.queueName = options.queueName .. "-LogAction"
    fetchRemote(url, options, function(data, info) outputDebugString("LogAction returned "..tostring(info)) end)
end

--@app.post("/returns")
--def log_returns(episode_id: str = Body(...), reward: float = Body(...), info: Union[EnvInfoDict, MultiAgentDict] = None, multiagent_done_dict: Optional[MultiAgentDict] = None) -> None:
function PolicyClient:LogReturns(episode_id, reward, info, multiagent_done_dict)
    --outputDebugString("LogReturns("..tostring(episode_id)..", "..tostring(reward)..", "..tostring(info)..", "..tostring(multiagent_done_dict)..")")
    if episode_id == nil or reward == nil then
        outputDebugString("LogReturns: episode_id or reward is nil")
        return
    end
    local url = self.base_url .. "/returns"
    local data = {
        episode_id = episode_id,
        reward = reward,
        info = info,
        multiagent_done_dict = multiagent_done_dict
    }
    local options = self.base_options
    options.method = "POST"
    options.postData = toJSON2(data)
    options.queueName = options.queueName .. "-LogReturns"
    if not fetchRemote(url, options, function(data, info) end) then
        outputDebugString("LogReturns: fetchRemote failed")
    end
end

--@app.post("/episode_end")
--def end_episode(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...)) -> None:
function PolicyClient:EndEpisode(episode_id, observation)
    outputDebugString("EndEpisode("..tostring(episode_id)..", "..tostring(observation)..")")
    if episode_id == nil or observation == nil then
        outputDebugString("EndEpisode: episode_id or observation is nil")
        return
    end
    local url = self.base_url .. "/episode_end"
    local data = {
        episode_id = episode_id,
        observation = observation
    }
    local options = self.base_options
    options.method = "POST"
    options.postData = toJSON2(data)
    fetchRemote(url, options, function(data, info) outputDebugString("EndEpisode returned "..tostring(info)) end)
end
