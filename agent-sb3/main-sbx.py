from fastapi import FastAPI, Depends, Request
from MtaSaEnvRelative import MtaSaEnvRelative
import threading
from gymnasium.wrappers import FlattenObservation, TimeLimit
import requests
import json
from sbx import DroQ
from stable_baselines3 import HerReplayBuffer
from stable_baselines3.common.env_checker import check_env
import os

speed = 2
env = MtaSaEnvRelative()
env = FlattenObservation(env)
env = TimeLimit(env, max_episode_steps=60*25*speed)

app = FastAPI()

try:
    model = DroQ.load("model-droq-rel3", env=env, verbose=1, tensorboard_log="./tensorboard/")
    model.set_env(env)
    model.load_replay_buffer("replay_buffer-droq-rel3")
    print("Model loaded DroQ")
except:
    model = DroQ("MlpPolicy", env, verbose=1, tensorboard_log="./tensorboard/")
    print("Model created DroQ")

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
        check_env(env)
        print("Environment checked")
        while True:
            model.learn(total_timesteps=60*60*25*speed, log_interval=1, reset_num_timesteps=False) # 1 hour
            model.save("model-droq-rel3")
            model.save_replay_buffer("replay_buffer-droq-rel3")
            print("Model saved")

        while False:
            observation, _ = env.reset()
            while True:
                action, _states = model.predict(observation, deterministic=False)
                observation, reward, done, truncaed, info = env.step(action)
                if done or truncaed:
                    break


@app.on_event("startup")
def startup_event():
    #requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_rel/start", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))
    BackgroundTasks().start()

@app.on_event("shutdown")
def shutdown_event():
    requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_rel/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))
    #requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_rel/stop", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

