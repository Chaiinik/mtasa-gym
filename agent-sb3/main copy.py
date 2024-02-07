from fastapi import FastAPI
from pydantic import BaseModel
from fastapi import Request
import numpy as np
import torch
from stable_baselines3 import SAC

app = FastAPI()
agents = {}
device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

# dummy env
class DummyEnv:
    def __init__(self):
        self.action_space = gym.spaces.Box(low=-1.0, high=1.0, shape=(3,), dtype=np.float32)
        self.observation_space = None

@app.get("/")
def read_root():
    return {"Hello": "World"}

prev_observation = None
prev_action = None
prev_reward = None
prev_done = None

@app.post("/step/{agent_id}")
async def step(agent_id: str, request: Request):
    global prev_observation, prev_action, prev_reward, prev_done
    body = await request.body()
    # parse from [[ 1000, 0, 0, 3, 0, 0, 0 ]] to array
    body = body.decode("utf-8")
    body = body.replace("[", "").replace("]", "")
    body = body.split(",")
    body = [float(x) for x in body]

    # parse body
    reward = body[0]
    done = body[1]
    observation = body[2:]

    # init agent
    if agent_id not in agents:
        agents[agent_id] = init_agent(len(observation))

    # train agent
    agents[agent_id].store_data(prev_observation, prev_action, prev_reward, observation, prev_done)
    agents[agent_id].train()

    # step
    action = agents[agent_id].get_exploration_action(observation, env)

    # save prev
    prev_observation = observation
    prev_action = action
    prev_reward = reward
    prev_done = done
    return [action]

    # accelerate/reverse, right/left, brake
    # return [[0.05, -1.0, 0]]


def init_agent(obs_dim: int, act_dim: int=3, act_limit: float=1.0):
    #agent = REDQSACAgent('MTASA-v0', obs_dim, act_dim, act_limit, device)
    agent = SAC()
    return agent
