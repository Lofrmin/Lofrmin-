import json
import os
from urllib.request import Request, urlopen


STRATEGIES = {"patrol", "cutoff", "ambush", "guard"}
INSTRUCTIONS = (
    "You control the Debt Collector in a two-phase space station maze. Choose a tactic for the next loop "
    "using only the sensor observations in the user JSON. gates[0] and gates[1] count detected uses of "
    "the two phase gates. sprint_heard is 1 if a sprint was heard through a corner. "
    "patrol investigates normally; cutoff watches a chosen gate; ambush deploys at a chosen gate; "
    "guard watches the route back to the audit desk. Prefer patrol with no clues, and adapt to habits "
    "without treating them as certainty. Return only a JSON object with strategy (one of those four) "
    "and gate (integer 0 or 1). Example: {\"strategy\":\"cutoff\",\"gate\":1}."
)


def choose(observations, fallback):
    key = os.environ.get("DEEPSEEK_API_KEY", "").strip()
    if not key:
        return fallback

    data = json.dumps({
        "model": os.environ.get("DEEPSEEK_MODEL", "deepseek-flash"),
        "thinking": {"type": "disabled"},
        "response_format": {"type": "json_object"},
        "max_tokens": 96,
        "messages": [
            {"role": "system", "content": INSTRUCTIONS},
            {"role": "user", "content": json.dumps({
                "gates": observations["gates"], "sprint_heard": observations["sprint_heard"],
            })},
        ],
    }).encode("utf-8")
    request = Request(
        "https://api.deepseek.com/chat/completions", data=data,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=2.5) as response:
            completion = json.loads(response.read(16384))
        decision = json.loads(completion["choices"][0]["message"]["content"])
        strategy, gate = decision["strategy"], decision["gate"]
        if isinstance(strategy, str) and strategy in STRATEGIES and type(gate) is int and gate in (0, 1):
            return {"lap": fallback["lap"], "strategy": strategy, "gate": gate, "source": "deepseek"}
    except (OSError, ValueError, TypeError, KeyError, IndexError):
        pass
    return fallback
