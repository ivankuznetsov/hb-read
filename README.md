# hb-read

[![CI](https://github.com/ivankuznetsov/hb-read/actions/workflows/ci.yml/badge.svg)](https://github.com/ivankuznetsov/hb-read/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A small, read-only Honeybadger CLI and portable Agent Skill for Codex, Claude Code, and Pi. It lists projects, error groups, error details, and occurrences without MCP or Docker.

This is an independent project and is not affiliated with or endorsed by Honeybadger Industries LLC.

## Why

`hb-read` is for error triage from a terminal or coding agent when a persistent integration is unnecessary. It has a deliberately narrow contract:

- documented Honeybadger Data API `GET` endpoints only
- credentials accepted through environment variables only
- recursive redaction of tokens, API keys, authorization headers, cookies, passwords, and secrets
- JSON output that works for both humans and agents
- no daemon, MCP server, or container

## Requirements

- Bash 3.2 or newer
- `curl`
- `jq` 1.6 or newer
- Python 3 only when running the test suite

Linux and macOS are supported. On Windows, use WSL.

## Install

Clone the repository and choose which agent should receive the skill:

```bash
git clone https://github.com/ivankuznetsov/hb-read.git
cd hb-read
./install.sh --agent codex
```

Available values are `codex`, `claude`, `pi`, `all`, and `none` for CLI-only installation. The CLI is installed to `~/.local/bin/hb-read` by default.

```bash
./install.sh --agent all
./install.sh --agent claude --prefix /usr/local
./install.sh --agent pi --force
```

Pi can also load the repository directly as a Git package:

```bash
pi install git:github.com/ivankuznetsov/hb-read@v1.0.0
```

The Git package gives Pi access to the bundled skill and CLI. Run `install.sh` as well if you want `hb-read` available globally on `PATH`.

### Skill locations

| Agent | Personal skill location |
| --- | --- |
| Codex | `${CODEX_HOME:-~/.codex}/skills/honeybadger-read` |
| Claude Code | `~/.claude/skills/honeybadger-read` |
| Pi | `~/.pi/agent/skills/honeybadger-read` |

## Authenticate

Create a personal authentication token in Honeybadger, then export it:

```bash
export HONEYBADGER_PERSONAL_AUTH_TOKEN='your-personal-token'
```

`HONEYBADGER_AUTH_TOKEN` is supported as a fallback. For Honeybadger's EU region, set the endpoint documented for your account:

```bash
export HONEYBADGER_ENDPOINT='https://eu-api.honeybadger.io'
```

`HONEYBADGER_API_URL` takes precedence when both endpoint variables are set.

## Use the CLI

```bash
# Discover project IDs
hb-read projects

# List recent error groups
hb-read faults 12345 --limit 10 --order recent

# Search and filter using Unix timestamps
hb-read faults 12345 \
  --query Timeout \
  --occurred-after 1785542400

# Inspect one error group
hb-read fault 12345 98765

# Fetch recent occurrences
hb-read notices 12345 98765 --limit 3
```

Add `--compact` before the command for single-line JSON:

```bash
hb-read --compact faults 12345 --limit 3
```

Run `hb-read help` for every option.

Honeybadger calls an error group a **fault** and an individual occurrence a **notice** in its Data API.

## Use the Agent Skill

After installation, ask your agent naturally:

```text
Show me the latest Honeybadger errors for this project.
Inspect the last three occurrences of fault 98765.
Find Timeout errors since this Unix timestamp.
```

You can also invoke the skill explicitly where supported:

```text
$honeybadger-read
/honeybadger-read
/skill:honeybadger-read
```

Explicit syntax varies by agent; automatic activation uses the skill description in `skills/honeybadger-read/SKILL.md`.

## Security model

The auth token is written to a mode-`0600` temporary curl configuration rather than included in process arguments. Temporary files are removed on exit. Responses and API errors pass through recursive redaction before output.

The CLI refuses non-HTTPS API origins except loopback HTTP for local testing. It does not expose arbitrary paths or HTTP methods, and it contains no create, update, or delete commands.

Honeybadger responses can still contain sensitive application data such as stack traces, request context, user details, and project names. Handle the output accordingly.

## Development

Run the hermetic test suite; it starts a local mock API and never needs Honeybadger credentials:

```bash
./tests/run.sh
```

Optional static analysis:

```bash
shellcheck bin/hb-read install.sh skills/honeybadger-read/scripts/hb-read tests/run.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution workflow.

## License

[MIT](LICENSE)
