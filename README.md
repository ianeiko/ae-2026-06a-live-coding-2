# Publishing a LangGraph App — Setup

Tutorial repo: FastAPI + LangGraph backend on Cloud Run (`apps/api`), Next.js frontend on Vercel (`apps/web`).
See [plan.md](plan.md) for the full plan.

Prerequisites (assumed installed, not covered here): GitHub account + `git`, Claude Code.

## 1. Install CLIs

| Tool | Docs | Install (macOS) |
| --- | --- | --- |
| Node.js 20+ | https://nodejs.org | `brew install node` |
| uv (Python) | https://docs.astral.sh/uv/ | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| gcloud | https://cloud.google.com/sdk/docs/install | `brew install --cask google-cloud-sdk` |
| Vercel CLI | https://vercel.com/docs/cli | `npm i -g vercel` |
| agents-cli | https://github.com/google/agents-cli | `uvx google-agents-cli setup` |
| LangGraph CLI | https://docs.langchain.com/langgraph-platform/cli | no install — `uvx --from "langgraph-cli[inmem]" langgraph` |

Verify:

```bash
node -v && uv --version && gcloud --version && vercel --version
```

## 2. Google Cloud setup

### 2.1 Log in

```bash
gcloud auth login                      # your gcloud CLI identity
gcloud auth application-default login  # ADC — used by client libraries
```

Two separate credentials. The CLI uses the first; anything running locally
against Google APIs uses the second.

### 2.2 Pick a project

```bash
gcloud projects list                   # find an existing one
gcloud projects create <PROJECT_ID>    # or make a new one (must be globally unique)
gcloud config set project <PROJECT_ID>
```

If you see:

```
WARNING: Your active project does not match the quota project in your local
Application Default Credentials file.
```

your ADC is still pointing at an older project. Fix it — the project ID is a
required argument:

```bash
gcloud auth application-default set-quota-project <PROJECT_ID>
```

### 2.3 Enable billing

Cloud Run and Cloud Build refuse to run without a billing account attached.

```bash
gcloud billing accounts list
gcloud billing projects link <PROJECT_ID> --billing-account=<ACCOUNT_ID>
gcloud billing projects describe <PROJECT_ID>   # expect billingEnabled: true
```

New Google Cloud accounts get free credits; this tutorial's usage sits inside
Cloud Run's free tier. https://cloud.google.com/free

### 2.4 Enable the APIs

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com
```

- **Cloud Run** — runs the container.
- **Artifact Registry** — stores the built image.
- **Cloud Build** — builds the image from source, so you never run `docker build`.

Verify:

```bash
gcloud services list --enabled | grep -E "run|artifact|cloudbuild"
```

### 2.5 Set a default region

Saves passing `--region` on every command. Pick one near you.

```bash
gcloud config set run/region europe-west1
gcloud run regions list        # all options
```

### 2.6 Sanity check

```bash
gcloud config list             # account + project + run/region
```

### Deploy command (for reference — Claude runs this later)

From `apps/api`, source deploy: no Dockerfile build step on your machine.

```bash
gcloud run deploy langgraph-api \
  --source . \
  --allow-unauthenticated \
  --set-env-vars "OPENROUTER_API_KEY=$OPENROUTER_API_KEY,OPENROUTER_MODEL=$OPENROUTER_MODEL"
