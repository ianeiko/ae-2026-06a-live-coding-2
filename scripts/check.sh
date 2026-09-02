#!/usr/bin/env bash
# Prints ok / MISSING for every setup step in README.md and names the section that fixes it.
cd "$(dirname "$0")/.."
fail=0
PY=$(command -v python3 || command -v python)   # python3 on macOS, often just python on Windows
ok()   { printf 'ok       %s\n' "$1"; }
miss() { printf 'MISSING  %-36s -> %s\n' "$1" "$2"; fail=1; }

for c in git node uv claude; do command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c" "Appendix A"; done
for c in gcloud vercel; do command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c" "§3 Tools"; done

o=$(git remote get-url origin 2>/dev/null)
owner=$(echo "$o" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#')
if [ -z "$o" ]; then miss "git origin" "§2 Fork"
elif [ "$owner" = ianeiko ]; then miss "git origin is the upstream repo, not your fork" "§2 Fork"
else ok "git origin ($o)"; fi

gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q . \
  && ok "gcloud login" || miss "gcloud login" "§3 gcloud auth login"
P=$(gcloud config get-value project 2>/dev/null)
if [ -n "$P" ]; then
  ok "gcloud project ($P)"
  gcloud billing projects describe "$P" --format='value(billingEnabled)' 2>/dev/null | grep -q True \
    && ok "billing" || miss "billing" "§3 gcloud billing projects link"
  n=$(gcloud services list --enabled --format='value(config.name)' 2>/dev/null \
      | grep -cE '^(run|artifactregistry|cloudbuild)\.googleapis\.com$')
  [ "$n" = 3 ] && ok "Cloud Run/Build/Artifact APIs" || miss "APIs ($n/3 enabled)" "§3 gcloud services enable"
else
  miss "gcloud project" "§3 gcloud config set project"
fi
[ -n "$(gcloud config get-value run/region 2>/dev/null)" ] \
  && ok "gcloud run/region" || miss "gcloud run/region" "§3 gcloud config set run/region"

vercel whoami >/dev/null 2>&1 && ok "vercel login" || miss "vercel login" "§3 vercel login"

PL=$(claude plugin list 2>/dev/null)
plugin_on() { echo "$PL" | grep -A3 "^  ❯ $1" | grep Status | grep -qv disabled; }
plugin_on vercel@claude-plugins-official && ok "vercel plugin" \
  || miss "vercel plugin" "§3 open claude in the repo, or: claude plugin install vercel@claude-plugins-official"
plugin_on google-cloud-developer@google-plugins && ok "google cloud plugin" \
  || miss "google cloud plugin" "§3 open claude in the repo, or: claude plugin marketplace add google/skills && claude plugin install google-cloud-developer@google-plugins"

[ -f apps/api/pyproject.toml ] && ok "apps/api" || miss "apps/api (clone incomplete)" "§2 Fork"
[ -f apps/web/package.json ]  && ok "apps/web" || miss "apps/web (clone incomplete)" "§2 Fork"

envset() { grep -E "^$2=.+" "$1" 2>/dev/null | grep -vqE '=\s*(sk-or-v1-\.\.\.|lsv2_pt_\.\.\.|\.\.\.)?\s*$'; }
for v in OPENROUTER_API_KEY OPENROUTER_BASE_URL OPENROUTER_MODEL LANGCHAIN_TRACING_V2 LANGSMITH_API_KEY LANGSMITH_PROJECT; do
  envset apps/api/.env "$v" && ok "apps/api/.env $v" || miss "apps/api/.env $v" "§3 Keys"
done

# Does the OpenRouter key work, and is there credit behind it? Skipped when offline.
k=$(grep -E '^OPENROUTER_API_KEY=' apps/api/.env 2>/dev/null | cut -d= -f2-)
if [ -n "$k" ]; then
  code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $k" https://openrouter.ai/api/v1/auth/key)
  case "$code" in
    200) ok "OpenRouter key accepted"
         bal=$(curl -s -m 8 -H "Authorization: Bearer $k" https://openrouter.ai/api/v1/credits \
               | "$PY" -c 'import json,sys;d=json.load(sys.stdin)["data"];print(f"{d["total_credits"]-d["total_usage"]:.2f}")' 2>/dev/null)
         if [ -n "$bal" ]; then
           "$PY" -c "import sys;sys.exit(0 if $bal>0 else 1)" && ok "OpenRouter credit (\$$bal left)" \
             || miss "OpenRouter credit (\$$bal left)" "§3 Keys — ask for a topped-up key"
         fi ;;
    401|403) miss "OpenRouter key rejected ($code)" "§3 Keys — check the OpenRouter key you were given" ;;
  esac
fi

[ $fail = 0 ] && echo "all set — go to §4" || echo "fix the MISSING lines, then re-run"
exit $fail
