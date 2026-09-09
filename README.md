# Publishing a LangGraph App

A chat app you run locally, then put live: FastAPI + LangGraph backend on Google
Cloud Run (`apps/api`), Next.js frontend on Vercel (`apps/web`). You start from an
empty `apps/`: three prompts have Claude scaffold both templates, write the app, and
deploy it. You set up two accounts and the CLIs.

## TL;DR

1. **Accounts** (§1) — Google Cloud billing, Vercel, a LangSmith key.
2. **Fork** (§2) — fork this repo, clone your fork.
3. **Tools** (§3) — paste one prompt into Claude, or run the commands.
   `bash scripts/check.sh` tells you when you're done.
4. **Hand off** (§4) — paste three prompts. Claude does the rest.

## 1. Accounts

Browser only. Keep the LangSmith key handy — §3 pastes it into `.env`, together
with the OpenRouter key you were given.

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

Open `claude` in the repo and accept the trust dialog. That reads the repo's
`.claude/settings.json` and installs the two plugins ISSUE-2 deploys with —
`vercel` (`/vercel:deploy`, `/vercel:env`, `/vercel:status`) and
`google-cloud-developer` (the `cloud-run-basics` skill) — plus the repo's own
`.claude/skills/`. Say yes when it offers to install them; `scripts/check.sh`
fails until both are enabled. Then pick one of the two paths below. Commands are
macOS — on Windows use Appendix D instead.

### The lazy way

Paste this into Claude:

> Set this machine up for this repo. Run `bash scripts/check.sh` and fix every MISSING line until it prints `all set`; README §3 and Appendix A say what each step is. Install tools yourself (Homebrew, npm, uv) and the two plugins (`vercel@claude-plugins-official`, `google-cloud-developer@google-plugins`). Logins and anything that asks for a password are mine: give me the command, I'll run it in another terminal and say "done". Google Cloud: create a project named `langgraph-chat-<4 random digits>`, link my billing account (ask which if I have several), enable the three APIs, set run/region to europe-west1. Copy `.env.example` to `.env` and tell me which two values to paste where — never ask me to paste secrets into this chat. Don't scaffold or write any app code yet, that's §4. Re-run the check after each fix.

### The manual way

```bash
brew install --cask google-cloud-sdk && npm i -g vercel            # needs Node and uv — Appendix A; Windows: Appendix D
claude plugin install vercel@claude-plugins-official                # skip both if the trust dialog already did it
claude plugin marketplace add google/skills && claude plugin install google-cloud-developer@google-plugins
gcloud auth login && vercel login
gcloud projects create <PROJECT_ID> && gcloud config set project <PROJECT_ID>
gcloud billing accounts list
gcloud billing projects link <PROJECT_ID> --billing-account=<ACCOUNT_ID>
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
gcloud config set run/region europe-west1
cp .env.example .env                                               # paste OPENROUTER_API_KEY and LANGSMITH_API_KEY
```

Either way, finish with:

```bash
bash scripts/check.sh      # all set — go to §4
```

`todo` lines about `apps/` are expected here: `apps/` is empty until §4 fills it.
Only `MISSING` lines block you.

## 4. Hand off to Claude

Open `claude` in the repo. Prompt zero — scaffold the two templates:

> Read ISSUE-0.md and implement it. Scaffold only — no app logic, no deploy. Commit when all four acceptance checks pass.

Prompt one — local:

> Read ISSUE-1.md and implement it end to end. Don't deploy anything. Commit when all four acceptance checks pass.

Open http://localhost:3000 and send a message (Appendix B if it doesn't work).
Then prompt two — live:

> Read ISSUE-2.md and implement it. Work through its six steps in order, using the gcloud and vercel CLIs and the installed skills. Stop and tell me if a check fails.

Claude records your URLs here when ISSUE-2 is done:

| Service | URL | Deployed with |
| --- | --- | --- |
| backend (`apps/api`) | _(filled in by ISSUE-2)_ | `gcloud run deploy` |
| frontend (`apps/web`) | _(filled in by ISSUE-2)_ | `vercel --prod` |

## Appendix A — what else should be on your machine

The lazy prompt installs these; the manual way assumes them. Windows equivalents
are in Appendix D.

| Tool | Install (macOS) |
| --- | --- |
| Homebrew | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| git, Node.js 20+, uv | `brew install git node uv` |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Claude plugins | `claude plugin install vercel@claude-plugins-official`, then `claude plugin marketplace add google/skills && claude plugin install google-cloud-developer@google-plugins` — `claude plugin list` shows both enabled |

## Appendix B — run it locally

Both apps exist only after ISSUE-0, and the chat works only after ISSUE-1. Two terminals:

```bash
cd apps/api && uv run uvicorn agent.app:app --port 8000 --reload   # terminal 1
cd apps/web && npm run dev                                          # terminal 2
```

Then http://localhost:3000. DevTools → Network should show `POST localhost:8000/chat`.
(On Windows run both in Git Bash — Appendix D.)

| What you see | Cause | Fix |
| --- | --- | --- |
| Request to `undefined/chat` | `NEXT_PUBLIC_API_URL` unset | it lives in `apps/web/.env`, written by ISSUE-0; restart `npm run dev` |
| 500 naming `OPENROUTER_*` | key or model slug missing | fix `apps/api/.env` (ISSUE-0 copies it from root `.env`), restart the backend |
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

## Appendix D — Windows

Everything here assumes a **bash** shell, so get one first: install
[Git for Windows](https://git-scm.com/download/win) and use **Git Bash** for every
command in this README (or use WSL and follow the macOS path inside it). PowerShell
and `cmd` won't run `scripts/check.sh`.

Install the tools (PowerShell, once — `winget` ships with Windows 10/11):

| Tool | Install (Windows) |
| --- | --- |
| git (+ Git Bash) | `winget install Git.Git` |
| Node.js 20+ | `winget install OpenJS.NodeJS.LTS` |
| uv | `winget install astral-sh.uv` |
| gcloud CLI | `winget install Google.CloudSDK` |
| Vercel CLI | `npm i -g vercel` |
| Claude Code | `npm i -g @anthropic-ai/claude-code` |

The two Claude plugins install the same way on Windows (`claude plugin install ...`
from Git Bash) — see Appendix A.

Then reopen Git Bash (so the new tools are on `PATH`) and continue with §3 — every
`gcloud` / `vercel` / `cp` / `bash scripts/check.sh` line works there unchanged.
The only replacement is the first line of the manual way: the two `brew install`
packages come from the `winget` table above instead.

Windows-only snags:

| What you see | Fix |
| --- | --- |
| `bash: scripts/check.sh: No such file` | you're in PowerShell or `cmd` — reopen Git Bash |
| `gcloud: command not found` in Git Bash | reopen Git Bash after installing; if it persists, restart Windows |
| `python3: command not found` | check.sh falls back to `python`; install it with `winget install Python.Python.3.12` if neither exists (only the OpenRouter credit line needs it) |
| CRLF warnings from git | harmless — `git config core.autocrlf input` quiets them |
