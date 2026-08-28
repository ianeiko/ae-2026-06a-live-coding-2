Wire the LangGraph backend to the Next.js frontend and prove it works on localhost. No deployment in this issue — that's #2.

## Backend — `apps/api`

Add deps to `pyproject.toml`: `fastapi`, `uvicorn[standard]`, `langchain-openai`.

**`src/agent/graph.py`** — replace the template's `changeme` passthrough with a real LLM call:

- State: `messages: list[dict]` (each `{"role": "user"|"assistant", "content": str}`). Stateless — the client sends the whole history every request.
- One node, `call_model`: builds `ChatOpenAI(model=OPENROUTER_MODEL, base_url=OPENROUTER_BASE_URL, api_key=OPENROUTER_API_KEY)`, invokes it with the messages, appends the reply.
- Keep the graph compiled at module level so `langgraph.json` still resolves.

**`src/agent/app.py`** — FastAPI app wrapping the graph:

- `GET /healthz` → `{"ok": true}`. No LLM call, no key needed.
- `POST /chat`, body `{"messages": [{"role": "user", "content": "hi"}]}` → `{"reply": "..."}`. Calls `graph.ainvoke`, returns the last assistant message.
- `CORSMiddleware` with `allow_origins=["*"]` — fine here because the endpoint is public and unauthenticated; add a comment saying it should be pinned in a real app.
- Binds `0.0.0.0:$PORT`, default `8000`.

**`Dockerfile`** — `python:3.12-slim`, install with `uv`, `CMD` runs uvicorn on `$PORT`. Cloud Build uses this in #2; nobody runs `docker build` locally.

Config comes from env vars only (`apps/api/.env` locally): `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_MODEL`, `PORT`. No key literals, no defaults that hide a missing key — fail loudly at first request.

## Frontend — `apps/web`

Strip `app/page.tsx` to one client component: message list, text input, send button.

- `POST ${process.env.NEXT_PUBLIC_API_URL}/chat` with the full message array; append the reply.
- Local state only. No auth, no persistence, no streaming, no extra deps.
- Show a pending state while in flight and the error text on failure — a silent dead button is the failure mode students hit most.

Delete the starter boilerplate (Next/Vercel SVGs in `public/`, unused styles).

## Tests

Replace `tests/integration_tests/test_graph.py` (it asserts the old `changeme` shape). Keep it small:

- unit: `POST /chat` with a stubbed model returns the reply shape; `GET /healthz` returns 200.
- integration (marked, real key): one round trip through `/chat` returns non-empty text.

## Acceptance — all four must pass

1. `cd apps/api && uv run pytest tests/unit_tests` — green.
2. Backend up (`uv run uvicorn agent.app:app --port 8000`), then:
   ```bash
   curl localhost:8000/healthz
   curl -X POST localhost:8000/chat -H 'content-type: application/json' \
     -d '{"messages":[{"role":"user","content":"say hi in three words"}]}'
   ```
   Second one returns real model text, not a canned string.
3. Both servers up (8000 + 3000). Using the `/browse` skill: load `localhost:3000`, send a message, confirm the reply renders. Not curl — the common failures (`undefined/chat`, CORS, build-time `NEXT_PUBLIC_*`) only show in a browser.
4. `cd apps/web && npm run build` — clean, no type or lint errors.

Update README §8 (Run it locally) if the contract here differs from what it documents. Commit when all four pass.
