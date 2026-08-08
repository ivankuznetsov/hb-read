#!/usr/bin/env python3
import sys
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    skill_dir = root / "skills" / "honeybadger-read"
    skill = skill_dir / "SKILL.md"
    text = skill.read_text(encoding="utf-8")

    if not text.startswith("---\n"):
        raise SystemExit("SKILL.md must start with YAML frontmatter")

    _, frontmatter, body = text.split("---", 2)
    fields = {}
    for line in frontmatter.strip().splitlines():
        key, separator, value = line.partition(":")
        if not separator:
            raise SystemExit(f"invalid frontmatter line: {line}")
        fields[key.strip()] = value.strip()

    if set(fields) != {"name", "description"}:
        raise SystemExit("frontmatter must contain only name and description")
    if fields["name"] != skill_dir.name:
        raise SystemExit("skill name must match its directory")
    if not fields["description"]:
        raise SystemExit("skill description must not be empty")
    if not body.strip():
        raise SystemExit("skill instructions must not be empty")

    metadata = (skill_dir / "agents" / "openai.yaml").read_text(encoding="utf-8")
    if "$honeybadger-read" not in metadata:
        raise SystemExit("OpenAI default prompt must invoke $honeybadger-read")

    print("portable skill validation passed")


if __name__ == "__main__":
    main()
