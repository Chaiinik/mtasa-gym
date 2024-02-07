import gymnasium as gym
import numpy as np
from queue import Queue
import requests
import time
import os

class MtaSaEnvGoal(gym.Env):
    metadata = {'render.modes': ['human']}
    def __init__(self, reward_type="dense"):
        self.reward_type = reward_type
        # Actions -> accelerate/reverse, right/left, brake
        self.action_space = gym.spaces.Box(low=-1.0, high=1.0, shape=(2,), dtype=np.float32)
        # Observations
        self.observation_space_observation = gym.spaces.Dict({
            "health": gym.spaces.Box(low=0, high=1000-250, shape=(1,), dtype=np.float64),
            #"position": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            #"destination": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            #"next_checkpoint": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64),
            "rotation": gym.spaces.Box(low=0, high=360, shape=(3,), dtype=np.float64),
            "velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float64),
            "angular_velocity": gym.spaces.Box(low=-10, high=10, shape=(3,), dtype=np.float64),
            "lidar": gym.spaces.Box(low=0, high=100, shape=(1*48,), dtype=np.float64),
            #"lidar_materialType": gym.spaces.Box(low=0, high=15, shape=(3*49,), dtype=np.int16),
            #"wheel_control": gym.spaces.Box(low=-1, high=1, shape=(2,), dtype=np.float64),
            "wheel_on_ground": gym.spaces.Box(low=0, high=1, shape=(4,), dtype=np.int8),
            #"wheel_friction": gym.spaces.Box(low=0, high=3, shape=(4,), dtype=np.int16),
            "in_water": gym.spaces.Box(low=0, high=1, shape=(1,), dtype=np.int8),
            "collision": gym.spaces.Box(low=0, high=1000, shape=(1,), dtype=np.float64),
        })
        self.observation_space = gym.spaces.Dict({
            "observation": gym.spaces.flatten_space(self.observation_space_observation),
            "desired_goal": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64), # 1000, destination
            "achieved_goal": gym.spaces.Box(low=-3000, high=3000, shape=(3,), dtype=np.float64), # health, current position
        })

        # queues
        self.action_queue = Queue(maxsize=1)
        self.observation_queue = Queue(maxsize=1)
        self.agent_id = 0

    def reset(self, seed=None, options=None):
        try:
            self.agent_id += 1
            print("reset: agent_id = {}".format(self.agent_id))
            self.action_queue = Queue(maxsize=1)
            self.observation_queue = Queue(maxsize=1)
            args = {
                "agent_id": self.agent_id,
            }
            requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_goal/call/resetEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")), json=args)
            #print("reset: request sent")

            #self.action_queue.put(np.array([0., 0.]))
            #print("reset: waiting for observation")
            obs = self.observation_queue.get()
            #print("reset: observation received")

            observation = obs["observation"]
            observation = gym.spaces.flatten(self.observation_space_observation, observation)
            info = { "in_water": obs["observation"]["in_water"][0], "health": obs["observation"]["health"][0] } #, "collision": obs["observation"]["collision"][0] }
            desired_goal = np.array(obs["desired_goal"])
            achieved_goal = np.array(obs["achieved_goal"])
            new_observation = {
                "observation": observation,
                "desired_goal": desired_goal,
                "achieved_goal": achieved_goal,
            }
            #print("reset done")
            return new_observation, info
        except Exception as e:
            print(e)
            return self.reset(seed, options)

    def step(self, action):
        #start = time.time()
        if self.action_queue.full():
            self.action_queue.get()
            print("action_queue full")
        self.action_queue.put(action)
        #end = time.time()
        #print("step: action_queue.put took {} seconds".format(end - start))
        obs = self.observation_queue.get()
        #end2 = time.time()
        #print("step: observation_queue.get took {} seconds".format(end2 - end))
        #print(f"{action} --> {obs['observation']['wheel_control']}")
        observation = obs["observation"]
        observation = gym.spaces.flatten(self.observation_space_observation, observation)
        desired_goal = np.array(obs["desired_goal"])
        achieved_goal = np.array(obs["achieved_goal"])
        info = { "in_water": obs["observation"]["in_water"][0], "health": obs["observation"]["health"][0] } #, "collision": obs["observation"]["collision"][0] }
        reward = self.compute_reward(achieved_goal, desired_goal, info)
        done = self.compute_terminated(achieved_goal, desired_goal, info)
        truncated = self.compute_truncated(achieved_goal, desired_goal, info)
        new_observation = {
            "observation": observation,
            "desired_goal": desired_goal,
            "achieved_goal": achieved_goal,
        }
        #print("reward: {}, done: {}, truncated: {}".format(reward, done, truncated))
        return new_observation, float(reward), bool(done), bool(truncated), info

    def render(self, mode='human'):
        pass

    def close(self):
        requests.post(f"http://{os.getenv('MTA_SERVER_HOST')}:{os.getenv('MTA_SERVER_PORT')}/fhs_rl_goal/call/stopEnvironment", auth=(os.getenv("MTA_SERVER_ADMIN_USERNAME"), os.getenv("MTA_SERVER_ADMIN_PASSWORD")))

    def app_put_observation(self, agent_id, observation):
        #print(agent_id, observation)
        if agent_id == self.agent_id:
            if self.observation_queue.full():
                self.observation_queue.get()
                print("observation_queue full")
            self.observation_queue.put(observation, timeout=10)
        else:
            print("Wrong agent_id (expected {}, got {})".format(self.agent_id, agent_id))

    def app_get_action(self, agent_id):
        if agent_id == self.agent_id:
            action = self.action_queue.get(timeout=10)
            #action = np.array([1.0, -0.5])
            return action
        else:
            print("Wrong agent_id (expected {}, got {})".format(self.agent_id, agent_id))
            return np.array([0., 0.])

    def compute_reward(self, achieved_goal, desired_goal, info):
        if self.reward_type == "sparse":
            distance = np.linalg.norm(achieved_goal - desired_goal, axis=-1)
            reward = np.where(distance < 1, 1., 0.)
            return reward
        else:
            reward = -np.linalg.norm(achieved_goal - desired_goal, axis=-1)
            return reward

    def compute_terminated(self, achieved_goal, desired_goal, info):
        #achieved_health = achieved_goal[0]
        #desired_health = desired_goal[0]
        #achieved_position = achieved_goal[1:]
        #desired_position = desired_goal[1:]

        distance = np.linalg.norm(achieved_goal - desired_goal, axis=-1) < 1
        under_water = info["in_water"] == 1
        health = info["health"] < 1
        return np.logical_or(distance, np.logical_or(under_water, health))

    def compute_truncated(self, achieved_goal, desired_goal, info):
        return False
