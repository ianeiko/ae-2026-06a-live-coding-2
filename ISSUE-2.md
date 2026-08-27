Deploy both apps and verify the live chat end to end. **Blocked by #1** — do not start until its four acceptance checks pass locally.

Prereqs are already done by README §2–§4: `gcloud` authed with billing + APIs + default region, `vercel login`, Vercel plugin installed. If any is missing, stop and point at the README section rather than improvising.

Run these as separate prompts, in order. Each one has a check you can see fail.

## 1. Deploy the backend

> Deploy `apps/api` to Cloud Run as `langgraph-api` with `gcloud run deploy --source . --allow-unauthenticated`, passing `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` and `OPENROUTER_MODEL` from my root `.env` via `--set-env-vars`. Consult the `google-agents-cli-deploy` skill for Cloud Run practice. Print the service URL when done.

Cloud Build builds the Dockerfile from #1. Do not set `PORT` — Cloud Run injects it.

**Check:** `curl <SERVICE_URL>/healthz` → `{"ok":true}`.

## 2. Smoke the deployed API

> `curl -X POST <SERVICE_URL>/chat` with one user message and show me the reply. If it fails, read the logs with `gcloud run services logs read langgraph-api --limit 50` and tell me the cause before changing anything.

Almost always a missing or wrong env var — a bad `OPENROUTER_MODEL` slug fails at request time, not at startup.

## 3. Point the frontend at it

> In `apps/web`, use the Vercel CLI / `/vercel:env` to link the project and set `NEXT_PUBLIC_API_URL` to `<SERVICE_URL>` for production, preview and development. Confirm with `vercel env ls`.

`NEXT_PUBLIC_*` is baked in at build time, so this must precede the deploy.

## 4. Deploy the frontend

> Deploy `apps/web` to production with `/vercel:deploy prod`. Give me the production URL.

Run it from `apps/web` so the monorepo root-directory setting resolves itself.

**Check:** the URL loads and the chat UI renders.

## 5. Verify end to end

> Using the `/browse` skill, open the production URL, send "say hi in three words", and confirm a real reply renders. Report the network request URL you saw.

That last part is the actual test: the request must go to the Cloud Run host. If it went to `undefined/chat` or `localhost`, step 3 didn't take effect — re-run the deploy.

## 6. Report

> Give me a table: service, URL, deploy command, verified how. Then `/vercel:status` and `gcloud run services list`.

## Acceptance

- `<SERVICE_URL>/healthz` returns 200.
- `<SERVICE_URL>/chat` returns real model text.
- The production Vercel URL holds a working conversation, verified in a browser.
- Both URLs are recorded in the README.

## Failure modes

| Symptom | Cause | Fix |
| --- | --- | --- |
| Build fails on Cloud Build | Dockerfile or deps from #1 | read the build log link the command prints |
| `/chat` 500s, `/healthz` fine | key or model slug wrong | `gcloud run services update langgraph-api --set-env-vars ...` |
| Frontend calls `undefined/chat` | env var set after the build | re-run `vercel --prod` |
| CORS error in the browser | middleware missing from #1 | fix in `apps/api`, redeploy |
