#!/usr/bin/env bash
# Prints ok / MISSING for every setup step in README.md. Fix what's missing in the section named.
cd "$(dirname "$0")/.."
fail=0
ok()   { printf 'ok       %s\n' "$1"; }
miss() { printf 'MISSING  %-34s -> %s\n' "$1" "$2"; fail=1; }

for c in git gh node uv gcloud vercel claude; do
  command -v "$c" >/dev/null 2>&1 && ok "$c" || miss "$c" "§1 Install CLIs"
done

gh auth status >/dev/null 2>&1 && ok "gh login" || miss "gh login" "§0 gh auth login"
o=$(git remote get-url origin 2>/dev/null)
owner=$(echo "$o" | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#')
me=$(gh api user --jq .login 2>/dev/null)
if [ -z "$o" ]; then miss "git origin" "§0 fork and clone"
elif [ -n "$me" ] && [ "$owner" != "$me" ]; then miss "git origin is $owner's repo, not yours" "§0 fork and clone"
else ok "git origin ($o)"; fi

gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q . \
  && ok "gcloud login" || miss "gcloud login" "§2 gcloud auth login"
gcloud auth application-default print-access-token >/dev/null 2>&1 \
  && ok "gcloud ADC" || miss "gcloud ADC" "§2 gcloud auth application-default login"
P=$(gcloud config get-value project 2>/dev/null)
if [ -n "$P" ]; then
  ok "gcloud project ($P)"
  Q=$(python3 -c 'import json,os;print(json.load(open(os.path.expanduser("~/.config/gcloud/application_default_credentials.json"))).get("quota_project_id",""))' 2>/dev/null)
  [ -z "$Q" ] || [ "$Q" = "$P" ] || miss "ADC quota project ($Q)" "§2 gcloud auth application-default set-quota-project $P"
  gcloud billing projects describe "$P" --format='value(billingEnabled)' 2>/dev/null | grep -q True \
    && ok "billing" || miss "billing" "§2 gcloud billing projects link"
  n=$(gcloud services list --enabled --format='value(config.name)' 2>/dev/null \
      | grep -cE '^(run|artifactregistry|cloudbuild)\.googleapis\.com$')
  [ "$n" = 3 ] && ok "Cloud Run/Build/Artifact APIs" || miss "APIs ($n/3 enabled)" "§2 gcloud services enable"
else
  miss "gcloud project" "§2 gcloud config set project"
fi
[ -n "$(gcloud config get-value run/region 2>/dev/null)" ] \
  && ok "gcloud run/region" || miss "gcloud run/region" "§2 gcloud config set run/region"

vercel whoami >/dev/null 2>&1 && ok "vercel login" || miss "vercel login" "§3 vercel login"

claude plugin list 2>/dev/null | grep -A3 '^  ❯ vercel@' | grep -q 'enabled' \
  && ok "vercel plugin" || miss "vercel plugin" "§4 claude plugin install vercel@claude-plugins-official"
[ -d "$HOME/.claude/skills/google-agents-cli-deploy" ] || [ -d "$HOME/.agents/skills/google-agents-cli-deploy" ] \
  && ok "google-agents-cli skills" || miss "google-agents-cli skills" "§4 uvx google-agents-cli setup"

[ -f apps/api/pyproject.toml ] && ok "apps/api scaffold" || miss "apps/api scaffold" "§5 langgraph new"
[ -f apps/web/package.json ]  && ok "apps/web scaffold"  || miss "apps/web scaffold"  "§5 create-next-app"

envset() { grep -E "^$2=.+" "$1" 2>/dev/null | grep -vqE '=\s*(sk-or-v1-\.\.\.|lsv2_pt_\.\.\.|\.\.\.)?\s*$'; }
for v in OPENROUTER_API_KEY OPENROUTER_BASE_URL OPENROUTER_MODEL LANGCHAIN_TRACING_V2 LANGSMITH_API_KEY LANGSMITH_PROJECT; do
  envset apps/api/.env "$v" && ok "apps/api/.env $v" || miss "apps/api/.env $v" "§6 Keys"
done
envset apps/web/.env.local NEXT_PUBLIC_API_URL && ok "apps/web/.env.local NEXT_PUBLIC_API_URL" || miss "apps/web/.env.local" "§6 Keys"

[ $fail = 0 ] && echo "all set — go to §7" || echo "fix the MISSING lines, then re-run"
exit $fail
