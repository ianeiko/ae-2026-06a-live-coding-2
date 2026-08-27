"""Integration test: one real round trip through /chat. Needs a real key."""

import os

import pytest
from fastapi.testclient import TestClient

from agent.app import app

# Marked so it can be selected or excluded by name: `-m integration`.
pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not os.environ.get("OPENROUTER_API_KEY"),
        reason="OPENROUTER_API_KEY not set",
    ),
]


def test_chat_real_model() -> None:
    client = TestClient(app)
    res = client.post(
        "/chat",
        json={"messages": [{"role": "user", "content": "say hi in three words"}]},
    )
    assert res.status_code == 200
    assert res.json()["reply"].strip()
