# sonar

A status line for the shell prompt, tmux, and Claude Code. It shows the state of
the work in the current pane.

## Install

Sonar runs from symlinks, so every caller keeps its usual path:

```bash
ln -sfn ~/Projects/sonar/bin/sonar ~/.local/bin/sonar
mkdir -p ~/.config/sonar
ln -sfn ~/Projects/sonar/hook.bash ~/.config/sonar/hook.bash
```

Sonar writes a cache to `${XDG_CACHE_HOME:-~/.cache}/sonar` and runtime state
to `${XDG_RUNTIME_DIR:-/tmp}/sonar`. Neither belongs in this repo.

## Integration

### ~/.bashrc

The hook reads Starship variables, so source it after Starship is set up.

```bash
# Sonar status line hook. It must come after Starship is set up.
[[ -f ~/.config/sonar/hook.bash ]] && source ~/.config/sonar/hook.bash
```

### ~/.config/tmux/tmux.conf

```tmux
# Sonar: a second status row that shows the state of the work in the active pane.
set -g status 2
set -g status-format[1] '#(~/.local/bin/sonar tmux #{pane_id} "#{pane_current_path}" #{client_width})'
```

### ~/.claude/settings.json

Add these entries under `hooks`. Each one is an entry in the event's list.

```json
"UserPromptSubmit": [
  { "matcher": "", "hooks": [{ "type": "command", "command": "~/.local/bin/sonar agent clear" }] }
],
"Notification": [
  { "matcher": "", "hooks": [{ "type": "command", "command": "~/.local/bin/sonar agent wait" }] }
],
"SessionEnd": [
  { "matcher": "", "hooks": [{ "type": "command", "command": "~/.local/bin/sonar agent clear" }] }
]
```

Add this at the top level:

```json
"statusLine": {
  "type": "command",
  "command": "in=$(cat); printf %s \"$in\" | ~/.local/bin/sonar claude",
  "refreshInterval": 5
}
```
