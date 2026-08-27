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

Inside Claude Code:

```
/plugin
```

Install the Google Cloud and Vercel plugins so Claude can drive deployments directly.

## 5. Keys

Copy `.env.example` to `.env` (gitignored) and fill in:

```bash
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=anthropic/claude-sonnet-4.5
```

Get a key: https://openrouter.ai/keys · models: https://openrouter.ai/models

The backend calls OpenRouter through its OpenAI-compatible endpoint
(`https://openrouter.ai/api/v1`) from LangGraph.

## 6. Create the spec issue

```bash
gh issue create --title "Implement LangGraph chat app" --body-file ISSUE.md
```

## 7. Let Claude build it

```bash
claude
```

Prompt:

> Implement GitHub issue #1 end to end. Use gcloud and vercel CLIs and the installed skills to deploy. Commit when done.
