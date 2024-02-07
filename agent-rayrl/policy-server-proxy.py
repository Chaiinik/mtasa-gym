#!/usr/bin/env python
import ray
from ray.rllib.env.policy_client import PolicyClient
from fastapi import FastAPI, Body
from typing import Union, Optional
from ray.rllib.utils.typing import (
    MultiAgentDict,
    EnvInfoDict,
    EnvObsType,
    EnvActionType,
)
import json
import numpy as np
import time

app = FastAPI()
while True:
    try:
        client = PolicyClient("http://agent:8081", inference_mode="remote")
        break
    except:
        print("Waiting for server...")
        time.sleep(1)

@app.post("/episode")
def start_episode(episode_id: Optional[str] = Body(...), training_enabled: bool = Body(...)) -> str:
    return client.start_episode(episode_id, training_enabled)

@app.get("/action")
def get_action(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...)): #-> Union[EnvActionType, MultiAgentDict]:
    return [client.get_action(episode_id, observation).tolist()]

@app.post("/action")
def log_action(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...), action: Union[EnvActionType, MultiAgentDict] = Body(...)) -> None:
    return client.log_action(episode_id, observation, action)

@app.post("/returns")
def log_returns(episode_id: str = Body(...), reward: float = Body(...), info: Union[EnvInfoDict, MultiAgentDict] = None, multiagent_done_dict: Optional[MultiAgentDict] = None) -> None:
    return client.log_returns(episode_id, reward, info, multiagent_done_dict)

@app.post("/episode_end")
def end_episode(episode_id: str = Body(...), observation: Union[EnvObsType, MultiAgentDict] = Body(...)) -> None:
    return client.end_episode(episode_id, observation)
