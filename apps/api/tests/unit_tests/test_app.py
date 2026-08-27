"""Unit tests for the FastAPI wrapper. No network, no API key."""

from importlib import import_module
from typing import Any

import pytest
from fastapi.testclient import TestClient

# import_module, not `from agent import graph` — that name is the compiled graph.
app_module = import_module("agent.app")
graph_module = import_module("agent.graph")


class StubModel:
    """Minimal stand-in for ChatOpenAI: echoes the last user message."""

    async def ainvoke(self, messages: list[dict[str, str]]) -> Any:
        class Reply:
            content = f"stubbed reply to: {messages[-1]['content']}"

        return Reply()


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> TestClient:
    monkeypatch.setattr(graph_module, "build_model", lambda: StubModel())
    return TestClient(app_module.app)


def test_healthz(client: TestClient) -> None:
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.json() == {"ok": True}


def test_chat_returns_reply(client: TestClient) -> None:
    res = client.post("/chat", json={"messages": [{"role": "user", "content": "hi"}]})
    assert res.status_code == 200
    assert res.json() == {"reply": "stubbed reply to: hi"}


def test_chat_rejects_empty_messages(client: TestClient) -> None:
    assert client.post("/chat", json={"messages": []}).status_code == 422


def test_chat_missing_key_fails_loudly(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    with pytest.raises(RuntimeError, match="OPENROUTER_API_KEY"):
        graph_module.build_model()
