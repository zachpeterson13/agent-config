#!/usr/bin/env bash
# Sets up this machine to use my agent standards.
# Safe to re-run: it backs up anything it replaces and skips what's already done.
#
#   ./scripts/install.sh                # link standards + install plugins
#   ./scripts/install.sh --no-plugins

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
STAMP="$(date +%Y%m%d-%H%M%S)"
INSTALL_PLUGINS=1

usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-plugins) INSTALL_PLUGINS=0; shift ;;
    -h|--help)    usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

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
for tool in git node claude gh; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool found"; else warn "$tool not found"; missing=1; fi
done
if [[ $missing -eq 1 ]]; then
  cat <<'EOF'
    Install what's missing, then re-run this script:
      git    https://git-scm.com
      node   https://nodejs.org (18.18 or later)
      claude https://docs.claude.com/en/docs/claude-code
      gh     https://cli.github.com   (then: gh auth login)
EOF
fi

# ---------------------------------------------------------------------------
step "Linking shared standards"
mkdir -p "$CLAUDE_DIR"

# Claude: a managed block at the top of ~/.claude/CLAUDE.md that imports my AGENTS.md.
# Claude reads it fresh every session, so `git pull` is the whole update.
# Only the lines between the markers are ever rewritten; everything else is yours.
BEGIN_MARKER='<!-- BEGIN agent-config: managed block, re-running install replaces it -->'
END_MARKER='<!-- END agent-config -->'
export AC_BLOCK="$BEGIN_MARKER
@$REPO_DIR/AGENTS.md
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
  # Most likely an older global CLAUDE.md.
  # Its content now lives in AGENTS.md, so set it aside rather than merge it.
  backup "$CLAUDE_MD"
  printf '%s\n\n%s\n' "$AC_BLOCK" '<!-- Personal preferences can go below this line. -->' > "$CLAUDE_MD"
  ok "Wrote ~/.claude/CLAUDE.md"
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
  else
    warn "Skipping Claude plugins (claude not installed)"
  fi
fi

# ---------------------------------------------------------------------------
step "Next steps"
cat <<'EOF'
  1. In Claude Code, run /memory to confirm AGENTS.md is loaded (new sessions only).
  2. In each project repo: cd into it, run scripts/init-project.sh, then /setup-matt-pocock-skills.
  3. To get standards updates later: git pull in this repo.
EOF
