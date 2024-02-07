import gymnasium as gym
import numpy as np
from queue import Queue
import requests
import os

class MtaSaEnv(gym.Env):
    metadata = {'render.modes': ['human']}
    def __init__(self):
        # Actions -> accelerate/reverse, right/left, brake
        self.action_space = gym.spaces.Box(low=-1.0, high=1.0, shape=(3,), dtype=np.float32)
        # Observations
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

        # queues
        self.action_queue = Queue()
        #self.action_queue.put(np.array([0, 0, 0]))
        self.observation_queue = Queue()

    def _get_obs(self):
        observation = self.observation_queue.get()
        reward = float(observation["reward"])
        done = bool(observation["done"] == 1)
        observation.pop("reward")
        observation.pop("done")
        return observation, reward, done

    def put_observation(self, observation):
        self.observation_queue.put(observation)

    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl/call/resetEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))
        while not self.observation_queue.empty():
            self.observation_queue.get()
        while not self.action_queue.empty():
            self.action_queue.get()
        self.done = False
        self.reward = 0
        self.action_queue.put(np.array([0, 0, 0]))
        self.action_queue.put(np.array([0, 0, 0]))

        observation, reward, done = self._get_obs()
        return observation, {}

    def step(self, action):
        self.action_queue.put(action)
        observation, reward, done = self._get_obs()
        return observation, reward, done, False, {}

    def render(self, mode='human'):
        pass

    def close(self):
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

    def compute_reward(self, achieved_goal, desired_goal, info):
        reward = 0.
        return reward

    def compute_terminated(self, achieved_goal, desired_goal, info):
        return False

    def compute_truncated(self, achieved_goal, desired_goal, info):
        return False
