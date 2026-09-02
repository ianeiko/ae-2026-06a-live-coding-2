# Publishing a LangGraph App

A chat app you run locally, then put live: FastAPI + LangGraph backend on Google
Cloud Run (`apps/api`), Next.js frontend on Vercel (`apps/web`). The code is
already written. You set up accounts and tools; Claude runs it and deploys it.

## TL;DR

1. **Accounts** (§1) — six sign-ups in the browser.
2. **Fork** (§2) — fork this repo, clone your fork.
3. **Tools** (§3) — paste one prompt into Claude Code, or run the commands.
   `bash scripts/check.sh` tells you when you're done.
4. **Hand off** (§4) — create two GitHub issues, paste two prompts. Claude does the rest.

## 1. Accounts

Browser only. Keep the two API keys handy — §3 pastes them.

| Sign up for | Where | You leave with |
| --- | --- | --- |
| GitHub | https://github.com | an account |
| Claude | https://claude.ai — Pro/Max, or an API account | a login for Claude Code |
| Google Cloud | https://console.cloud.google.com → **Billing** → **Create billing account** | a billing account (card required; free credits cover this tutorial) |
| Vercel | https://vercel.com/signup → **Continue with GitHub** | an account |
| OpenRouter | https://openrouter.ai/keys → **Create key** | an API key (credits are provided) |
| LangSmith | https://smith.langchain.com → Settings → **API keys** | an API key (free) |

## 2. Fork and clone

Click **Fork** at the top of this page, then:

```bash
git clone https://github.com/<you>/ae-2026-06a-live-coding-2 && cd ae-2026-06a-live-coding-2
```

The fork is a repo you own: you push to it, Vercel deploys from it, §4 files the
issues in it.

## 3. Tools

Install Claude Code, open it in the repo, log in, and accept the trust dialog —
that installs the Google Cloud plugin for you:

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude
```

Then pick one.

### The lazy way

Paste this into Claude:

> Set this machine up for this repo. Run `bash scripts/check.sh` and fix every MISSING line until it prints `all set`; README §3 and Appendix A say what each step is. Install tools yourself (Homebrew, npm, uv). Logins and anything that asks for a password are mine: give me the command, I'll run it in another terminal and say "done". Google Cloud: create a project named `langgraph-chat-<4 random digits>`, link my billing account (ask which if I have several), enable the three APIs, set run/region to europe-west1. Env files: copy the examples into place and tell me which two values to paste where — never ask me to paste secrets into this chat. Re-run the check after each fix.

### The manual way

```bash
brew install --cask google-cloud-sdk && npm i -g vercel            # needs Node, gh, uv — Appendix A
gh auth login && gcloud auth login && vercel login
gcloud projects create <PROJECT_ID> && gcloud config set project <PROJECT_ID>
gcloud billing accounts list
gcloud billing projects link <PROJECT_ID> --billing-account=<ACCOUNT_ID>
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
gcloud config set run/region europe-west1
claude plugin install vercel@claude-plugins-official
cp apps/api/.env.example apps/api/.env                             # paste OPENROUTER_API_KEY and LANGSMITH_API_KEY
echo 'NEXT_PUBLIC_API_URL=http://localhost:8000' > apps/web/.env.local
```

Either way, finish with:

```bash
bash scripts/check.sh      # all set — go to §4
```

## 4. Hand off to Claude

File the two issues in your fork, then open Claude:

```bash
gh repo set-default        # pick your fork
gh issue create --title "Wire the LangGraph backend to the Next.js frontend (local)" --body-file ISSUE-1.md
gh issue create --title "Deploy to Cloud Run + Vercel and verify end to end" --body-file ISSUE-2.md
claude
```

Prompt one — local:

> Implement GitHub issue #1 end to end. Don't deploy anything. Commit when all four acceptance checks pass.

Open http://localhost:3000 and send a message (Appendix B if it doesn't work).
Then prompt two — live:

> Implement GitHub issue #2. Work through its six steps in order, using the gcloud and vercel CLIs and the installed skills. Stop and tell me if a check fails.

Claude records your URLs here when #2 is done:

| Service | URL | Deployed with |
| --- | --- | --- |
| backend (`apps/api`) | https://langgraph-api-116820946223.europe-west1.run.app | `gcloud run deploy` |
| frontend (`apps/web`) | https://langgraph-chat-web.vercel.app | `vercel --prod` |

## Appendix A — what else should be on your machine

The lazy prompt installs these; the manual way assumes them.

| Tool | Install (macOS) |
| --- | --- |
| Homebrew | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| git, gh | `brew install git gh` |
| Node.js 20+ | `brew install node` |
| uv | `brew install uv` |

## Appendix B — run it locally

Two terminals:

```bash
cd apps/api && uv run uvicorn agent.app:app --port 8000 --reload   # terminal 1
cd apps/web && npm run dev                                          # terminal 2
```

Then http://localhost:3000. DevTools → Network should show `POST localhost:8000/chat`.

| What you see | Cause | Fix |
| --- | --- | --- |
| Request to `undefined/chat` | `NEXT_PUBLIC_API_URL` unset | put it in `apps/web/.env.local`, restart `npm run dev` |
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

Once #2 has linked Vercel to your fork, every push to `main` redeploys the
frontend. The backend redeploys with `gcloud run deploy` (see ISSUE-2.md).