```

`--allow-unauthenticated` makes the service publicly reachable so the Vercel
frontend can call it. The command prints the service URL — that becomes the
frontend's `NEXT_PUBLIC_API_URL`.

Useful follow-ups:

```bash
gcloud run services list
gcloud run services describe langgraph-api --format='value(status.url)'
gcloud run services logs read langgraph-api --limit 50
```

Docs: https://cloud.google.com/run/docs · https://cloud.google.com/sdk/gcloud/reference/run

## 3. Vercel login

```bash
vercel login
```

## 4. Claude Code plugins / skills

These are what let Claude drive the platforms itself instead of you copy-pasting
commands.

### Vercel — official plugin

Ships skills *and* an MCP server (deployments, logs, env vars, domains).

```bash
claude plugin marketplace add anthropics/claude-plugins-official   # usually already present
claude plugin install vercel@claude-plugins-official
claude plugin list                                                 # expect: vercel ✔ enabled
```

Or interactively inside Claude Code: `/plugin` → search `vercel` → install.

Gives Claude `/vercel:deploy`, `/vercel:env`, `/vercel:status` and the
`vercel-cli`, `deployments-cicd`, `nextjs` skills.

### Google Cloud — `agents-cli` skills

There is no Cloud Run plugin in the Claude Code marketplace (only GCS, BigQuery,
AlloyDB, Firebase). Google ships its own skills bundle instead:

```bash
uvx google-agents-cli setup      # installs the CLI + skills into Claude Code
```

Skills only, no CLI: `npx skills add google/agents-cli`

Repo: https://github.com/google/agents-cli · Docs: https://google.github.io/agents-cli/

Installs seven skills; the one that matters here is
**`google-agents-cli-deploy`** — Cloud Run vs Agent Runtime vs GKE, secrets,
service accounts, CI/CD, scaling and session config, plus curl/load-test recipes
per target.

Then authenticate:

```bash
agents-cli login
agents-cli login --status
```

**Caveat — it is ADK-shaped.** `agents-cli scaffold` and `agents-cli deploy`
assume a Google ADK project layout. Our backend is LangGraph, so we use the
skills for their Cloud Run *knowledge* and let Claude deploy with plain
`gcloud run deploy --source .` (§2). Cloud Run takes any container, so this is
fine — just don't expect `agents-cli deploy` to work on `apps/api` unscaffolded.

### Who actually does the deploying

| Tool | Deploys? | Role in this tutorial |
| --- | --- | --- |
| `gcloud` | **yes** | The backend deploy. Cloud Build builds, Cloud Run runs. |
| `agents-cli` skills | no (`agents-cli deploy` needs an ADK project) | Teaches Claude Cloud Run practice: service accounts, secrets, rollback, scaling |
| `vercel` (plugin + CLI) | **yes** | The frontend deploy |

One deploy command per app, nothing else in the loop.

## 5. Keys

Copy `.env.example` to `.env` (gitignored) and fill in:

```bash
cp .env.example .env
```

| Variable | Notes |
| --- | --- |
| `OPENROUTER_API_KEY` | https://openrouter.ai/keys |
| `OPENROUTER_BASE_URL` | `https://openrouter.ai/api/v1` — leave as is |
| `OPENROUTER_MODEL` | required, no default — use `anthropic/claude-haiku-4.5` (cheap, fast) |
| `PORT` | local only; Cloud Run injects its own |

The frontend has its own env file, `apps/web/.env.local` (§7):
`NEXT_PUBLIC_API_URL` — `http://localhost:8000` until the backend is deployed,
then the Cloud Run URL.

Model slugs must match https://openrouter.ai/models exactly — a wrong slug fails
at request time, not at startup. OpenRouter is OpenAI-compatible, so the backend
uses an OpenAI-style client pointed at `OPENROUTER_BASE_URL`.

One key covers every model, so students can swap providers by editing one line.

## 6. Scaffold the backend from a LangGraph template

Don't start from an empty folder. The LangGraph CLI ships templates:

```bash
uvx --from "langgraph-cli[inmem]" langgraph new apps/api \
  --template new-langgraph-project-python
```

Templates available: `new-langgraph-project-python` (minimal — use this),
`agent-python`, `deep-agent-python`, plus `-js` variants.

You get `langgraph.json`, `src/agent/graph.py` with a compiled one-node graph,
`pyproject.toml` + `uv.lock`, and tests.

### Verify it runs locally

Before any deployment work, confirm the scaffold actually works:

```bash
cd apps/api
cp .env.example .env
uvx --from "langgraph-cli[inmem]" langgraph dev --no-browser
```

In a second terminal:

