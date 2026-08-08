#!/usr/bin/env bash
set -euo pipefail

program=install.sh
agent=""
prefix=${PREFIX:-"$HOME/.local"}
force=false

usage() {
  printf '%s\n' \
    'Install BadgerPeek and its portable Agent Skill.' \
    '' \
    'Usage:' \
    '  ./install.sh --agent codex|claude|pi|all|none [--prefix PATH] [--force]' \
    '' \
    'Options:' \
    '  --agent NAME  Install the skill for one agent, every agent, or CLI only' \
    '  --prefix PATH Install the CLI under PATH/bin (default: ~/.local)' \
    '  --force       Replace files from an existing BadgerPeek installation' \
    '  -h, --help    Show this help'
}

die() {
  printf '%s: %s\n' "$program" "$*" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --agent) (($# >= 2)) || die "--agent requires a value"; agent=$2; shift 2 ;;
    --prefix) (($# >= 2)) || die "--prefix requires a value"; prefix=$2; shift 2 ;;
    --force) force=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$agent" in
  codex | claude | pi | all | none) ;;
  "") die "--agent is required" ;;
  *) die "--agent must be codex, claude, pi, all, or none" ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cli_source="$repo_root/skills/badgerpeek/scripts/badgerpeek"
skill_source="$repo_root/skills/badgerpeek"
cli_destination="$prefix/bin/badgerpeek"

[[ -f "$cli_source" ]] || die "CLI source not found: $cli_source"
[[ -f "$skill_source/SKILL.md" ]] || die "skill source not found: $skill_source/SKILL.md"

destinations=()
if [[ "$agent" == codex || "$agent" == all ]]; then
  destinations+=("${CODEX_HOME:-$HOME/.codex}/skills/badgerpeek")
fi
if [[ "$agent" == claude || "$agent" == all ]]; then
  destinations+=("$HOME/.claude/skills/badgerpeek")
fi
if [[ "$agent" == pi || "$agent" == all ]]; then
  destinations+=("$HOME/.pi/agent/skills/badgerpeek")
fi

if ! $force; then
  [[ ! -e "$cli_destination" ]] || die "$cli_destination already exists (use --force to replace it)"
  for destination in "${destinations[@]}"; do
    [[ ! -e "$destination" ]] || die "$destination already exists (use --force to replace it)"
  done
fi

install -d "$(dirname "$cli_destination")"
install -m 0755 "$cli_source" "$cli_destination"

for destination in "${destinations[@]}"; do
  install -d "$destination/scripts" "$destination/agents"
  install -m 0644 "$skill_source/SKILL.md" "$destination/SKILL.md"
  install -m 0755 "$skill_source/scripts/badgerpeek" "$destination/scripts/badgerpeek"
  install -m 0644 "$skill_source/agents/openai.yaml" "$destination/agents/openai.yaml"
  printf 'Installed skill: %s\n' "$destination"
done

printf 'Installed CLI: %s\n' "$cli_destination"
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) printf 'Add %s/bin to PATH to run badgerpeek directly.\n' "$prefix" ;;
esac
