# Publishing a LangGraph App — Setup

FastAPI + LangGraph backend on Cloud Run (`apps/api`), Next.js frontend on
Vercel (`apps/web`). Full plan in [plan.md](plan.md).

## TL;DR

You do the setup only — logins, keys, two scaffolds, two GitHub issues. Claude
does the rest from two prompts: [#1](ISSUE-1.md) wires and tests it locally,
[#2](ISSUE-2.md) deploys and verifies it live.

```bash
bash scripts/check.sh   # tells you which step below is still missing
claude                  # then paste the two prompts from §5
```

## Prerequisites

Accounts, not tools — the tools are §1.

| Need | Where |
| --- | --- |
| GitHub account | https://github.com |
| Claude Code, logged in | https://docs.anthropic.com/en/docs/claude-code |
| Google Cloud account **with a billing account** | https://console.cloud.google.com/billing — free credits cover this tutorial |
| Vercel account | https://vercel.com/signup |
| OpenRouter API key | https://openrouter.ai/keys |
| LangSmith API key (free tier) | https://smith.langchain.com → Settings → API keys |

## 0. Fork and clone

Fork, don't clone. The fork is a repo you own — you push to it, Vercel deploys
from it — and GitHub keeps the link to this one so you can pull later fixes.

```bash
gh auth login
gh repo fork ianeiko/ae-2026-06a-live-coding-2 --clone
cd ae-2026-06a-live-coding-2
git remote -v      # origin = your fork, upstream = this repo
```

Forks don't copy issues; §5 creates #1/#2 in yours. Later, to pick up upstream
changes:

```bash
git pull upstream main
```

Already have a clone, or used "Use this template"? Point `origin` at your own
empty repo and add upstream by hand — same result, one link fewer for free:

```bash
gh repo create <you>/ae-2026-06a-live-coding-2 --private --source . --remote origin --push
git remote add upstream https://github.com/ianeiko/ae-2026-06a-live-coding-2.git
```

**Auto-deploys.** Vercel: once #2 has linked the project to your fork with Root
Directory `apps/web`, every push to `main` builds and deploys — nothing else to
set up. Cloud Run: stays a manual `gcloud run deploy` (#2); if you want pushes to
redeploy the backend too, Cloud Run → service → *Set up continuous deployment*
points Cloud Build at `apps/api` in your fork.

## Quick check

```bash
bash scripts/check.sh
```

Prints `ok` / `MISSING` for every step in §0–§4 and names the section that
fixes it. Ends with `all set — go to §5` when nothing is missing.

## 1. Install CLIs

| Tool | Install (macOS) | Docs |
| --- | --- | --- |
| Node.js 20+ | `brew install node` | https://nodejs.org |
| uv | `curl -LsSf https://astral.sh/uv/install.sh \| sh` | https://docs.astral.sh/uv/ |
| gcloud | `brew install --cask google-cloud-sdk` | https://cloud.google.com/sdk/docs/install |
| Vercel CLI | `npm i -g vercel` | https://vercel.com/docs/cli |
| gh | `brew install gh` | https://cli.github.com |

LangGraph CLI needs no install — it runs via `uvx` in §2.3.

## 2. Google Cloud — backend (`apps/api`)

### 2.1 Account, project, billing, APIs

```bash
gcloud auth login                                          # CLI identity
gcloud auth application-default login                      # ADC, for client libraries
gcloud projects create <PROJECT_ID>                        # or pick one: gcloud projects list
gcloud config set project <PROJECT_ID>
gcloud auth application-default set-quota-project <PROJECT_ID>
gcloud billing accounts list
gcloud billing projects link <PROJECT_ID> --billing-account=<ACCOUNT_ID>
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
gcloud config set run/region europe-west1                  # any: gcloud run regions list
```

Billing is required — Cloud Run and Cloud Build refuse to run without it. The
three APIs are the container runtime, the image store, and the builder (so you
never run `docker build`).

### 2.2 Claude skills for Cloud Run

```bash
uvx google-agents-cli setup                            # Google's Cloud Run skills
agents-cli login
```

`agents-cli deploy` itself only works on Google ADK projects; here Claude uses
its `google-agents-cli-deploy` skill for Cloud Run know-how and deploys with
plain `gcloud run deploy`.

### 2.3 Scaffold the backend

```bash
uvx --from "langgraph-cli[inmem]" langgraph new apps/api --template new-langgraph-project-python
```

A template, not an empty folder: `langgraph.json`, a compiled one-node graph,
`pyproject.toml` and tests. Issue #1 turns it into the FastAPI app.

## 3. Vercel — frontend (`apps/web`)

### 3.1 Login and Claude plugin

```bash
vercel login
claude plugin install vercel@claude-plugins-official   # /vercel:deploy, /vercel:env, MCP server
```

The plugin is what lets Claude drive Vercel instead of you copy-pasting
commands.

### 3.2 Scaffold the frontend

```bash
npx create-next-app@latest apps/web --ts --app --tailwind --eslint --no-src-dir --use-npm --yes
```

A starter page; issue #1 turns it into the chat UI.

## 4. Keys

One backend env file — it feeds both the local server and the Cloud Run
deploy — plus one line for the frontend:

```bash
cp apps/api/.env.example apps/api/.env      # fill in OPENROUTER_API_KEY, LANGSMITH_API_KEY
echo 'NEXT_PUBLIC_API_URL=http://localhost:8000' > apps/web/.env.local
```

If you scaffolded fresh in §2.3 the template's `.env.example` lacks the
OpenRouter vars — paste in the six from
[this repo's copy](apps/api/.env.example) instead.

| Variable | Notes |
| --- | --- |
| `OPENROUTER_API_KEY` | https://openrouter.ai/keys — one key covers every model |
| `OPENROUTER_BASE_URL` | `https://openrouter.ai/api/v1`, leave as is |
| `OPENROUTER_MODEL` | copy a slug exactly from https://openrouter.ai/models; `anthropic/claude-haiku-4.5` is cheap and fast |
| `LANGCHAIN_TRACING_V2` / `LANGSMITH_API_KEY` / `LANGSMITH_PROJECT` | traces in https://smith.langchain.com; omit the key and it still runs, untraced |
| `NEXT_PUBLIC_API_URL` | `http://localhost:8000` now; the Cloud Run URL later (issue #2 sets it on Vercel) |

Both files are gitignored. Run `bash scripts/check.sh` — it should now say
`all set`.

## 5. Hand off to Claude

The spec is two GitHub issues. Upstream has them
([#1](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/1),
[#2](https://github.com/ianeiko/ae-2026-06a-live-coding-2/issues/2)) but your
fork doesn't — create them from the files, in your fork:

```bash
gh repo set-default    # pick your fork, not ianeiko/…
gh issue create --title "Wire the LangGraph backend to the Next.js frontend (local)" --body-file ISSUE-1.md
gh issue create --title "Deploy to Cloud Run + Vercel and verify end to end" --body-file ISSUE-2.md
```

Then `claude`, and two prompts. First, local:

> Implement GitHub issue #1 end to end. Don't deploy anything. Commit when all four acceptance checks pass.

Look at the result yourself (§6) — both servers up, a message sent in the
browser. Once that feels right, deploy:

> Implement GitHub issue #2. Work through its six steps in order, using the gcloud and vercel CLIs and the installed skills. Stop and tell me if a check fails.

#2 is a list of prompts on purpose — you can also paste them one at a time
and watch each check pass.

## 6. Run it locally

Two terminals; both servers run in the foreground.

```bash
cd apps/api && uv run uvicorn agent.app:app --port 8000 --reload   # terminal 1
cd apps/web && npm run dev                                          # terminal 2
```

Then http://localhost:3000 — send a message, watch DevTools → Network for
`POST localhost:8000/chat`. The browser is the check that matters: `undefined/chat`, CORS
and baked-in `NEXT_PUBLIC_*` failures never show in curl.

| What you see | Cause | Fix |
| --- | --- | --- |
| Request to `undefined/chat` | `NEXT_PUBLIC_API_URL` unset | put it in `apps/web/.env.local`, restart `npm run dev` |
| 500 naming `OPENROUTER_*` | key or model slug missing | fix `apps/api/.env`, restart the backend |
| 404 from OpenRouter | model slug isn't real | copy it exactly from https://openrouter.ai/models |
| Connection refused | backend not running | start terminal 1 first |

Tests: `cd apps/api && uv run pytest tests/unit_tests` (no key needed),
`uv run pytest -m integration` (one real call), `cd apps/web && npm run build`.

## 7. Live

Output of issue #2. Deploy commands and failure modes live in
[ISSUE-2.md](ISSUE-2.md).

| Service | URL | Deployed with |
| --- | --- | --- |
| backend (`apps/api`) | https://langgraph-api-116820946223.europe-west1.run.app | `gcloud run deploy` |
| frontend (`apps/web`) | https://langgraph-chat-web.vercel.app | `vercel --prod` |