```bash
curl localhost:2024/ok
# {"ok":true}

curl -X POST localhost:2024/runs/wait \
  -H 'content-type: application/json' \
  -d '{"assistant_id":"agent","input":{"changeme":"hello"}}'
# {"changeme":"output from call_model. Configured with None"}
```

Two good responses = the graph compiled and ran. Interactive API docs at
`localhost:2024/docs`. Ctrl-C to stop.

**No LangSmith key and no LangGraph licence are required.** The dev server logs
`No license key or control plane API key set` and works anyway — those matter
only for LangSmith tracing and LangSmith Deployment, neither of which we use.
`LANGSMITH_PROJECT` in `.env.example` is optional; ignore it.

This dev server is not what we deploy. Claude wraps the same graph in a small
FastAPI app (`POST /chat`, `GET /healthz`, binding `0.0.0.0:$PORT`) with a
`python:3.12-slim` Dockerfile that installs with `uv` — that is what Cloud Run
builds in §2.

## 7. Scaffold the frontend

No template needed — it is one page calling one endpoint.

```bash
npx create-next-app@latest apps/web --ts --app --tailwind --eslint \
  --no-src-dir --use-npm --yes
```

Then strip the boilerplate page down to a message list, an input, and a fetch to
`process.env.NEXT_PUBLIC_API_URL`. Claude does this in §9.

### Verify it runs locally

```bash
cd apps/web
echo 'NEXT_PUBLIC_API_URL=http://localhost:8000' > .env.local
npm run dev
```

Open http://localhost:3000. Before §9 that is the Next.js starter page; after
§9 it is the chat UI. Either way, all you can check here is that the page
serves — the backend round trip is the next block.

```bash
# in a second terminal
curl -s -o /dev/null -w '%{http_code}\n' localhost:3000
# 200
```

Common failures: port 3000 already in use (Next picks 3001 and says so — use
that URL), or a stale `node_modules` after switching Node versions (`rm -rf
node_modules && npm install`).

### Verify it talks to the backend (after §9)

Once Claude has built the chat page, run **both** servers — backend on 8000,
frontend on 3000 — and check the full path:

```bash
# 1. backend reachable on its own
curl localhost:8000/healthz
# {"ok":true}

curl -X POST localhost:8000/chat \
  -H 'content-type: application/json' \
  -d '{"messages":[{"role":"user","content":"say hi in three words"}]}'
# {"reply":"Hi there friend"}
```

`/chat` takes the **whole** history every request — the backend is stateless, so
`{"message":"hello"}` is a 422. `/healthz` makes no model call and needs no key,
so it is the first thing to try when the container starts but `/chat` 500s.

Then in the browser at http://localhost:3000, send a message and confirm a reply
appears. If the page loads but sending does nothing, open DevTools → Network:

| What you see | Cause | Fix |
| --- | --- | --- |
| Request to `undefined/chat` | `NEXT_PUBLIC_API_URL` not set | it must be in `apps/web/.env.local`, then restart `npm run dev` — `NEXT_PUBLIC_*` is baked in at build time |
| CORS error | backend has no CORS middleware | FastAPI needs `CORSMiddleware`; we allow `*` because the endpoint is public and every Vercel preview has its own origin — pin it in a real app |
| 404 on `/chat` | route mismatch | backend path must be exactly `POST /chat` |
| 500 naming a missing env var | key or model slug not set | the backend reads env only — check the root `.env`, then restart it |
| Connection refused | backend not running | start it first |

After deploying, repeat this against production: set `NEXT_PUBLIC_API_URL` to the
Cloud Run URL in the Vercel dashboard (or `vercel env add`), redeploy the
frontend, and send one message on the live site.

## 8. The spec issues

