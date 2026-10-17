#!/usr/bin/env bash
# Adds the team's agent files to a project (new or existing).
# Never overwrites: files that already exist are skipped and listed.
#
#   ./scripts/init-project.sh ~/code/my-project

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_DIR/project-template"
TARGET="${1:-}"

if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
  echo "Usage: $0 <path-to-project>" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

added=(); skipped=(); notes=()

# A project set up under the old standards has a CLAUDE.md with real content.
# Codex can't read it, so move the content into AGENTS.md and make CLAUDE.md an import.
IMPORT='@AGENTS.md'
if [[ -f "$TARGET/CLAUDE.md" ]]; then
  claude_text="$(cat "$TARGET/CLAUDE.md")"
  trimmed="$(printf '%s' "$claude_text" | tr -d '[:space:]')"
  if [[ "$trimmed" != "$IMPORT" ]]; then
    if [[ -e "$TARGET/AGENTS.md" ]]; then
      notes+=("CLAUDE.md has its own content and AGENTS.md also exists. Codex only reads AGENTS.md:")
      notes+=("  merge CLAUDE.md into AGENTS.md by hand, then make CLAUDE.md just: $IMPORT")
    else
      printf '%s\n' "$claude_text" > "$TARGET/AGENTS.md"
      printf '%s\n' "$IMPORT" > "$TARGET/CLAUDE.md"
      notes+=("Moved the existing CLAUDE.md content into AGENTS.md; CLAUDE.md now just imports it.")
      notes+=("  Compare AGENTS.md with the template sections and fill in anything missing.")
    fi
  fi
fi

while IFS= read -r -d '' src; do
  rel="${src#"$TEMPLATE"/}"
  dest="$TARGET/$rel"
  if [[ -e "$dest" ]]; then
    skipped+=("$rel")
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    added+=("$rel")
  fi
done < <(find "$TEMPLATE" -type f -print0 | sort -z)

echo "Project: $TARGET"
if ((${#notes[@]})); then
  echo; printf '  !! %s\n' "${notes[@]}"
fi
if ((${#added[@]})); then
  echo; echo "Added:"; printf '  + %s\n' "${added[@]}"
fi
if ((${#skipped[@]})); then
  echo; echo "Already present (left alone, check they match the template):"; printf '  = %s\n' "${skipped[@]}"
fi

cat <<'EOF'

Next:
  1. Fill in the TODOs in AGENTS.md, or open Claude Code and ask it to fill them
     in by inspecting the solution.
  2. Run /setup-matt-pocock-skills (choose GitLab, your triage labels, and docs/ for docs).
  3. Commit the new files on a chore/ branch and open an MR into dev.
EOF
