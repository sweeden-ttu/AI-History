import json
import random
import time
from pathlib import Path


DEFAULT_STRATEGIES = ["frequency", "alpha", "balanced"]


def _initial_state(strategies: list[str]) -> dict:
    return {
        "strategies": {
            strategy: {"trials": 0, "value": 0.0, "last_reward": 0.0}
            for strategy in strategies
        },
        "updated_at": time.time(),
    }


def load_policy_state(state_path: Path, strategies: list[str] | None = None) -> dict:
    strategy_list = strategies or DEFAULT_STRATEGIES
    if not state_path.exists():
        return _initial_state(strategy_list)
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return _initial_state(strategy_list)

    if "strategies" not in state:
        return _initial_state(strategy_list)
    for strategy in strategy_list:
        state["strategies"].setdefault(strategy, {"trials": 0, "value": 0.0, "last_reward": 0.0})
    return state


def save_policy_state(state_path: Path, state: dict) -> None:
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state["updated_at"] = time.time()
    state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def select_strategy(state: dict, epsilon: float) -> str:
    strategies = list(state["strategies"].keys())
    if not strategies:
        return "frequency"
    if random.random() < max(0.0, min(1.0, epsilon)):
        return random.choice(strategies)
    return max(strategies, key=lambda s: float(state["strategies"][s]["value"]))


def anti_ghost_penalty(tokens: list[str]) -> float:
    seen = set()
    repeats = 0
    long_identifiers = 0
    for token in tokens:
        if token in seen:
            repeats += 1
        seen.add(token)
        if len(token) > 40:
            long_identifiers += 1
    return 0.05 * repeats + 0.02 * long_identifiers


def update_reward(
    state: dict,
    strategy: str,
    compile_ok: bool,
    smoke_ok: bool,
    elapsed_seconds: float,
    ttl_lambda: float,
    vitamin: float,
    anti_ghost: float,
) -> dict:
    strategy_info = state["strategies"].setdefault(
        strategy, {"trials": 0, "value": 0.0, "last_reward": 0.0}
    )
    base_reward = 0.0
    if compile_ok:
        base_reward += 1.0
    if smoke_ok:
        base_reward += 1.0
    ttl_penalty = max(0.0, ttl_lambda) * max(0.0, elapsed_seconds)
    reward = base_reward - ttl_penalty - max(0.0, anti_ghost)

    trials = int(strategy_info["trials"]) + 1
    old_value = float(strategy_info["value"])
    step = 1.0 / trials
    exploration_boost = min(0.5, max(0.0, vitamin) * 0.05)
    new_value = (1.0 - step) * old_value + step * reward + exploration_boost
    strategy_info["trials"] = trials
    strategy_info["value"] = new_value
    strategy_info["last_reward"] = reward
    return state
