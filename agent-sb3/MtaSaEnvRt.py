from rtgym import RealTimeGymInterface
import gymnasium as gym
import numpy as np
from queue import Queue
import requests
import os

action_queue = Queue(maxsize=1)
observation_queue = Queue(maxsize=1)

class MtaSaEnvRt(RealTimeGymInterface):
    def __init__(self):
        self.observation_space = gym.spaces.Dict({
            "health": gym.spaces.Box(low=0, high=1000, shape=(1,), dtype=np.float64),
            "position": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            "destination": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            "next_checkpoint": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            "rotation": gym.spaces.Box(low=0, high=360, shape=(3,), dtype=np.float64),
            "velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float64),
            "angular_velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float64),
            "lidar": gym.spaces.Box(low=0, high=100, shape=(25,), dtype=np.float64),
        })

    def get_observation_space(self):
        # convert self.observation_space to gym.spaces.Tuple
        #return self.observation_space
        return gym.spaces.Tuple((
            gym.spaces.utils.flatten_space(self.observation_space),
        ))
        return gym.spaces.Tuple((
            self.observation_space["health"],
            self.observation_space["position"],
            self.observation_space["destination"],
            self.observation_space["next_checkpoint"],
            self.observation_space["rotation"],
            self.observation_space["velocity"],
            self.observation_space["angular_velocity"],
            self.observation_space["lidar"],
        ))

    def get_action_space(self):
        return gym.spaces.Box(low=-1.0, high=1.0, shape=(3,), dtype=np.float32)

    def get_default_action(self):
        return np.array([0.0, 0.0, 0.0], dtype=np.float32)

    def send_control(self, control):
        try:
            action_queue.put(control, timeout=5)
        except:
            print("Failed to put action in queue")

    def reset(self, seed=None, options=None):
        while not observation_queue.empty():
            observation_queue.get()
        while not action_queue.empty():
            action_queue.get()
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl/call/resetEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))
        observation, _, _, _ = self.get_obs_rew_terminated_info()
        return observation, {}

    def get_obs_rew_terminated_info(self):
        try:
            observation = observation_queue.get(timeout=5)
        except:
            print("Failed to get observation from queue")
            return None, None, True, {}
        reward = float(observation["reward"])
        done = bool(observation["done"] == 1)
        observation.pop("reward")
        observation.pop("done")
        #return observation, reward, done, {}
        #return observation, reward, done, {}
        flattened_observation = gym.spaces.utils.flatten(self.observation_space, observation)
        #flattened_observation = gym.spaces.utils.unflatten(self.get_observation_space(), flattened_observation)
        #print(observation)
        #print(type(flattened_observation), flattened_observation)
        return [flattened_observation], reward, done, {}

    def wait(self):
        pass # maybe pause the game
