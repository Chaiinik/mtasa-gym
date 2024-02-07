from fastapi import FastAPI, Depends, Request
from stable_baselines3 import SAC, HerReplayBuffer
from MtaSaEnvGoal import MtaSaEnvGoal
import uvicorn
import threading
import gymnasium as gym
from gymnasium.wrappers import FlattenObservation, TimeLimit
from stable_baselines3.common.env_checker import check_env
import requests
import time
import json
import numpy as np
from rtgym import DEFAULT_CONFIG_DICT
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env import VecNormalize, DummyVecEnv
import pprint
import os

env = MtaSaEnvGoal()
env = TimeLimit(env, max_episode_steps=60*25)

app = FastAPI()

try:
    model = SAC.load("model", env, verbose=1, replay_buffer_class=HerReplayBuffer, replay_buffer_kwargs=dict(n_sampled_goal=4, goal_selection_strategy="future", copy_info_dict=False))
    model.set_env(env)
    model.load_replay_buffer("replay_buffer")
    model.learning_starts = 0
    print("Model loaded")
except:
    model = SAC("MultiInputPolicy", env, verbose=1, replay_buffer_class=HerReplayBuffer, replay_buffer_kwargs=dict(n_sampled_goal=4, goal_selection_strategy="future", copy_info_dict=False), learning_starts=2*60*25)
    print("Model created")

@app.get("/")
def read_root():
    return {"Hello": "World"}

async def get_observation(request: Request):
    body = await request.body()
    json_body = json.loads(body)
    observation = json_body[0]
    #for key, value in observation.items():
    #    observation[key] = np.array(value)
    return observation

@app.post("/step/{agent_id}")
def step(agent_id: int, observation: list = Depends(get_observation)):
    env.app_put_observation(agent_id, observation)
    action = env.app_get_action(agent_id)
    return [action.tolist()]

class BackgroundTasks(threading.Thread):
    def run(self,*args,**kwargs):
        #print("Environment benchmarks:")
        #print(env.benchmarks())
        #check_env(env)
        #print("Environment checked")
        while True:
            #env.reset()
            #model.learn(total_timesteps=60*60*25, log_interval=1) # 1 hour
            model.learn(total_timesteps=4*60*60*25, log_interval=1) # 4 hour
            #model.learn(total_timesteps=1_000_000_000, log_interval=4, callback=checkpoint_callback)
            #pprint.pprint(env.benchmarks())
            model.save("model")
            model.save_replay_buffer("replay_buffer")
            print("Model saved")

        #while True:
        #    observation, _ = env.reset()
        #    while True:
        #        action, _states = model.predict(observation, deterministic=True)
        #        observation, reward, done, truncaed, info = env.step(action)
        #        if done or truncaed:
        #            break


@app.on_event("startup")
def startup_event():
    BackgroundTasks().start()

@app.on_event("shutdown")
def shutdown_event():
    requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

