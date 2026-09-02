# Publishing a LangGraph App

A chat app you run locally, then put live: FastAPI + LangGraph backend on Google
Cloud Run (`apps/api`), Next.js frontend on Vercel (`apps/web`). The code is
already written. You set up two accounts and the CLIs; Claude runs it and deploys it.

## TL;DR

1. **Accounts** (§1) — Google Cloud billing, Vercel, a LangSmith key.
2. **Fork** (§2) — fork this repo, clone your fork.
3. **Tools** (§3) — paste one prompt into Claude, or run the commands.
   `bash scripts/check.sh` tells you when you're done.
4. **Hand off** (§4) — paste two prompts. Claude does the rest.

## 1. Accounts

Browser only. Keep the LangSmith key handy — §3 pastes it, together with the
OpenRouter key you were given.

| Sign up for | Where | You leave with |
| --- | --- | --- |
| Google Cloud | https://console.cloud.google.com → **Billing** → **Create billing account** | a billing account (card required; free credits cover this tutorial) |
| Vercel | https://vercel.com/signup → **Continue with GitHub** | an account |
| LangSmith | https://smith.langchain.com → Settings → **API keys** | an API key (free) |

## 2. Fork and clone

Click **Fork** at the top of this page, then:

```bash
git clone https://github.com/<you>/ae-2026-06a-live-coding-2 && cd ae-2026-06a-live-coding-2
```

## 3. Tools

Open `claude` in the repo and accept the trust dialog (that installs the two
plugins the deploy needs). Then pick one.

### The lazy way

Paste this into Claude:

> Set this machine up for this repo. Run `bash scripts/check.sh` and fix every MISSING line until it prints `all set`; README §3 and Appendix A say what each step is. Install tools yourself (Homebrew, npm, uv). Logins and anything that asks for a password are mine: give me the command, I'll run it in another terminal and say "done". Google Cloud: create a project named `langgraph-chat-<4 random digits>`, link my billing account (ask which if I have several), enable the three APIs, set run/region to europe-west1. Copy `apps/api/.env.example` to `apps/api/.env` and tell me which two values to paste where — never ask me to paste secrets into this chat. Re-run the check after each fix.

### The manual way

```bash
brew install --cask google-cloud-sdk && npm i -g vercel            # needs Node and uv — Appendix A
gcloud auth login && vercel login
gcloud projects create <PROJECT_ID> && gcloud config set project <PROJECT_ID>
gcloud billing accounts list
gcloud billing projects link <PROJECT_ID> --billing-account=<ACCOUNT_ID>
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
gcloud config set run/region europe-west1
cp apps/api/.env.example apps/api/.env                             # paste OPENROUTER_API_KEY and LANGSMITH_API_KEY
```

Either way, finish with:

```bash
bash scripts/check.sh      # all set — go to §4
```

## 4. Hand off to Claude

Open `claude` in the repo. Prompt one — local:

> Read ISSUE-1.md and implement it end to end. Don't deploy anything. Commit when all four acceptance checks pass.

Open http://localhost:3000 and send a message (Appendix B if it doesn't work).
Then prompt two — live:

> Read ISSUE-2.md and implement it. Work through its six steps in order, using the gcloud and vercel CLIs and the installed skills. Stop and tell me if a check fails.

Claude records your URLs here when ISSUE-2 is done:

| Service | URL | Deployed with |
| --- | --- | --- |
| backend (`apps/api`) | https://langgraph-api-116820946223.europe-west1.run.app | `gcloud run deploy` |
| frontend (`apps/web`) | https://langgraph-chat-web.vercel.app | `vercel --prod` |

## Appendix A — what else should be on your machine

The lazy prompt installs these; the manual way assumes them.

| Tool | Install (macOS) |
| --- | --- |
| Homebrew | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| git, Node.js 20+, uv | `brew install git node uv` |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |

## Appendix B — run it locally

Two terminals:

```bash
cd apps/api && uv run uvicorn agent.app:app --port 8000 --reload   # terminal 1
cd apps/web && npm run dev                                          # terminal 2
```

Then http://localhost:3000. DevTools → Network should show `POST localhost:8000/chat`.

| What you see | Cause | Fix |
| --- | --- | --- |
| Request to `undefined/chat` | `NEXT_PUBLIC_API_URL` unset | it lives in `apps/web/.env`; restart `npm run dev` |
| 500 naming `OPENROUTER_*` | key or model slug missing | fix `apps/api/.env`, restart the backend |
| 404 from OpenRouter | model slug isn't real | copy it exactly from https://openrouter.ai/models |
| Connection refused | backend not running | start terminal 1 first |

Tests: `cd apps/api && uv run pytest tests/unit_tests`, `uv run pytest -m integration`
(one real call), `cd apps/web && npm run build`.

## Appendix C — later

Pull fixes from this repo into your fork:

```bash
git remote add upstream https://github.com/ianeiko/ae-2026-06a-live-coding-2.git
git pull upstream main
```

Once ISSUE-2 has linked Vercel to your fork, every push to `main` redeploys the
frontend. The backend redeploys with `gcloud run deploy` (see ISSUE-2.md).
