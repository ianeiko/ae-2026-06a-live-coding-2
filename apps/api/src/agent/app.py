"""FastAPI wrapper around the LangGraph chat graph."""

from __future__ import annotations

import os
from pathlib import Path
from typing import List, Literal

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from agent.graph import graph

# Repo-root .env first — it is the documented home for the backend keys
# (README §5). apps/api/.env is the LangGraph template's own file and only fills
# in whatever the root one leaves unset. Neither overrides real env vars, so
# Cloud Run's injected config always wins.
_API_DIR = Path(__file__).resolve().parents[2]
load_dotenv(_API_DIR.parent.parent / ".env")
load_dotenv(_API_DIR / ".env")

app = FastAPI(title="LangGraph Chat API")

# Wide open on purpose: this endpoint is public and unauthenticated, and the
# frontend's origin changes per Vercel preview deploy. In a real app, pin this
# to the known frontend origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class Message(BaseModel):
    """One chat turn."""

    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    """Full history, sent every request — the backend keeps no state."""

    messages: List[Message] = Field(min_length=1)


class ChatResponse(BaseModel):
    """The model's reply."""

    reply: str


# `/healthz` is a reserved path on Google's frontend: on Cloud Run it is answered
# with a Google 404 and never reaches the container. `/health` is the probe that
# works everywhere; `/healthz` stays for local runs and other platforms.
@app.get("/health")
@app.get("/healthz")
async def health() -> dict[str, bool]:
    """Liveness probe. No LLM call, no API key needed."""
    return {"ok": True}


@app.post("/chat")
async def chat(req: ChatRequest) -> ChatResponse:
    """Run one turn through the graph and return the last assistant message."""
    try:
        result = await graph.ainvoke(
            {"messages": [m.model_dump() for m in req.messages]}
        )
    except RuntimeError as exc:
        # Missing config. 500 with the reason in the body, so the frontend's
        # error text names the missing var instead of a bare status code.
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    return ChatResponse(reply=result["messages"][-1]["content"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
