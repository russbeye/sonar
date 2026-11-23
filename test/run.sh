#!/usr/bin/env bash
# Checks for bin/sonar. Run: test/run.sh
# SONAR=<path> runs the same checks against another copy of the script, such as
# an older commit, to see which checks it fails.
#
# Most checks run sonar as a program against fixture repos in a temporary folder.
# Fake `ss` and `gh` commands on PATH stand in for the real listeners and CI.

here=$(cd "${BASH_SOURCE[0]%/*}" && pwd)
SONAR=${SONAR:-$here/../bin/sonar}
export LANG=C.UTF-8
T=$(mktemp -d)
export XDG_CACHE_HOME=$T/cache XDG_RUNTIME_DIR=$T/run
mkdir -p "$T/bin" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "$T"' EXIT

pass=0 fail=0
ok()  { pass=$((pass + 1)); printf 'ok    %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; [[ -n $2 ]] && printf '      %s\n' "$2"; }
check() { # $1 name, then a command that must succeed
  local name=$1; shift
  if "$@"; then ok "$name"; else bad "$name" "${DETAIL-}"; fi
  DETAIL=""
}
has() { [[ $1 == *"$2"* ]] || { DETAIL="no '$2' in: $1"; return 1; }; }
lacks() { [[ $1 != *"$2"* ]] || { DETAIL="unwanted '$2' in: $1"; return 1; }; }

plain() { sed 's/\x1b\[[0-9;]*m//g'; }
# One rendered line for a folder at a width, with escapes removed.
bar() { "$SONAR" prompt test "$1" "$2" | plain; }
# Every distinct line a folder renders at widths 140 down to 20.
bars() { local w; for (( w = 140; w >= 20; w-- )); do bar "$1" "$w"; done | sort -u; }

newrepo() { # $1 path, $2 branch
  git init -q -b "$2" "$1"
  git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# The fake ss prints one listener line for each "port pid" pair in $T/listeners.
cat > "$T/bin/ss" <<EOF
#!/usr/bin/env bash
while read -r port pid addr; do
  printf 'LISTEN 0      511        %s:%s 0.0.0.0:* users:(("x",pid=%s,fd=3))\n' "\${addr:-127.0.0.1}" "\$port" "\$pid"
done < "$T/listeners"
EOF
printf '#!/bin/sh\nexit 1\n' > "$T/bin/gh"
chmod +x "$T/bin/ss" "$T/bin/gh"
export PATH=$T/bin:$PATH
: > "$T/listeners"

# ---------- path ----------

newrepo "$T/proj" main
mkdir -p "$T/proj/src/parser"
check "path starts at the repo inside a subfolder" has "$(bar "$T/proj/src/parser" 140)" "proj/src/parser"
check "path shortens to repo/…/leaf when narrow" has "$(bars "$T/proj/src/parser")" "proj/…/parser"

# ---------- worktrees ----------

newrepo "$T/crc" main
git -C "$T/crc" worktree add -q -b feat/crc-calibration-larger-wins-baseline "$T/crc-calibration-larger-wins-baseline"
git -C "$T/crc" worktree add -q -b feat/other "$T/scratch"
line=$(bar "$T/crc-calibration-larger-wins-baseline" 140)
check "worktree named after its branch shows the repo and ⧉ only" has "$line" "crc ⧉ · ⎇ feat/crc-calibration-larger-wins-baseline"
check "worktree with another folder name shows the folder" has "$(bar "$T/scratch" 140)" "crc ⧉ scratch · "
check "main checkout shows no ⧉" lacks "$(bar "$T/crc" 140)" "⧉"

# ---------- branch forms ----------

all=$(bars "$T/crc-calibration-larger-wins-baseline")
check "long branch loses its middle first" has "$all" "⎇ feat/crc-calib…wins-baseline"
check "long branch then keeps the type and the last word" has "$all" "⎇ feat/…baseline"
git -C "$T/proj" checkout -q -b fix/aromatica-017-add-to-cart-flow-electron
all=$(bars "$T/proj")
check "branch with a ticket number keeps the number" has "$all" "⎇ fix/017…"
check "branch middle cut matches the pitch" has "$all" "⎇ fix/aromatica…flow-electron"
git -C "$T/proj" checkout -q -b feat/oauth2-login
check "digits inside a word are not a ticket number" lacks "$(bars "$T/proj")" "feat/2…"
for b in main feat/x averyveryverylongbranchnamewithoutanyslashatallinit; do
  git -C "$T/proj" checkout -q -b "$b" 2>/dev/null || git -C "$T/proj" checkout -q "$b"
  check "branch $b never renders as a bare ellipsis" lacks "$(bars "$T/proj")" "⎇ …"
done
git -C "$T/proj" checkout -q feat/x
check "a short form that is longer than the name is never used" lacks "$(bar "$T/proj" 1)" "feat/…x"
git -C "$T/proj" checkout -q --detach
check "detached HEAD shows the short SHA" has "$(bar "$T/proj" 140)" "⎇ $(git -C "$T/proj" rev-parse --short=7 HEAD)"

# ---------- shorten before drop ----------

git -C "$T/proj" checkout -q main
echo x > "$T/proj/dirty"
all=$(bars "$T/proj/src/parser")
dial=$(grep -c -E '◔ ·|◔ *$' <<<"$all")
check "drift dial shows without its time at some width" test "$dial" -gt 0
# At the widest width that drops the dial, the path must already be at its shortest form.
first_drop=$(for (( w = 140; w >= 20; w-- )); do l=$(bar "$T/proj/src/parser" "$w"); [[ $l != *◔* ]] && { echo "$l"; break; }; done)
check "segments shorten before the drift dial drops" lacks "$first_drop" "/"
check "the path is at its shortest form when the dial drops" has "$first_drop" "  proj · ⎇"

# ---------- width ----------

fits() { # $1 dir: no rendered line is wider than its width
  local w l
  for w in 140 100 72 56; do
    l=$(bar "$1" "$w"); l=${l%"${l##*[! ]}"}
    (( ${#l} <= w )) || { DETAIL="width $w: ${#l} columns: $l"; return 1; }
  done
}
check "lines fit at 140, 100, 72 and 56 in a worktree" fits "$T/crc-calibration-larger-wins-baseline"
check "lines fit at 140, 100, 72 and 56 in a subfolder" fits "$T/proj/src/parser"

# ---------- ports on the bar ----------

listen() { # $1 folder: starts a process there and sets LPID to its PID
  # The process must not hold this shell's stdout, or a caller in $( ) waits for it.
  (cd "$1" && exec sleep 300) >/dev/null 2>&1 & LPID=$!; pids+=("$LPID")
}
listen "$T/proj"; pid=$LPID
key=${T//\//%}%proj
ports() { rm -f "$XDG_CACHE_HOME/sonar/$key".*; "$SONAR" refresh "$T/proj"; cat "$XDG_CACHE_HOME/sonar/$key.ports"; }
read -r lo hi < /proc/sys/net/ipv4/ip_local_port_range
eph=$(( lo + 1 ))

printf '%s %s\n' 5173 "$pid" "$eph" "$pid" > "$T/listeners"
check "an ephemeral port stays off the bar" test "$(ports)" = ":5173"
printf 'web=5173\ndev=%s\n' "$eph" > "$T/proj/.sonar"
check "named ports show by name, even in the ephemeral range" test "$(ports)" = "web:5173 dev:$eph"
rm "$T/proj/.sonar"
printf '%s %s\n' 3000 "$pid" 5173 "$pid" 8787 "$pid" 9000 "$pid" 9001 "$pid" > "$T/listeners"
check "the bar shows 3 ports, then +N" test "$(ports)" = ":3000 :5173 :8787 +2"

printf '%s\n' '$(touch '"$T"'/pwned)' "web=5173;touch $T/pwned2" '`touch '"$T"'/pwned3`' > "$T/proj/.sonar"
ports >/dev/null; bar "$T/proj" 140 >/dev/null
check "a .sonar file never runs code" test ! -e "$T/pwned" -a ! -e "$T/pwned2" -a ! -e "$T/pwned3"
rm "$T/proj/.sonar"

# ---------- sonar ports ----------

printf '%s %s\n' 5173 "$pid" "$eph" "$pid" > "$T/listeners"
out=$(cd "$T/proj" && "$SONAR" ports 2>&1)
check "sonar ports prints the pitch columns" has "$out" "PORT    PID      NAME         AGE   BAR  NOTE"
check "sonar ports marks a fixed port in this repo as on the bar" grep -qE "^:5173 +$pid +sleep +[0-9]+m +yes" <<<"$out"
check "sonar ports marks an ephemeral port as off the bar" grep -qE "^:$eph +$pid +sleep +[0-9]+m +no" <<<"$out"
check "sonar ports does not call a child of this shell an orphan" lacks "$out" "orphan"

in_sonar() { ( source "$SONAR" >/dev/null 2>&1 || exit 1; "$@" ); }
check "sourcing sonar runs no subcommand" test -z "$(source "$SONAR" 2>&1)"
check "PID 1 as parent means orphan" in_sonar is_orphan 1
check "a live shell as parent does not mean orphan" in_sonar eval '! is_orphan $$'

listen "$T"; victim=$LPID
start=$(in_sonar eval "proc_info $victim && echo \$P_START")
in_sonar confirm_kill "$victim" "$start" 1 1m "$T" sleep <<<"" >/dev/null
check "confirm_kill keeps the process on an empty answer" test -d "/proc/$victim"
in_sonar confirm_kill "$victim" "$(( start + 1 ))" 1 1m "$T" sleep <<<"y" >/dev/null
check "confirm_kill keeps a process whose start time changed" test -d "/proc/$victim"
in_sonar confirm_kill "$victim" "$start" 1 1m "$T" sleep <<<"y" >/dev/null
sleep 0.2
check "confirm_kill sends SIGTERM on y" test ! -d "/proc/$victim" -o "$(awk '{print $3}' "/proc/$victim/stat" 2>/dev/null)" = Z

# ---------- adversarial cases ----------

errs() { # $1 dir: any stderr from renders at every width
  local w; for (( w = 140; w >= 1; w -= 7 )); do "$SONAR" prompt test "$1" "$w" 2>&1 >/dev/null; done
}
for d in "$T/proj/src/parser" "$T/crc-calibration-larger-wins-baseline" "$T/scratch" "$T" /; do
  e=$(errs "$d"); DETAIL=$e
  check "no stderr from renders in ${d#"$T"}" test -z "$e"
done
check "a width of 1 still ends and keeps the priority 1 segments" has "$(timeout 5 "$SONAR" prompt test "$T/proj" 1 | plain)" "proj · ⎇ main"

git init -q --bare "$T/bare.git"
git -C "$T/proj" push -q "$T/bare.git" main 2>/dev/null
git -C "$T/bare.git" worktree add -q "$T/bwt" main 2>/dev/null
check "a worktree of a bare repo shows the bare repo name" has "$(bar "$T/bwt" 140)" "bare ⧉ bwt · ⎇ main"

git init -q -b main "$T/empty"
e=$("$SONAR" prompt test "$T/empty" 140 2>&1 >/dev/null); DETAIL=$e
check "a repo with no commits renders without errors" test -z "$e"
check "a folder outside any repo shows no branch" lacks "$(bar "$T" 140)" "⎇"

printf '%s %s %s\n' 5173 "$pid" "[::]" > "$T/listeners"
check "an IPv6 listener on a fixed port shows on the bar" test "$(ports)" = ":5173"

listen "$T/proj"; dup=$LPID
printf '%s %s\n' 5173 "$pid" 5174 "$dup" > "$T/listeners"
out=$(cd "$T/proj" && "$SONAR" ports 2>&1)
check "two listeners with one command in one folder are duplicates" grep -qE "^:5174 +$dup .*duplicate of $pid" <<<"$out"

(cd "$T/proj" && exec bash -c 'sleep 300 & exec sleep 301') >/dev/null 2>&1 & parent=$!; pids+=("$parent")
sleep 0.2
child=$(pgrep -P "$parent" sleep); pids+=("$child")
printf '%s %s\n' 5173 "$parent" 5175 "$child" > "$T/listeners"
out=$(cd "$T/proj" && "$SONAR" ports 2>&1)
check "a listener started by another listener is its child" grep -qE "^:5175 +$child .*child of sleep $parent" <<<"$out"
check "a child of a listener is not an orphan" lacks "$(grep "^:5175" <<<"$out")" "orphan"

listen "$T"; victim=$LPID
printf '%s %s\n' 5173 "$victim" > "$T/listeners"
# Without a terminal, --kill-strays cannot ask, so it must kill nothing. The
# victim is a child of this shell and not an orphan, so we fake its listing as
# one by running the confirmation path directly with no terminal.
in_sonar eval "proc_info $victim; confirm_kill $victim \$P_START 5173 1m $T sleep < /dev/null" >/dev/null
check "confirm_kill kills nothing when stdin is closed" test -d "/proc/$victim"
setsid -w "$SONAR" ports --kill-strays </dev/null >/dev/null 2>&1
check "sonar ports --kill-strays with no terminal kills nothing" test -d "/proc/$victim"

# ---------- render time ----------

median_ms() { # $1 dir: median of 20 prompt renders, startup included
  local i s e t=()
  for i in {1..20}; do
    s=$EPOCHREALTIME; "$SONAR" prompt test "$1" 140 >/dev/null; e=$EPOCHREALTIME
    t+=($(( (${e/./} - ${s/./}) / 1000 )))
  done
  printf '%s\n' "${t[@]}" | sort -n | sed -n 10p
}
ms=$(median_ms "$here/..")
DETAIL="median ${ms} ms"
check "median render in this repo is 25 ms or less (was $ms ms)" test "$ms" -le 25

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
