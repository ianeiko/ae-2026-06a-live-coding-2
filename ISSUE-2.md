Deploy both apps and verify the live chat end to end. **Blocked by #1** — do not start until its four acceptance checks pass locally.

Prereqs are already done by README §2–§4: `gcloud` authed with billing + APIs + default region, `vercel login`, Vercel plugin installed. If any is missing, stop and point at the README section rather than improvising.

Run these as separate prompts, in order. Each one has a check you can see fail.

## 1. Deploy the backend

> Deploy `apps/api` to Cloud Run as `langgraph-api` with `gcloud run deploy --source . --allow-unauthenticated`, passing all six vars from `apps/api/.env` via `--set-env-vars`: `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`, `OPENROUTER_MODEL`, `LANGCHAIN_TRACING_V2`, `LANGSMITH_API_KEY`, `LANGSMITH_PROJECT`. Consult the `google-agents-cli-deploy` skill for Cloud Run practice. Print the service URL when done.

Cloud Build builds the Dockerfile from #1. Do not set `PORT` — Cloud Run injects it.

Source `apps/api/.env`, not the root `.env` — only the former has the LangSmith
vars. `--set-env-vars` *replaces* the whole set on every deploy, so a later
redeploy that passes three vars silently turns tracing off.

**Check:** `curl <SERVICE_URL>/health` → `{"ok":true}`. Use `/health`, not
`/healthz`: Google's frontend reserves `/healthz` and answers it with a
Google-branded 404 before the request reaches your container, which reads
exactly like a broken deploy. The request never even appears in the Cloud Run
logs. `apps/api` wires both paths; only `/health` survives in production.

## 2. Smoke the deployed API

> `curl -X POST <SERVICE_URL>/chat` with one user message and show me the reply. If it fails, read the logs with `gcloud run services logs read langgraph-api --limit 50` and tell me the cause before changing anything.

Almost always a missing or wrong env var — a bad `OPENROUTER_MODEL` slug fails at request time, not at startup.

## 3. Point the frontend at it

> In `apps/web`, use the Vercel CLI / `/vercel:env` to link the project and set `NEXT_PUBLIC_API_URL` to `<SERVICE_URL>` for production, preview and development. Confirm with `vercel env ls`.

`NEXT_PUBLIC_*` is baked in at build time, so this must precede the deploy.

## 4. Deploy the frontend

> Deploy `apps/web` to production with `/vercel:deploy prod`. Then set the Vercel project's **Root Directory** to `apps/web`, and confirm a git push builds green too.

This is a monorepo, so the Root Directory setting is not optional. A CLI deploy
run from `apps/web` uploads that directory and passes whatever the setting says
— which hides the problem. A push-triggered build starts at the repo root, finds
no `app/` there, and fails with `Couldn't find any pages or app directory`. Set
it once in the dashboard, or `PATCH /v9/projects/<id>` with
`{"rootDirectory":"apps/web"}`.

**Check:** the URL loads and the chat UI renders, *and* the next push to `main`
produces a green deployment rather than a build error.

## 5. Verify end to end

> Using the `/browse` skill, open the production URL, send "say hi in three words", and confirm a real reply renders. Report the network request URL you saw.

That last part is the actual test: the request must go to the Cloud Run host. If it went to `undefined/chat` or `localhost`, step 3 didn't take effect — re-run the deploy.

## 6. Report

> Give me a table: service, URL, deploy command, verified how. Then `/vercel:status` and `gcloud run services list`. Confirm the run appeared in LangSmith.

## Acceptance

- `<SERVICE_URL>/health` returns 200.
- `<SERVICE_URL>/chat` returns real model text.
- The production Vercel URL holds a working conversation, verified in a browser.
- A push to `main` produces a green Vercel deployment.
- The request lands as a `Chat Graph` run in the LangSmith project.
- Both URLs are recorded in the README.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Build fails on Cloud Build | Dockerfile or deps from #1 | read the build log link the command prints |
| `/chat` 500s, `/health` fine | key or model slug wrong | `gcloud run services update langgraph-api --set-env-vars ...` |
| Frontend calls `undefined/chat` | env var set after the build | re-run `vercel --prod` |
| CORS error in the browser | middleware missing from #1 | fix in `apps/api`, redeploy |
| Google-branded 404 on `/healthz` | reserved path, answered before your container | probe `/health` |
| `Couldn't find any pages or app directory` on a pushed build | Root Directory is the repo root | set it to `apps/web` |
| chat works, LangSmith empty | `LANGSMITH_*` not in `--set-env-vars` | redeploy with all six vars |
