#!/usr/bin/env bash
# Adds my agent files to the repo in the current directory.
# Run it from the root of the repo. No arguments. Safe to re-run, before or
# after /setup-matt-pocock-skills.
#
#   cd ~/code/my-project && ~/agent-config/scripts/init-project.sh
#
# Adds what's missing and never overwrites your content:
#   AGENTS.md              repo context (from the template)
#   CLAUDE.md              a one-line import of AGENTS.md, so both tools read one file
#   .claude/settings.json  enables Matt Pocock's skills 
#   docs/standards/*.md    my stack standards, read only when relevant
#
# It does NOT create anything /setup-matt-pocock-skills owns (docs/agents/, the
# glossary, ADRs, labels). One fix-up: if that skill wrote its "## Agent skills"
# block into CLAUDE.md, the block is moved to AGENTS.md to keep one source of truth.

set -euo pipefail
[[ $# -eq 0 ]] || { sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$(pwd)"
TEMPLATE="$REPO_DIR/project-template"
STANDARDS="$REPO_DIR/standards"
IMPORT='@AGENTS.md'
BLOCK_HEAD='## Agent skills'
AGENTS="$TARGET/AGENTS.md"
CLAUDE="$TARGET/CLAUDE.md"

[[ -e "$TARGET/.git" ]] || { echo "Run this from the root of a git repo (no .git in $TARGET)." >&2; exit 1; }
[[ "$TARGET" != "$REPO_DIR" ]] || { echo "This is the agent-config repo itself. cd into the project repo first." >&2; exit 1; }

added=(); skipped=(); notes=()

block_of()   { awk '/^## Agent skills[[:space:]]*$/ && !d {f=1; d=1; print; next} f && /^## / {f=0} f {print}' "$1"; }
without_block() { awk '/^## Agent skills[[:space:]]*$/ && !d {f=1; d=1; next} f && /^## / {f=0} !f {print}' "$1"; }
legacy_of()  { without_block "$1" | perl -0pe 's/<!--.*?-->//gs' | grep -vxF "$IMPORT" | tr -d '[:space:]' || true; }
trim_file()  { perl -0pi -e 's/\A\s+//; s/\s+\z/\n/' "$1"; }

# --- AGENTS.md and CLAUDE.md ----------------------------------------------
if [[ -f "$CLAUDE" ]]; then
  block="$(block_of "$CLAUDE")"
  legacy="$(legacy_of "$CLAUDE")"
  if [[ ! -f "$AGENTS" ]]; then
    if [[ -n "$legacy" ]]; then
      # Old-style repo: CLAUDE.md held the project context. Move it all.
      grep -vxF "$IMPORT" "$CLAUDE" > "$AGENTS" || true
      trim_file "$AGENTS"
      notes+=("Moved the project context from CLAUDE.md into AGENTS.md.")
      notes+=("  Compare it with project-template/AGENTS.md and add any missing sections.")
    else
      cp "$TEMPLATE/AGENTS.md" "$AGENTS"
      if [[ -n "$block" ]]; then
        printf '\n%s\n' "$block" >> "$AGENTS"
        notes+=("Moved the '$BLOCK_HEAD' block from CLAUDE.md into AGENTS.md.")
      fi
      added+=("AGENTS.md")
    fi
    cp "$TEMPLATE/CLAUDE.md" "$CLAUDE"
  else
    if [[ -n "$block" ]]; then
      if grep -q '^## Agent skills[[:space:]]*$' "$AGENTS"; then
        tmp="$(mktemp)"; printf '%s\n' "$block" > "$tmp.block"
        awk -v bf="$tmp.block" '
          /^## Agent skills[[:space:]]*$/ && !d { while ((getline l < bf) > 0) print l; print ""; f=1; d=1; next }
          f && /^## / { f=0 }
          !f { print }' "$AGENTS" > "$tmp" && mv "$tmp" "$AGENTS"; rm -f "$tmp.block"
        notes+=("Replaced the '$BLOCK_HEAD' block in AGENTS.md with the newer one from CLAUDE.md.")
      else
        printf '\n%s\n' "$block" >> "$AGENTS"
        notes+=("Moved the '$BLOCK_HEAD' block from CLAUDE.md into AGENTS.md.")
      fi
      trim_file "$AGENTS"
      tmp="$(mktemp)"; without_block "$CLAUDE" > "$tmp" && mv "$tmp" "$CLAUDE"; trim_file "$CLAUDE"
    fi
    if [[ -n "$legacy" ]]; then
      notes+=("CLAUDE.md has its own content and AGENTS.md also exists. AGENTS.md is the source of truth:")
      notes+=("  merge CLAUDE.md into AGENTS.md by hand, then make CLAUDE.md just: $IMPORT")
    elif ! grep -qxF "$IMPORT" "$CLAUDE"; then
      cp "$TEMPLATE/CLAUDE.md" "$CLAUDE"
      notes+=("CLAUDE.md didn't import AGENTS.md; reset it to the one-line import.")
    else
      skipped+=("CLAUDE.md")
    fi
    skipped+=("AGENTS.md")
  fi
elif [[ ! -f "$AGENTS" ]]; then
  cp "$TEMPLATE/AGENTS.md" "$AGENTS"; cp "$TEMPLATE/CLAUDE.md" "$CLAUDE"
  added+=("AGENTS.md" "CLAUDE.md")
else
  cp "$TEMPLATE/CLAUDE.md" "$CLAUDE"
  added+=("CLAUDE.md"); skipped+=("AGENTS.md")
fi

# --- Other template files (anything not handled above) ---------------------
while IFS= read -r -d '' src; do
  rel="${src#"$TEMPLATE"/}"
  [[ "$rel" == "AGENTS.md" || "$rel" == "CLAUDE.md" ]] && continue
  dest="$TARGET/$rel"
  if [[ -e "$dest" ]]; then skipped+=("$rel")
  else mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; added+=("$rel"); fi
done < <(find "$TEMPLATE" -type f -print0 | sort -z)

# --- Standards ------------------------------------------------------------
for src in "$STANDARDS"/*.md; do
  [[ -e "$src" ]] || continue
  rel="docs/standards/$(basename "$src")"; dest="$TARGET/$rel"
  if [[ ! -e "$dest" ]]; then mkdir -p "$(dirname "$dest")"; cp "$src" "$dest"; added+=("$rel")
  elif ! cmp -s "$src" "$dest"; then skipped+=("$rel (differs from the template version; kept yours)")
  else skipped+=("$rel"); fi
done
if ! grep -q 'docs/standards/' "$AGENTS"; then
  notes+=("AGENTS.md doesn't point to docs/standards/. Add a section like:")
  notes+=("  ## Standards")
  notes+=("  Read the matching file before writing or reviewing code. Don't load these otherwise.")
  notes+=('  - C#/.NET code: `docs/standards/dotnet.md`')
fi

# --- Report ----------------------------------------------------------------
echo "Repo: $TARGET"
((${#notes[@]}))   && { echo; printf '  !! %s\n' "${notes[@]}"; }
((${#added[@]}))   && { echo; echo "Added:"; printf '  + %s\n' "${added[@]}"; }
((${#skipped[@]})) && { echo; echo "Already present (left alone):"; printf '  = %s\n' "${skipped[@]}"; }
echo
echo "Next:"
echo "  1. Fill in the TODOs in AGENTS.md (or ask your agent to, from the project files)."
if [[ ! -d "$TARGET/docs/agents" ]]; then
  echo "  2. Run /setup-matt-pocock-skills (issue tracker: GitHub). If it writes to CLAUDE.md,"
  echo "     re-run this script to move its block into AGENTS.md."
fi
echo "  3. Commit on a chore/ branch and open a PR into main."
