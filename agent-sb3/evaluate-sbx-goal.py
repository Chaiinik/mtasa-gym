from fastapi import FastAPI, Depends, Request
from MtaSaEnvGoal import MtaSaEnvGoal
import threading
from gymnasium.wrappers import TimeLimit
import requests
import json
from sbx import DroQ
import time
import os
import numpy as np

SPEED = 1

env = MtaSaEnvGoal()
env = TimeLimit(env, max_episode_steps=30*25*SPEED)
app = FastAPI()
model = DroQ.load("model-droq-goal2", env=env, verbose=1)

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
        print("Evaluating model")
        steps = []
        time_needed = []
        rewards = []
        for i in range(10):
            print(f"Episode {i+1}/10")
            start = time.time()
            episode_steps = 0
            episode_reward = 0
            observation, _ = env.reset()
            while True:
                action, _states = model.predict(observation, deterministic=True)
                observation, reward, done, truncaed, info = env.step(action)
                episode_steps += 1
                episode_reward += reward
                if done or truncaed:
                    break
            end = time.time()
            time_needed.append(end-start)
            steps.append(episode_steps)
            rewards.append(episode_reward)
            print(f"Time needed: {end-start}s, Steps: {episode_steps}, Reward: {episode_reward}")
        print(f"Average time needed: {np.mean(time_needed)}s +- {np.std(time_needed)}")
        print(f"Average steps: {np.mean(steps)} +- {np.std(steps)}")
        print(f"Average rewards: {np.mean(rewards)} +- {np.std(rewards)}")


@app.on_event("startup")
def startup_event():
    BackgroundTasks().start()

@app.on_event("shutdown")
def shutdown_event():
    requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_goal/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

