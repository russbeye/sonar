#!/usr/bin/env bash
# Builds fixture repos and state for the README screenshots. For each state it
# writes $OUT/<name>.screen, the terminal text around one real Sonar line and
# the real Starship prompt. docs/screenshot-terminal.sh turns those into PNGs.
#
# Rebuild the screenshots from the repo root:
#   out=$(mktemp -d) && docs/screenshot-fixtures.sh "$out" && docs/screenshot-terminal.sh "$out" docs
set -e
SONAR=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)/bin/sonar
OUT=${1:?out dir}
T=$(mktemp -d)
export XDG_CACHE_HOME=$T/cache XDG_RUNTIME_DIR=$T/run LANG=C.UTF-8
mkdir -p "$XDG_CACHE_HOME/sonar" "$XDG_RUNTIME_DIR/sonar/pane" "$XDG_RUNTIME_DIR/sonar/agents" "$OUT"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
now=$EPOCHSECONDS

commit() { # $1 repo, $2 minutes ago, $3 message
  GIT_AUTHOR_DATE="@$(( now - $2 * 60 ))" GIT_COMMITTER_DATE="@$(( now - $2 * 60 ))" \
    git -C "$1" commit -q --allow-empty -m "$3"
}
pane() { # $1 key, then status, ms, jobs, aws, ssh, PATH
  local k=$1; shift; printf '%s\n' "$@" > "$XDG_RUNTIME_DIR/sonar/pane/$k"
}
cache() { # $1 repo root, $2 ci line, $3 ports line. Fresh files stop a background refresh.
  local key=${1//\//%}
  printf '%s\n' "$2" > "$XDG_CACHE_HOME/sonar/$key.ci"
  printf '%s\n' "$3" > "$XDG_CACHE_HOME/sonar/$key.ports"
  : > "$XDG_CACHE_HOME/sonar/$key.lock"
}
dirty() { # $1 repo, $2 modified count, $3 untracked count
  local i
  for (( i = 1; i <= $2; i++ )); do echo a > "$1/m$i"; done
  git -C "$1" add . && commit "$1" "${4:-1}" files
  for (( i = 1; i <= $2; i++ )); do echo b >> "$1/m$i"; done
  for (( i = 1; i <= $3; i++ )); do echo c > "$1/u$i"; done
}
prompt_line() { # $1 dir, $2 exit status of the last command
  (cd "$1" && STARSHIP_SHELL= starship prompt --status "$2")
}
render() { # $1 name, $2 pane key, $3 dir, $4 width, $5 status, $6 command, $7 output, then extra env
  local name=$1 key=$2 dir=$3 w=$4 st=$5 cmd=$6 res=$7; shift 7
  # We lay the screen out the way the bash hook does outside tmux: the last
  # command and its output, a blank line, the Sonar line, then a fresh prompt.
  {
    printf '%s%s\n' "$(prompt_line "$dir" 0)" "$cmd"
    printf '%b\n\n' "$res"
    env "$@" "$SONAR" prompt "$key" "$dir" "$w"
    prompt_line "$dir" "$st"
  } > "$OUT/$name.screen"
}

# In flow: three files modified for 47 minutes, two commits not pushed, dev
# server and API up, one background job, CI running, one agent waiting.
git init -q --bare "$T/remote-proj.git"
git init -q -b feat/parser "$T/proj"; mkdir -p "$T/proj/src/parser"
dirty "$T/proj" 3 0 200
git -C "$T/proj" remote add origin "$T/remote-proj.git"; git -C "$T/proj" push -q -u origin feat/parser
commit "$T/proj" 60 "parse headers"; commit "$T/proj" 47 "parse bodies"
cache "$T/proj" "in_progress " "web:5173 api:8080"
: > "$XDG_RUNTIME_DIR/sonar/agents/s1"
pane flow 0 6100 1 "" "" "$PATH"
render flow flow "$T/proj/src/parser" 140 0 "pnpm test src/parser" '\e[32m ✓ 38 passed\e[0m (6.1s)'

# Trouble: kube context on prod, CI failed, last command exited 2 after 14.2s,
# Node 20 against a pin of 22, four commits behind, work 1h34 old.
mkdir -p "$T/kube" "$T/installs/node/20.11.1/bin"
printf 'apiVersion: v1\ncurrent-context: prod-eks\n' > "$T/kube/config"
printf '#!/bin/sh\necho v20.11.1\n' > "$T/installs/node/20.11.1/bin/node"; chmod +x "$T/installs/node/20.11.1/bin/node"
git init -q --bare "$T/remote-api.git"
git init -q -b fix/migrate "$T/api"; echo 22 > "$T/api/.nvmrc"
git -C "$T/api" add .nvmrc; commit "$T/api" 400 init
git -C "$T/api" remote add origin "$T/remote-api.git"; git -C "$T/api" push -q -u origin fix/migrate
git clone -q -b fix/migrate "$T/remote-api.git" "$T/api-other"
for i in 1 2 3 4; do commit "$T/api-other" 30 "upstream $i"; done
git -C "$T/api-other" push -q
dirty "$T/api" 5 1 94
git -C "$T/api" fetch -q
rm -rf "$T/api-other"
cache "$T/api" "completed failure" ""
rm -f "$XDG_RUNTIME_DIR/sonar/agents/"*
pane trouble 2 14200 0 "" "" "$T/installs/node/20.11.1/bin:$PATH"
render trouble trouble "$T/api" 140 2 "npm run migrate" \
  '\e[31mnpm error notsup Unsupported engine: wanted node 22, current node 20.11.1\e[0m' KUBECONFIG="$T/kube/config"

# Worktree: a worktree named after its long branch, in a 72-column split.
git init -q -b main "$T/crc"; commit "$T/crc" 300 init
git -C "$T/crc" worktree add -q -b feat/crc-calibration-larger-wins-baseline "$T/crc-calibration-larger-wins-baseline"
wt=$T/crc-calibration-larger-wins-baseline
dirty "$wt" 7 7 273
cache "$wt" "in_progress " ""
: > "$XDG_RUNTIME_DIR/sonar/agents/s1"; : > "$XDG_RUNTIME_DIR/sonar/agents/s2"
pane wt 0 3400 0 "" "" "$PATH"
render worktree-72 wt "$wt" 72 0 "pnpm test calibration" '\e[32m ✓ 112 passed\e[0m (3.4s)'

# Calm: clean tree, nothing running, CI green.
rm -f "$XDG_RUNTIME_DIR/sonar/agents/"*
git init -q -b main "$T/calm"; commit "$T/calm" 20 init
cache "$T/calm" "completed success" ""
pane calm 0 120 0 "" "" "$PATH"
render calm calm "$T/calm" 140 0 "git pull --rebase" 'Already up to date.'

rm -rf "$T"
