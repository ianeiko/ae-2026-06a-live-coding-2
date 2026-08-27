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
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=anthropic/claude-sonnet-4.5
```

Get a key: https://openrouter.ai/keys · models: https://openrouter.ai/models

The backend calls OpenRouter through its OpenAI-compatible endpoint
(`https://openrouter.ai/api/v1`) from LangGraph.

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

### About Docker — read this

`langgraph dockerfile Dockerfile` generates a Dockerfile, **but it builds on
`langchain/langgraph-api`**, the LangGraph Platform server image. That image
expects Postgres *and* Redis and a LangSmith licence — three services, stateful,
wrong shape for this tutorial.

So: keep the template's graph, and give it a thin FastAPI wrapper with our own
Dockerfile (`python:3.12-slim` + `uv`, one stateless container). That is exactly
what `plan.md` specifies, and what the issue in §8 asks Claude to build:

- `POST /chat` → invokes the compiled graph, returns the reply
- `GET /healthz` → returns `{"status":"ok"}`
- reads `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `PORT` from the environment
- binds `0.0.0.0:$PORT` (Cloud Run injects `PORT`)

## 7. Scaffold the frontend

No template needed — it is one page calling one endpoint.

```bash
npx create-next-app@latest apps/web --ts --app --tailwind --eslint \
  --no-src-dir --use-npm --yes
```

Then strip the boilerplate page down to a message list, an input, and a fetch to
`process.env.NEXT_PUBLIC_API_URL`. Claude does this in §9.

## 8. Create the spec issue

```bash
gh issue create --title "Implement LangGraph chat app" --body-file ISSUE.md
```

## 9. Let Claude build it

```bash
claude
```

Prompt:

> Implement GitHub issue #1 end to end. Use gcloud and vercel CLIs and the installed skills to deploy. Commit when done.
