# AGENTS.md

This file defines how coding agents and automation should work with JKSync.

## Required context

Before taking action in this project, agents must read:

- `README.md`
- `AGENTS.md`

`README.md` is the source of truth for user workflow, CLI usage, project initialization, and current behavior.

`AGENTS.md` defines execution constraints for agents.

## Core role

Agents are responsible for using JKSync in a predictable, repeatable way.

Agents should optimize for:

- zero prompts
- deterministic execution
- explicit parameters
- safe failure modes
- minimal hidden state

## Execution model

JKSync supports two operating styles.

### Interactive mode

Interactive mode is intended for humans.

It may ask questions and guide the user step by step.

Agents must not use interactive mode unless the task explicitly asks them to demonstrate or test the human prompt flow.

### Non-interactive mode

Non-interactive mode is required for normal agent use.

It is fully flag-driven and should not prompt.

Canonical pattern:

```bash
jksctl open \
  --host user@server \
  --remote-path /remote/path \
  --mode rsync \
  --background \
  --name project-name \
  -y
```

Agents must pass all required values as flags.

## Mandatory agent start flow

### 1. Ensure working directory

Agents must operate inside a project/session directory.

```bash
mkdir -p /target/path/to/project
cd /target/path/to/project
```

Do not run `jksctl open` from an unrelated parent directory.

### 2. Initialize or start project

Use non-interactive flags:

```bash
jksctl open \
  --host user@server \
  --remote-path /remote/path \
  --mode rsync \
  --background \
  --name project-name \
  -y
```

Use `--mode unison` only when Unison availability and behavior are acceptable for the target environment.

### 3. Verify state

After start, verify with JSON:

```bash
jksctl status --json
```

### 4. Observe logs when debugging

```bash
jksctl logs -n 50
```

## Directory model

Expected local layout:

```text
project-root/
  .git/
  .gitignore
  worktree/
```

Rules:

- `.git/` is local-only metadata in the session root
- `worktree/` is the synced remote payload
- agents must not mix remote payload into the session root
- agents should edit synced files under `worktree/`

## Config resolution

Default config path:

```text
~/.config/jksctl/
```

Contents:

```text
state.json
logs/
run/
```

Agents must rely on the default config resolution unless explicitly instructed otherwise.

Do not hardcode alternative paths in scripts or docs.

## Sync strategy

Priority:

1. `unison`, when available and appropriate
2. fallback to `rsync`

Agent rules:

- prefer explicit `--mode`
- do not assume Unison exists locally or remotely
- allow safe fallback behavior
- use `rsync` for simple one-way remote deployment loops

## Daemon behavior

Agents should assume:

- `jksctl open` starts `jksd`
- `--background` returns control to the caller
- `--live` is for humans or explicit debugging sessions
- the daemon handles sync automatically after startup
- shutdown final sync is bounded by `JKS_SHUTDOWN_SYNC_TIMEOUT` (default 10 seconds), so SSH/auth helper flows cannot block exit forever

Agents should close sessions explicitly when a task is done and a long-running daemon is not desired:

```bash
jksctl close --path /absolute/or/relative/session-root
jksctl close --name=my-project
```

`--name value` and `--name=value` are both supported by the CLI parser.

## Logging

Logs should remain useful for debugging and automation.

They should include:

- relative changed paths
- timestamps
- operation type/result
- durations where relevant

Agents may read logs, but should not change log format casually.

## Stable command set

Agents may use:

```bash
jksctl init
jksctl open
jksctl open --dry-run --json
jksctl status --json
jksctl list --json
jksctl logs
jksctl doctor --json
jksctl version --json
jksctl close
jksctl remove
jksctl config
```

Avoid relying on aliases in automation unless testing alias compatibility.

## Error handling

Agents must:

- use `--dry-run --json` before risky generated commands when practical
- fail fast on invalid parameters
- retry only when safe and justified
- avoid interactive recovery flows
- surface clear errors instead of waiting for prompts

If a task cannot be executed via flags, treat it as unsupported for agent automation until the CLI is extended.

## Security rules

Agents must:

- avoid exposing credentials in logs
- prefer SSH keys or existing SSH config
- not store secrets in project files
- not print tokens, passwords, or private keys

## Anti-patterns

Do not:

- parse human output when a `--json` form exists
- use interactive mode for normal agent work
- introduce hidden state
- modify config outside the expected config namespace
- rely on user input mid-run
- assume machine-specific paths unless provided
- mix session-root metadata with synced `worktree/` payload

## Future compatibility

New features should preserve automation compatibility.

When adding CLI behavior:

- keep flags stable
- preserve backward-compatible aliases where practical
- avoid changing default paths without migration
- make new prompts optional through flags
- update `README.md` and this file together

## Summary

Agents operate JKSync as a deterministic local-to-remote workflow engine.

For agents, non-interactive mode is the default contract.

## Implementation contracts now available

Agents can rely on these automation-oriented features:

- `jksctl init` initializes/configures without starting the daemon
- `jksctl open --dry-run --json` previews the plan without mutation
- `jksctl status --json` and `jksctl list --json` are machine-readable
- `jksctl doctor --json` reports dependency checks, and can check remote SSH/path/unison with `--host` and `--remote-path`
- `jksctl version --json` reports program/version/daemon metadata
- concurrent state-changing operations are protected by a lock file
- `remove --hard` has extra guardrails for non-interactive runs

