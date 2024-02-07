from fastapi import FastAPI, Depends, Request
from MtaSaEnvGoal import MtaSaEnvGoal
import threading
from gymnasium.wrappers import TimeLimit
import requests
import json
from sbx import DroQ
from stable_baselines3 import HerReplayBuffer
from stable_baselines3.common.env_checker import check_env
import os

SPEED = 1
env = MtaSaEnvGoal()
env = TimeLimit(env, max_episode_steps=5*60*25*SPEED)
app = FastAPI()

try:
    model = DroQ.load("model-droq-goal2", env=env, verbose=1, tensorboard_log="./tensorboard-goal/", replay_buffer_class=HerReplayBuffer, replay_buffer_kwargs=dict(n_sampled_goal=4, goal_selection_strategy="future", copy_info_dict=True))
    model.set_env(env)
    model.load_replay_buffer("replay_buffer-droq-goal2")
    model.learning_starts = 0
    print("Model loaded DroQ")
except:
    model = DroQ("MultiInputPolicy", env, verbose=1, tensorboard_log="./tensorboard-goal/", replay_buffer_class=HerReplayBuffer, replay_buffer_kwargs=dict(n_sampled_goal=4, goal_selection_strategy="future", copy_info_dict=True), learning_starts=5*60*25*SPEED)
    print("Model created DroQ")

@app.get("/")
def read_root():
    return {"Hello": "World"}

async def get_observation(request: Request):
    body = await request.body()
    json_body = json.loads(body)
    observation = json_body[0]
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
        check_env(env)
        print("Environment checked")
        while True:
            model.learn(total_timesteps=30*60*25*SPEED, log_interval=1, reset_num_timesteps=False) # 30 minutes
            model.save("model-droq-goal2")
            model.save_replay_buffer("replay_buffer-droq-goal2")
            print("Model saved")

@app.on_event("startup")
def startup_event():
    BackgroundTasks().start()

@app.on_event("shutdown")
def shutdown_event():
    requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_goal/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

