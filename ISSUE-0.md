Scaffold the two apps from their upstream templates. Nothing but `README.md`, the
`ISSUE-*.md` files and `scripts/` exists yet — `apps/` is empty. No app logic here:
this issue only lands the untouched templates plus their env files, so ISSUE-1.md
has something to edit.

## 1. Backend template — `apps/api`

```bash
uvx --from "langgraph-cli[inmem]" langgraph new apps/api --template new-langgraph-project-python
```

Lands `pyproject.toml`, `langgraph.json`, `src/agent/graph.py` (the `changeme`
passthrough ISSUE-1 replaces), `tests/`, `uv.lock`. Don't touch any of it here.

## 2. Frontend template — `apps/web`

```bash
npx create-next-app@latest apps/web --ts --tailwind --eslint --app --no-src-dir --use-npm --yes
rm -rf apps/web/.git
```

The flags matter: App Router, TypeScript, Tailwind, no `src/` — ISSUE-1 and
ISSUE-2 both assume `apps/web/app/page.tsx`. `create-next-app` initialises its own
git repo inside `apps/web`; delete it or the outer repo tracks nothing in there and
the Vercel deploy in ISSUE-2 uploads an empty directory.

## 3. Env files

Root `.env` already holds the real keys (README §3). Split it:

- `apps/api/.env` — all six backend vars: `OPENROUTER_API_KEY`,
  `OPENROUTER_BASE_URL`, `OPENROUTER_MODEL`, `LANGCHAIN_TRACING_V2`,
  `LANGSMITH_API_KEY`, `LANGSMITH_PROJECT`. This becomes the one backend env file
  ISSUE-2 deploys from; the template ships its own `.env.example` with a different
  var set — overwrite it with these six keys, values blanked.
- `apps/web/.env` — `NEXT_PUBLIC_API_URL=http://localhost:8000`. Commit this one:
  it is a localhost default, not a secret, and in production Vercel's own value
  wins (ISSUE-2 step 3).

Never print a key value into the chat. Copy files, don't echo secrets.

## 4. Commit

One commit, message `scaffold apps/api (langgraph) + apps/web (next.js) from templates`.
Both templates as-generated — a reviewer should see a clean diff against upstream.

## Acceptance — all four must pass

1. `bash scripts/check.sh` — `all set`, including the `apps/api` and `apps/web` lines.
2. `cd apps/api && uv sync && uv run pytest tests/unit_tests` — green (the template's
   own tests, still asserting `changeme`).
3. `cd apps/web && npm install && npm run build` — clean.
4. `git status` — clean, and `git ls-files apps | wc -l` is non-zero (proves the
   nested `.git` is gone and the outer repo actually tracks the templates).

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| `langgraph: command not found` | ran it without `uvx --from` | use the command above verbatim |
| `create-next-app` prompts interactively | a flag is missing | keep `--yes` and all the flags above |
| `git ls-files apps/web` empty | nested repo from `create-next-app` | `rm -rf apps/web/.git`, then `git add apps/web` |
| `npm run build` fails on a missing module | `--skip-install` or an interrupted install | `cd apps/web && npm install` |
| check.sh still says keys MISSING | `apps/api/.env` not written yet | step 3 |
