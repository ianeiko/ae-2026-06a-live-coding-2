#!/usr/bin/env bash
# Prints ok / MISSING for every setup step in README.md and names the section that fixes it.
cd "$(dirname "$0")/.."
fail=0
ok()   { printf 'ok       %s\n' "$1"; }
miss() { printf 'MISSING  %-36s -> %s\n' "$1" "$2"; fail=1; }

for c in git gh node uv; do command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c" "Appendix A"; done
for c in gcloud vercel; do  command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c" "§3 Tools"; done
command -v claude >/dev/null 2>&1 && ok "claude" || miss "claude" "§3 Claude Code"

gh auth status >/dev/null 2>&1 && ok "gh login" || miss "gh login" "§3 gh auth login"
o=$(git remote get-url origin 2>/dev/null)
owner=$(echo "$o" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#')
me=$(gh api user --jq .login 2>/dev/null)
if [ -z "$o" ]; then miss "git origin" "§2 Fork"
elif [ -n "$me" ] && [ "$owner" != "$me" ]; then miss "git origin is $owner's repo, not yours" "§2 Fork"
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
plugin_on vercel@claude-plugins-official && ok "vercel plugin" || miss "vercel plugin" "§3 claude plugin install vercel@claude-plugins-official"
plugin_on google-cloud-developer@google-plugins && ok "google cloud plugin" || miss "google cloud plugin" "§3 claude plugin install google-cloud-developer@google-plugins"

[ -f apps/api/pyproject.toml ] && ok "apps/api" || miss "apps/api (clone incomplete)" "§2 Fork"
[ -f apps/web/package.json ]  && ok "apps/web" || miss "apps/web (clone incomplete)" "§2 Fork"

envset() { grep -E "^$2=.+" "$1" 2>/dev/null | grep -vqE '=\s*(sk-or-v1-\.\.\.|lsv2_pt_\.\.\.|\.\.\.)?\s*$'; }
for v in OPENROUTER_API_KEY OPENROUTER_BASE_URL OPENROUTER_MODEL LANGCHAIN_TRACING_V2 LANGSMITH_API_KEY LANGSMITH_PROJECT; do
  envset apps/api/.env "$v" && ok "apps/api/.env $v" || miss "apps/api/.env $v" "§3 Keys"
done
envset apps/web/.env.local NEXT_PUBLIC_API_URL && ok "apps/web/.env.local NEXT_PUBLIC_API_URL" || miss "apps/web/.env.local" "§3 Keys"

# Does the OpenRouter key work, and is there credit behind it? Skipped when offline.
k=$(grep -E '^OPENROUTER_API_KEY=' apps/api/.env 2>/dev/null | cut -d= -f2-)
if [ -n "$k" ]; then
  code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $k" https://openrouter.ai/api/v1/auth/key)
  case "$code" in
    200) ok "OpenRouter key accepted"
         bal=$(curl -s -m 8 -H "Authorization: Bearer $k" https://openrouter.ai/api/v1/credits \
               | python3 -c 'import json,sys;d=json.load(sys.stdin)["data"];print(f"{d["total_credits"]-d["total_usage"]:.2f}")' 2>/dev/null)
         if [ -n "$bal" ]; then
           python3 -c "import sys;sys.exit(0 if $bal>0 else 1)" && ok "OpenRouter credit (\$$bal left)" \
             || miss "OpenRouter credit (\$$bal left)" "§1 add credit at openrouter.ai/settings/credits"
         fi ;;
    401|403) miss "OpenRouter key rejected ($code)" "§1 new key at openrouter.ai/keys" ;;
  esac
fi

[ $fail = 0 ] && echo "all set — go to §4" || echo "fix the MISSING lines, then re-run"
exit $fail
