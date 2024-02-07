from stable_baselines3 import SAC
import MtaSaEnv
import uvicorn
import threading
from gymnasium.wrappers import FlattenObservation, TimeLimit
from stable_baselines3.common.env_checker import check_env
import requests
import time
import json
import numpy as np

app = FastAPI()
env = MtaSaEnv.MtaSaEnv()
env = FlattenObservation(MtaSaEnv.MtaSaEnv())
env = TimeLimit(env, max_episode_steps=1000)
model = SAC("MlpPolicy", env, verbose=1)
#try:
#    model = model.load("model", env=env)
#except:
#    print("No model found")

@app.get("/")
def read_root():
    return {"Hello": "World"}


step_times = []
@app.post("/step")
async def step(observation: list = Depends(get_observation)):
    global env
    start = time.time()
    env.unwrapped.put_observation(observation)
    action = env.unwrapped.action_queue.get()
    step_times.append(time.time() - start)
    return [action.tolist()]

class BackgroundTasks(threading.Thread):
    def run(self,*args,**kwargs):
        check_env(env)
        print("Environment checked")
        model.learn(total_timesteps=10_000)
        model.save("model")
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

