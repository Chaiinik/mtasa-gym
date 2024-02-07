import argparse
import gymnasium as gym
import os

import ray
from ray.rllib.env.policy_server_input import PolicyServerInput
from ray.rllib.algorithms.sac import SACConfig
from ray.rllib.algorithms.ppo import PPOConfig
SERVER_ADDRESS = "0.0.0.0"
SERVER_PORT = 8081
CHECKPOINT_FILE = "last_checkpoint.out"
no_restore = False
checkpoint_freq = 100

ray.init(dashboard_host="0.0.0.0", configure_logging=False, log_to_driver=False)

# `InputReader` generator (returns None if no input reader is needed on
# the respective worker).
def _input(ioctx):
    # We are remote worker or we are local worker with num_workers=0:
    # Create a PolicyServerInput.
    if ioctx.worker_index > 0 or ioctx.worker.num_workers == 0:
        return PolicyServerInput(
            ioctx,
            SERVER_ADDRESS,
            SERVER_PORT + ioctx.worker_index - (1 if ioctx.worker_index > 0 else 0),
        )
    # No InputReader (PolicyServerInput) needed.
    else:
        return None

config = (
    #SACConfig()
    PPOConfig()
    .rollouts(num_rollout_workers=0, enable_connectors=False)
    .resources(num_gpus=1)
    #.framework("torch")
    .environment(
        env=None,
        observation_space=gym.spaces.Box(float("-inf"), float("inf"), (45,)),
        action_space=gym.spaces.Box(-1.0, 1.0, (3,)),
    )
    .training(train_batch_size=256, _enable_learner_api=False)
    .rl_module(_enable_rl_module_api=False)
    # Use the `PolicyServerInput` to generate experiences.
    .offline_data(
        input_=lambda ioctx: PolicyServerInput(ioctx, SERVER_ADDRESS, SERVER_PORT)
    )
    #.offline_data(input_=_input)
    # Disable OPE, since the rollouts are coming from online clients.
    .evaluation(off_policy_estimation_methods={})
)

# Create the Algorithm used for Policy serving.
algo = config.build()

# Attempt to restore from checkpoint if possible.
checkpoint_path = CHECKPOINT_FILE
if no_restore and os.path.exists(checkpoint_path):
    checkpoint_path = open(checkpoint_path).read()
    print("Restoring from checkpoint path", checkpoint_path)
    algo.restore(checkpoint_path)

# Serving and training loop.
count = 0
while True:
    # Calls to train() will block on the configured `input` in the Algorithm
    # config above (PolicyServerInput).
    print("algo.train: ", algo.train())
    if count % checkpoint_freq == 0:
        print("Saving learning progress to checkpoint file.")
        checkpoint = algo.save().checkpoint
        # Write the latest checkpoint location to CHECKPOINT_FILE,
        # so we can pick up from the latest one after a server re-start.
        with open(checkpoint_path, "w") as f:
            f.write(checkpoint.path)
    count += 1
