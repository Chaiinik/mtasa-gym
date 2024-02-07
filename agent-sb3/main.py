from fastapi import FastAPI, Depends, Request
from stable_baselines3 import SAC, HerReplayBuffer
from MtaSaEnvRt import MtaSaEnvRt, action_queue, observation_queue
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

my_config = DEFAULT_CONFIG_DICT
my_config["interface"] = MtaSaEnvRt
my_config["time_step_duration"] = 1/25
my_config["start_obs_capture"] = 0 #1/40 #- 0.005
my_config["time_step_timeout_factor"] = 1
my_config["ep_max_length"] = 60*25 # 60 seconds
my_config["act_buf_len"] = 4
my_config["reset_act_buf"] = True
#my_config["act_in_obs"] = False
#my_config['benchmark'] = True

env = gym.make("real-time-gym-ts-v1", config=my_config)
env = FlattenObservation(env)
#env = DummyVecEnv([lambda: env])
#env = VecNormalize(env, norm_obs=True, norm_reward=False, clip_obs=10.)

app = FastAPI()
model = SAC("MlpPolicy", env, verbose=1)#, replay_buffer_class=HerReplayBuffer, replay_buffer_kwargs=dict(n_sampled_goal=4, goal_selection_strategy="future"), learning_starts=2*60*25)

# find the latest checkpoint (highest number)
#checkpoint_path = None
#checkpoint_steps = 0
# search log folder for checkpoints
#try:
#    os.mkdir("./logs/")
#except FileExistsError:
#    pass
#for file in os.listdir("./logs/"):
#    if file.startswith("rl_model") and file.endswith(".zip"):
#        checkpoint_path = os.path.join("./logs/", file)
#        steps = int(file.split("_")[2])
#        if steps > checkpoint_steps:
#            checkpoint_steps = steps
#            checkpoint_path = os.path.join("./logs/", file)
#if checkpoint_path is not None:
#    model = SAC.load(checkpoint_path, env=env, verbose=1, device="cuda")
#    model.set_env(env)
#    model.learning_starts = checkpoint_steps
#    print("Loaded checkpoint from", checkpoint_path)
#
## Save a checkpoint every few steps
#checkpoint_callback = CheckpointCallback(
#  save_freq=5*60*25, # 5 minutes
#  save_path="./logs/",
#  name_prefix="rl_model",
#  save_replay_buffer=False,
#  save_vecnormalize=False,
#  verbose=2
#)

@app.get("/")
def read_root():
    return {"Hello": "World"}

async def get_observation(request: Request):
    body = await request.body()
    json_body = json.loads(body)
    observation = json_body[0]
    for key, value in observation.items():
        observation[key] = np.array(value)
    return observation

@app.get("/action")
def get_action():
    action = action_queue.get()
    if action is None:
        print("No action")
        return [[0.0, 0.0, 0.0]]
    return [action.tolist()]

@app.post("/observation")
def post_observation(observation: list = Depends(get_observation)):
    observation_queue.put(observation)

class BackgroundTasks(threading.Thread):
    def run(self,*args,**kwargs):
        #print("Environment benchmarks:")
        #print(env.benchmarks())
        check_env(env)
        print("Environment checked")
        while True:
            env.reset()
            model.learn(total_timesteps=60*60*25, log_interval=4) # 1 hour
            #model.learn(total_timesteps=1_000_000_000, log_interval=4, callback=checkpoint_callback)
            #pprint.pprint(env.benchmarks())
            model.save("model")
            model.save_replay_buffer("replay_buffer")
            print("Model saved")

        #observation, _ = env.reset()
        #while True:
        #    action, _states = model.predict(observation)
        #    observation, reward, done, truncaed, info = env.step(action)
        #    if done or truncaed:
        #        break


@app.on_event("startup")
def startup_event():
    BackgroundTasks().start()

@app.on_event("shutdown")
def shutdown_event():
    requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

