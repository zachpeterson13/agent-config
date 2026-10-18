#!/usr/bin/env bash
# Sets up one developer's machine to use the team's agent standards.
# Safe to re-run: it backs up anything it replaces and skips what's already done.
#
#   ./scripts/install.sh                          # link standards + install plugins
#   ./scripts/install.sh --no-plugins
#   ./scripts/install.sh --delegation claude      # who does the heavy work: codex | claude
#
# --delegation: if omitted, keeps your current choice; on a first install, picks
# codex if the codex CLI is installed, otherwise claude. Re-run to switch.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
STAMP="$(date +%Y%m%d-%H%M%S)"
INSTALL_PLUGINS=1
DELEGATION=""

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-plugins)   INSTALL_PLUGINS=0; shift ;;
    --delegation)   DELEGATION="${2:-}"; shift 2 || usage ;;
    --delegation=*) DELEGATION="${1#*=}"; shift ;;
    -h|--help)      usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done
if [[ -n "$DELEGATION" && "$DELEGATION" != "codex" && "$DELEGATION" != "claude" ]]; then
  echo "--delegation must be codex or claude" >&2; exit 1
fi

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
info() { printf '  - %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

backup() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    mv "$path" "$path.bak-$STAMP"
    warn "Backed up existing $path to $path.bak-$STAMP"
  fi
}

# ---------------------------------------------------------------------------
step "Checking tools"
missing=0
for tool in git node claude glab; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool found"; else warn "$tool not found"; missing=1; fi
done
HAS_CODEX=0
if command -v codex >/dev/null 2>&1; then HAS_CODEX=1; ok "codex found"
else info "codex not found (only needed for Codex delegation)"; fi
if [[ $missing -eq 1 ]]; then
  cat <<'EOF'
    Install what's missing, then re-run this script:
      git    https://git-scm.com
      node   https://nodejs.org (18.18 or later)
      claude https://docs.claude.com/en/docs/claude-code
      glab   https://gitlab.com/gitlab-org/cli   (then: glab auth login)
EOF
fi

# ---------------------------------------------------------------------------
step "Choosing delegation mode"
source_note="chosen with --delegation"
if [[ -z "$DELEGATION" ]]; then
  if [[ -f "$CLAUDE_MD" ]] && grep -qF 'claude/delegation-claude.md' "$CLAUDE_MD"; then
    DELEGATION=claude; source_note="kept your current choice"
  elif [[ -f "$CLAUDE_MD" ]] && grep -qF 'claude/delegation-codex.md' "$CLAUDE_MD"; then
    DELEGATION=codex; source_note="kept your current choice"
  elif [[ $HAS_CODEX -eq 1 ]]; then
    DELEGATION=codex; source_note="default: codex is installed"
  else
    DELEGATION=claude; source_note="default: codex is not installed"
  fi
fi
ok "Heavy work goes to: $DELEGATION ($source_note)"
if [[ "$DELEGATION" == "codex" && $HAS_CODEX -eq 0 ]]; then
  warn "Codex mode needs the codex CLI: npm install -g @openai/codex, then codex login."
  warn "Until then Claude will ask before falling back to its own subagents."
fi

# ---------------------------------------------------------------------------
step "Linking shared standards"
mkdir -p "$CLAUDE_DIR" "$CODEX_DIR"

# Claude: a managed block of imports at the top of ~/.claude/CLAUDE.md.
# Claude reads the repo files fresh every session, so `git pull` is the whole update.
# Only the lines between the markers are ever rewritten; everything else is yours.
BEGIN_MARKER='<!-- BEGIN agent-config: managed block, re-running install replaces it -->'
END_MARKER='<!-- END agent-config -->'
export AC_BLOCK="$BEGIN_MARKER
@$REPO_DIR/AGENTS.md
@$REPO_DIR/claude/orchestration.md
@$REPO_DIR/claude/delegation-$DELEGATION.md
$END_MARKER"