Already written — both live in this repo as `ISSUE-1.md` / `ISSUE-2.md` and on
GitHub as issues [#1](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/1)
and [#2](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/2), so the
spec is in the clone as well as in the tracker. Nothing to create; read them,
then go to §9.

```bash
gh issue list
gh issue view 1
```

- **#1** (closed) — FastAPI wrapper, real LLM call in the graph node, chat UI,
  Dockerfile, tests. Acceptance is four local checks, one of them a real browser.
- **#2** (open) — Cloud Run + Vercel, six prompts, verified end to end. Blocked
  by #1.

Two issues, not one: the wiring is worth confirming locally before anything is
deployed, and a single issue makes "we're happy with local, now ship it" an
invisible step. #2 is marked blocked by #1, so it can't be picked up early.

<details>
<summary>How they were created (if you are rebuilding this repo from scratch)</summary>

```bash
gh issue create --title "Wire the LangGraph backend to the Next.js frontend (local)" \
  --body-file ISSUE-1.md
gh issue create --title "Deploy to Cloud Run + Vercel and verify end to end" \
  --body-file ISSUE-2.md

ID=$(gh api repos/<owner>/<repo>/issues/1 --jq .id)
gh api --method POST repos/<owner>/<repo>/issues/2/dependencies/blocked_by \
  -F issue_id=$ID
```

</details>

## 9. Let Claude build it

```bash
claude
```

Prompt one — local:

> Implement GitHub issue #1 end to end. Don't deploy anything. Commit when all four acceptance checks pass.

[Issue #1](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/1) is
**done** — `apps/api` and `apps/web` in this repo are its output. §10 is how you
run and check it. Then look at it yourself: both servers up, send a message in
the browser. Only once that feels right, prompt two — deploy:

> Implement GitHub issue #2. Work through its six steps in order, using the gcloud and vercel CLIs and the installed skills. Stop and tell me if a check fails.

Issue #2 is a list of prompts on purpose — you can also paste them one at a
time and watch each check pass. Same commands either way.

## 10. Run it locally

The output of [issue #1](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/1):
a FastAPI wrapper around the graph (`POST /chat`, `GET /healthz`) and a one-page
chat UI. Two terminals, because both servers run in the foreground.

**Terminal 1 — backend on 8000.** It reads the keys from the repo-root `.env`
(§5), so there is nothing to export:

```bash
cd apps/api
uv run uvicorn agent.app:app --port 8000 --reload
# INFO: Uvicorn running on http://127.0.0.1:8000
```

**Terminal 2 — frontend on 3000:**

```bash
cd apps/web
npm run dev
# - Local: http://localhost:3000
```

### The three checks

Run them in this order — each one rules out a layer, so the first failure tells
you where to look.

```bash
# 1. server up at all — no model call, no key needed
curl localhost:8000/healthz
# {"ok":true}

# 2. the key and the model slug work
curl -X POST localhost:8000/chat \
  -H 'content-type: application/json' \
  -d '{"messages":[{"role":"user","content":"say hi in three words"}]}'
# {"reply":"Hi there friend"}
```

3. **The browser** — open http://localhost:3000, type a message, hit Send, watch
   DevTools → Network for `POST localhost:8000/chat`. Do not skip this for curl:
   `undefined/chat`, CORS, and build-time `NEXT_PUBLIC_*` failures only show up
   here. The §7 table lists what each one looks like.

`/chat` takes the **whole** history every request — the backend keeps no state,
so the browser resends every turn. A 500 names the missing env var in its body,
so read the response, not just the status code.

| What you see | Cause | Fix |
| --- | --- | --- |
| Next.js says `Local: http://localhost:8000` | you sourced the root `.env`, and its `PORT=8000` leaked into `npm run dev` | start the frontend in a clean shell, or `env -u PORT npm run dev` |
| 500 naming `OPENROUTER_*` | key or model slug missing | fill it in the root `.env`, restart the backend |
| 404 from OpenRouter | model slug isn't a real one | copy it exactly from https://openrouter.ai/models |
| `LangSmithError: 403` in test output | stale `LANGSMITH_API_KEY` in `apps/api/.env` | noise, not a failure — set `LANGCHAIN_TRACING_V2=false` there |

### The tests

```bash
cd apps/api
uv run pytest tests/unit_tests   # stubbed model, no key needed
uv run pytest -m integration     # one real round trip, needs the key
cd ../web && npm run build       # types + lint + build
```

Once all of this is green, #2 (Cloud Run + Vercel) is unblocked.
