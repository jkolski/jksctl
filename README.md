# JKSync

JKSync is a lightweight local-to-remote project sync tool for SSH-based workflows.

It is designed for a fast development loop:

```text
edit locally -> sync -> refresh remotely
```

The preferred commands are:

- `jksctl` - control CLI
- `jksd` - background daemon

The older `uspctl` / `uspd` names may remain as compatibility wrappers or symlinks during transition.

## Quick start

### 1. Choose where you want to work

Create or enter a local project/session directory:

```bash
cd ~/Desktop
mkdir my-project
cd my-project
```

You can use any normal working location: Desktop, Documents, a projects directory, or an external drive.

Key rule: run `jksctl` from inside your project directory. JKSync treats that directory as the session root.

### 2. Start JKSync interactively

```bash
jksctl open
```

On first run, JKSync guides you through setup and asks for:

- project name
- remote SSH host
- remote path
- pull interval
- file-change debounce
- whether rsync may delete remote files deleted locally

Then it initializes the project, performs an initial sync, and starts `jksd`.

### 3. Start JKSync non-interactively

For agents, scripts, and repeatable setups, pass all required values as flags:

```bash
jksctl open \
  --host user@server \
  --remote-path /var/www/project \
  --mode rsync \
  --background \
  --name my-project \
  -y
```

Useful optional flags:

```bash
jksctl open \
  --host user@server \
  --remote-path /var/www/project \
  --mode unison \
  --pull-interval 60 \
  --debounce 0.3 \
  --no-delete-remote \
  --background \
  --name my-project \
  -y
```

Preview without changing anything:

```bash
jksctl open --dry-run --json \
  --host user@server \
  --remote-path /var/www/project \
  --mode rsync \
  --name my-project \
  -y
```

Non-interactive mode is intended for:

- automation
- agents
- CI or repeatable scripts
- deterministic project setup

Agents should prefer non-interactive mode and avoid prompts.

## How it works

Local structure:

```text
project-root/
  .git/
  .gitignore
  worktree/
```

Rules:

- `.git/` belongs to the local session root only
- `worktree/` contains files synced to the remote path
- remote payload and local metadata should not be mixed

This keeps local tracking, daemon state, and remote files cleanly separated.

## Sync modes

### Preferred: `unison`

```bash
jksctl open --mode unison
```

Use Unison when it is available and works on both sides.

Benefits:

- two-way sync
- conflict-aware behavior
- better fit for bidirectional workflows

### Fallback: `rsync`

```bash
jksctl open --mode rsync
```

Use rsync when Unison is unavailable or simpler compatibility is more important.

Benefits:

- simple and widely available
- good local-to-remote push behavior
- reliable fallback path

JKSync automatically falls back to rsync if Unison is unavailable or fails during initial sync.

## Daemon

`jksctl open` starts `jksd` automatically, either in background mode or live mode.

The daemon:

- watches `worktree/` with `fswatch`
- pushes local changes
- periodically pulls/syncs remote updates
- logs changed relative paths, timestamps, and push durations
- performs graceful shutdown with final sync and commit steps

Background mode:

```bash
jksctl open --background
```

Live mode:

```bash
jksctl open --live
```

In live mode, `Ctrl+C` sends a graceful shutdown signal to the daemon.

## Commands

Initialize without starting the daemon:

```bash
jksctl init \
  --host user@server \
  --remote-path /var/www/project \
  --mode rsync \
  --name my-project \
  -y
```

Start / open:

```bash
jksctl open
jksctl start
jksctl go
jksctl up
```

Status and listing:

```bash
jksctl status
jksctl status --json
jksctl list
jksctl list --json
jksctl doctor
jksctl doctor --host user@server --remote-path /var/www/project
jksctl doctor --json
jksctl version
jksctl version --json
```

Logs:

```bash
jksctl logs
jksctl logs -n 200
```

Stop:

```bash
jksctl close
jksctl stop
jksctl halt
jksctl down
jksctl end
```

Remove:

```bash
jksctl remove
jksctl remove --path /absolute/path/to/project
jksctl remove --name my-project
jksctl remove --hard
```

`--hard` removes both registry state and the project directory from disk. Use it carefully.

Configuration:

```bash
jksctl config
jksctl config --language en
jksctl config --language pl
```

## Interactive vs non-interactive

Interactive mode is best for humans:

1. run `jksctl open`
2. answer prompts
3. start working in `worktree/`

Non-interactive mode is best for automation:

1. enter or create a project directory
2. run `jksctl open` with flags
3. verify with `jksctl status --json`
4. inspect logs if needed

Agent-friendly commands emit JSON where useful:

```bash
jksctl open --dry-run --json ...
jksctl status --json
jksctl list --json
jksctl doctor --json
jksctl version --json
```

If a project cannot be configured entirely through flags, it is not suitable for agent/CI usage yet.

## Internationalization

Supported languages:

- English, default
- Polish

Change language:

```bash
jksctl config --language en
jksctl config --language pl
```

Translations live in gettext-style `.po` files under `locale/`.

The CLI loads `.po` files directly, so no `.mo` compilation step is currently required.

## Config and state

State is stored per invoked command/config name.

Default `jksctl` path:

```text
~/.config/jksctl/
  state.json
  logs/
  run/
```

Legacy or alternate invocation names can use their own config namespace, for example:

```text
~/.config/uspctl/
```

When launched as `jksctl`, the tool can migrate a legacy `~/.config/uspctl/` setup on first run.

## Invocation flexibility

JKSync respects how it is invoked.

This allows symlinks and compatibility names:

```bash
ln -s $(which jksctl) ~/bin/my-sync
```

Config namespace follows the invoked control name unless overridden by environment variables.

## Requirements

Required tools:

- `git`
- `ssh`
- `rsync`
- `fswatch`

Optional:

- `unison`

On macOS:

```bash
brew install git rsync fswatch
brew install unison   # optional
```

## Safety and concurrency

JKSync uses a state lock under `~/.config/<name>/run/state.lock` to prevent concurrent state mutations.

`jksctl remove --hard` has extra guardrails and refuses obviously dangerous session roots. In non-interactive use, pass `--yes` explicitly.

`jksctl open` performs a layout preflight and warns when the session root contains payload-like files outside `worktree/` or when `worktree/` is already non-empty before initial sync.

## Exit codes

Stable exit code direction:

- `0` - OK
- `1` - runtime/sync error
- `2` - invalid CLI/config usage
- `3` - missing dependency
- `4` - remote unavailable
- `5` - active daemon/state conflict

## Security

JKSync:

- uses SSH for remote access
- does not include telemetry
- does not make hidden network calls
- should be used with SSH key authentication where possible

Do not put secrets into logs, command history, or project files.

## Philosophy

JKSync should stay:

- minimal
- transparent
- fast
- boring in the best way

Avoid:

- hidden behavior
- heavy configuration
- unnecessary abstractions
- framework or packaging complexity before the workflow is stable

## Current status

- Python implementation now
- source-first distribution for now
- macOS and Linux first
- Windows can start through WSL
- possible Go rewrite later, after UX stabilizes

## Author

J.KOL.SKI — Jakub Kołakowski

https://j.kol.ski

## License

MIT License.

See `LICENSE` for full text.