if [[ -f "$CLAUDE_MD" ]] && grep -qF "$BEGIN_MARKER" "$CLAUDE_MD" && grep -qF "$END_MARKER" "$CLAUDE_MD"; then
  updated="$(AC_BEGIN="$BEGIN_MARKER" AC_END="$END_MARKER" awk '
    index($0, ENVIRON["AC_BEGIN"]) == 1 { print ENVIRON["AC_BLOCK"]; skip = 1; next }
    skip && index($0, ENVIRON["AC_END"]) == 1 { skip = 0; next }
    !skip { print }
  ' "$CLAUDE_MD")"
  if [[ "$updated" == "$(cat "$CLAUDE_MD")" ]]; then
    ok "~/.claude/CLAUDE.md already up to date"
  else
    printf '%s\n' "$updated" > "$CLAUDE_MD"
    ok "Updated the managed block in ~/.claude/CLAUDE.md (kept your personal lines)"
  fi
else
  # Most likely the old global CLAUDE.md copied from the shared drive.
  # Its content now lives in AGENTS.md, so set it aside rather than merge it.
  backup "$CLAUDE_MD"
  printf '%s\n\n%s\n' "$AC_BLOCK" '<!-- Personal, non-team preferences can go below this line. -->' > "$CLAUDE_MD"
  ok "Wrote ~/.claude/CLAUDE.md"
fi

# Codex reads the same standards. Linked in either mode so switching needs no re-setup.
CODEX_AGENTS="$CODEX_DIR/AGENTS.md"
if [[ -L "$CODEX_AGENTS" && "$(readlink "$CODEX_AGENTS")" == "$REPO_DIR/AGENTS.md" ]]; then
  ok "~/.codex/AGENTS.md already linked"
else
  backup "$CODEX_AGENTS"
  ln -s "$REPO_DIR/AGENTS.md" "$CODEX_AGENTS"
  ok "Linked ~/.codex/AGENTS.md -> $REPO_DIR/AGENTS.md"
fi

# Codex config: never overwrite a personal config; seed it only if absent.
CODEX_CONFIG="$CODEX_DIR/config.toml"
if [[ -f "$CODEX_CONFIG" ]]; then
  ok "Kept your existing ~/.codex/config.toml (team defaults are in codex/config.toml if you want to compare)"
else
  cp "$REPO_DIR/codex/config.toml" "$CODEX_CONFIG"
  ok "Created ~/.codex/config.toml from team defaults"
fi

# ---------------------------------------------------------------------------
if [[ $INSTALL_PLUGINS -eq 1 ]]; then
  step "Installing plugins"
  try() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$label"; else warn "$label failed or was already done; run it manually: $*"; fi
  }
  if command -v claude >/dev/null 2>&1; then
    try "Claude: Matt Pocock skills" claude plugin install mattpocock-skills@claude-plugins-official
    # Installed whenever Codex is, even in Claude mode, so switching needs no re-install.
    if [[ $HAS_CODEX -eq 1 ]]; then
      try "Claude: Codex plugin marketplace" claude plugin marketplace add openai/codex-plugin-cc
      try "Claude: Codex plugin" claude plugin install codex@openai-codex
    fi
  else
    warn "Skipping Claude plugins (claude not installed)"
  fi
  if [[ $HAS_CODEX -eq 1 ]]; then
    try "Codex: Matt Pocock marketplace" codex plugin marketplace add mattpocock/skills
    try "Codex: Matt Pocock skills" codex plugin add mattpocock-skills@mattpocock
  else
    info "Skipping Codex plugins (codex not installed)"
  fi
fi

# ---------------------------------------------------------------------------
step "Next steps"
[[ "$DELEGATION" == "codex" ]] && echo "  0. In Claude Code, run /codex:setup to confirm Codex is logged in."
cat <<'EOF'
  1. In Claude Code, run /memory to confirm the three agent-config files are loaded.
     Changes apply to new Claude sessions.
  2. In each project, run scripts/init-project.sh <path>, then /setup-matt-pocock-skills.
  3. To get standards updates later: git pull in this repo.
  4. To switch who does the heavy work: re-run with --delegation codex|claude --no-plugins.
EOF
