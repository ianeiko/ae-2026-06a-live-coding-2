"""LangGraph chat graph: one node, one real LLM call through OpenRouter.

Stateless — the client sends the whole message history on every request.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, List

from langchain_openai import ChatOpenAI
from langgraph.graph import StateGraph

Message = Dict[str, str]


@dataclass
class State:
    """Conversation state: the full message history.

    Each message is `{"role": "user" | "assistant", "content": str}`.
    """

    messages: List[Message] = field(default_factory=list)


def build_model() -> ChatOpenAI:
    """Build the chat model from env vars.

    No defaults for the key or the model — a missing value fails loudly here
    rather than silently sending requests nowhere.
    """
    missing = [
        name
        for name in ("OPENROUTER_API_KEY", "OPENROUTER_BASE_URL", "OPENROUTER_MODEL")
        if not os.environ.get(name)
    ]
    if missing:
        raise RuntimeError(f"Missing required env vars: {', '.join(missing)}")

    return ChatOpenAI(
        model=os.environ["OPENROUTER_MODEL"],
        base_url=os.environ["OPENROUTER_BASE_URL"],
        api_key=os.environ["OPENROUTER_API_KEY"],
    )


def _text(content: Any) -> str:
    """Flatten message content to plain text (some models return content blocks)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(
            part.get("text", "") if isinstance(part, dict) else str(part)
            for part in content
        )
    return str(content)


async def call_model(state: State) -> Dict[str, Any]:
    """Send the history to the model and append its reply."""
    reply = await build_model().ainvoke(state.messages)
    return {
        "messages": [
            *state.messages,
            {"role": "assistant", "content": _text(reply.content)},
        ]
    }


# Compiled at module level so langgraph.json can resolve it.
graph = (
    StateGraph(State)
    .add_node(call_model)
    .add_edge("__start__", "call_model")
    .compile(name="Chat Graph")
)
