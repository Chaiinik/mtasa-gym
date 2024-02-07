import gymnasium as gym
import numpy as np
from queue import Queue
import requests
import os

class MtaSaEnvRelative(gym.Env):
    metadata = {'render.modes': ['human']}
    def __init__(self):
        # Actions -> accelerate/reverse, right/left, brake
        self.action_space = gym.spaces.Box(low=-1.0, high=1.0, shape=(2,), dtype=np.float32)
        # Observations
        self.observation_space = gym.spaces.Dict({
            "health": gym.spaces.Box(low=0, high=1000, shape=(1,), dtype=np.float32),
            #"position": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float32),
            #"destination": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float32),
            #"next_checkpoint": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float32),
            "rotation": gym.spaces.Box(low=0, high=360, shape=(3,), dtype=np.float32),
            "velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float32),
            "angular_velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float32),
            "lidar": gym.spaces.Box(low=0, high=100, shape=(1*25,), dtype=np.float32),
            #"lidar_materialType": gym.spaces.Box(low=0, high=15, shape=(3*49,), dtype=np.int16),
            #"wheel_control": gym.spaces.Box(low=-1, high=1, shape=(2,), dtype=np.float32),
            "wheel_on_ground": gym.spaces.Box(low=0, high=1, shape=(4,), dtype=np.int8),
            #"wheel_friction": gym.spaces.Box(low=0, high=3, shape=(4,), dtype=np.int16),
            "in_water": gym.spaces.Box(low=0, high=1, shape=(1,), dtype=np.int8),
            "waypoints": gym.spaces.Box(low=-3000, high=3000, shape=(3*5,), dtype=np.float32),
        })

        # queues
        self.action_queue = Queue(maxsize=1)
        self.observation_queue = Queue(maxsize=1)
        self.agent_id = 0

    def reset(self, seed=None, options=None):
        self.agent_id += 1
        args = {
            "agent_id": self.agent_id,
        }
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_rel/call/resetEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")), json=args)
        self.action_queue = Queue()
        self.observation_queue = Queue()
        self.action_queue.put(np.array([0., 0.]))

        obs = self.observation_queue.get()
        obs.pop("reward")
        #print("obs: {}".format(obs))
        info = {}
        return obs, info

    def step(self, action):
        self.action_queue.put(action)
        obs = self.observation_queue.get()
        #info = { "health": obs["observation"]["health"][0] }
        #info = { "in_water": obs["observation"]["in_water"][0] }
        #reward = self.compute_reward(achieved_goal, desired_goal, info)
        #reward = -np.linalg.norm(achieved_goal - desired_goal, axis=-1)
        #print("reward: {}".format(reward))
        #done = self.compute_terminated(achieved_goal, desired_goal, info)
        #truncated = self.compute_truncated(achieved_goal, desired_goal, info)
        #print("reward: {}, done: {}, truncated: {}".format(reward, done, truncated))
        #reward = 0
        #reward -= np.abs(obs["health"][0] - 1000)
        #distance = np.linalg.norm(obs["waypoints"])
        #reward -= distance
        #print("reward: {}".format(reward))
        #done = distance < 5 or obs["waypoints"] == 0 or int(obs["reward"]) == 0
        #done = obs["in_water"][0] == 1 or obs["health"][0] < 300 or int(obs["reward"]) == 0 # last checkpoint was reached
        done = int(obs["reward"]) == 0 # last checkpoint was reached
        truncated = False
        info = {}
        reward = obs["reward"]
        obs.pop("reward")
        #print("reward: {}".format(reward))
        #print("obs: {}".format(obs))
        return obs, float(reward), bool(done), bool(truncated), info

    def render(self, mode='human'):
        pass

    def close(self):
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_rel/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

    def app_put_observation(self, agent_id, observation):
        #print(agent_id, observation)
        if agent_id == self.agent_id:
            self.observation_queue.put(observation)

    def app_get_action(self, agent_id):
        if agent_id == self.agent_id:
            action = self.action_queue.get()
            return action
        else:
            #print("Wrong agent_id (expected {}, got {})".format(self.agent_id, agent_id))
            return np.array([0., 0.])
