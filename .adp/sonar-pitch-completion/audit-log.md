# Audit Log: sonar-pitch-completion

Source specification: the "Sonar Status Line" pitch artifact at
https://claude.ai/artifact/7tj4DYZnobmEsVNL5kKerB (version 1795392286-bbd0, read 2026-11-22).
Baseline code: `bin/sonar` and `hook.bash` at commit `c944908`.

## Problem Statement
**What the problem is:** The pitch artifact specifies Sonar behavior that `bin/sonar` at `c944908` does not implement. The work is to close each gap below so that the live bar behaves as the pitch describes. Each gap names what the pitch says and what the code does now.

1. Shorten before drop. The pitch says that segments get shorter before any segment is dropped. The code only drops segments (`render`, lines 277-285). The shorter forms that the pitch names are these:
   - A long branch name loses its middle (`feat/crc-calib…wins-baseline`), then keeps only the type and the last word (`feat/…baseline`). When the branch has a ticket number, the second form is the type and the number (`fix/017…`).
   - The drift dial loses its time and keeps the glyph.
   - The path goes from `repo/sub/dir` to `repo/…/dir` to `repo`.
   - The agents segment goes from `✦ 2 waiting` to `✦2`.
2. Repo-relative path. Inside a repo, the pitch says that the path starts at the repo name. The code abbreviates parents from the home folder (`seg_path`, lines 111-131).
3. Worktree path. In a linked worktree, the pitch says that the path is the main repo name and `⧉`. The folder name appears only when the folder name differs from the branch name. The code has no worktree handling.
4. Fixed ports only. The pitch says that the bar hides ports in the kernel ephemeral range. The code shows every listener whose working directory is inside the repo (`refresh`, lines 49-56).
5. Named ports. The pitch says that a `.sonar` file in the repo names ports (`web=5173`). A named port shows as `web:5173`, even inside the ephemeral range. The code reads no `.sonar` file.
6. Port cap. The pitch says that the bar shows 3 ports at most, then `+N`. The code has no cap.
7. `sonar ports` subcommand. The pitch says that `sonar ports` lists every listener with the columns PORT, PID, NAME, AGE, BAR, and NOTE. The listing flags orphans and duplicates, and it offers `--kill-strays`. The code has no such subcommand.
8. Danger rule. The pitch says that a red rule runs across the top of the bar when the danger segment shows. The code colors the segment red but draws no rule.

**What the problem is not:**
- It is not a rewrite. Segments that already match the pitch stay as they are: danger, remote host, git counts, last command, CI, toolchain drift, agents, jobs, and the drift dial glyphs and thresholds.
- It does not add a Starship render mode. The pitch says only that the script "can render" as the last line of a Starship prompt, and the existing `prompt` mode already prints an ANSI line.
- It does not change `hook.bash`, the tmux config, `~/.bashrc`, or `~/.claude/settings.json`, unless a gap above cannot close without such a change. Any such change gets its own Decision Log entry.
- It does not add network calls to the render path. The pitch budget is 0 network calls on the hot path.
- It does not change the Tokyo Night colors or the glyph set.

**Human-level definition of done:** Each scenario in the pitch mockup (Calm, In flow, Many ports, Worktree, Trouble, Over SSH) looks on the real bar as it does in the mockup, at 140, 100, 72, and 56 columns. In a narrow split, the branch name and the path get shorter before any segment goes away. Path, branch, failures, and danger never go away. In a repo where Vite and its workers hold many ports, the bar shows only the fixed port, and `sonar ports` shows the rest with orphans flagged. A prompt render still takes less than 25 ms, and a slow `gh` call or port scan never stalls the shell.
**Confirmed by:** developer   **Date:** 2026-11-22
**Revision history:** The developer locked two scope calls at the Phase 1 gate. Gap 7 stays in scope, but `--kill-strays` must ask for confirmation before it kills a process, and the render path must never call it. Gap 8 is out of scope. tmux cannot draw a rule above the status row without a third row, so the solid red danger segment is the only danger signal.

## Knowledge Gap Document
| Known | Inferred (flagged) | Cannot Determine |
|-------|--------------------|------------------|
| `bin/sonar` needs bash 5.3 or later. It uses the `${ cmd; }` command substitution that does not fork, and the host runs bash 5.3.20. | A `.sonar` file holds one `name=port` pair per line, as in the pitch example `web=5173`. The pitch shows no other format. | CD1: What "orphan" means in `sonar ports`. |
| The kernel ephemeral range on this host is 32768 to 60999, from `/proc/sys/net/ipv4/ip_local_port_range`. | A "fixed port" is any port outside that range. The pitch says only that ports in the ephemeral range stay hidden. | CD2: What "duplicate" means in `sonar ports`. |
| A prompt render inside this repo takes 22 to 28 ms, over 5 runs and with process startup included. The pitch budget is less than 25 ms, so the baseline already exceeds the budget on some runs. | The ticket-number form of a branch takes the first group of digits in the branch name. The pitch example `fix/aromatica-017-add-to-cart-flow-electron` becomes `fix/017…`. | CD3: Which processes `--kill-strays` kills. |
| `refresh` gets each listener from `ss -Hltnp` and keeps the listener when `/proc/PID/cwd` is inside the repo. `ss` shows a PID only for processes that the current user owns. | Worktree detection can use `git rev-parse --git-common-dir`. A linked worktree returns a path outside its own top level. | CD4: Whether the 25 ms budget includes process startup, as tmux and the bash hook pay it. |
| `render` drops segments by priority and has no shorter forms (lines 277-285). Each segment stores one width and one styled text. | Each extra `git` call on the render path costs about 2 to 5 ms. That estimate comes from the convention of fork cost for small `git` commands, and I did not measure it. | CD5: Whether Sonar must run on hosts other than this one, for example the SSH build boxes in the "Over SSH" scenario, with an older bash. |
| `kubectl` is not installed. `seg_danger` reads the kubeconfig file directly, so the danger segment does not need `kubectl`. | | |
| The repo has no tests and no test harness. | | |

## Open Questions (resolve before Phase 3)
1. CD1: Does "orphan" mean a listener whose parent process is gone, so that PID 1 or a subreaper now owns it? → Yes. The developer confirmed this definition on 2026-11-22.
2. CD2: Does "duplicate" mean two or more listeners with the same command line and the same working directory? → Yes. The developer confirmed this definition on 2026-11-22.
3. CD3: Does `--kill-strays` kill orphans only, with duplicates shown as a note and never killed? → Yes. The developer confirmed on 2026-11-22. The Phase 1 call also holds: the option asks for confirmation before it kills.
4. CD4: Does the 25 ms budget include process startup? If yes, the baseline already misses the budget on some runs, and this task must not make it slower. → Yes. The developer confirmed on 2026-11-22. The budget includes startup, and the task must not raise the median render time above the 23 ms baseline median.
5. CD5: Does Sonar run only on this host with bash 5.3? → Yes. The developer confirmed on 2026-11-22. No portability to older bash is required.

## Recommendation Brief
**Recommended approach:** Keep Sonar as one bash file, and extend the segment record so that each segment carries its forms, longest first. The record becomes `side<TAB>priority<TAB>width<TAB>text`, then more `width<TAB>text` pairs, one for each shorter form. `render` runs two passes, the same as the `fit()` function in the pitch mockup. Pass 1 moves the segment with the largest priority number that still has a shorter form to its next form, until the line fits or no segment can get shorter. Pass 2 drops segments by priority, as the code does now. The other gaps close like this:
- Path and worktree: one `git rev-parse --show-toplevel --git-common-dir --show-prefix` call replaces the existing `--show-toplevel` call in `collect`. That call gives the repo root, the main repo for a worktree, and the subdirectory, with no extra fork.
- Branch forms: pure string operations in `seg_git`, with no extra fork. The forms are the full name, the name with its middle cut, and then either `type/…lastword` or `type/NNN…` when the name holds a group of digits.
- Ports: `refresh` reads the ephemeral range and the repo `.sonar` file. It keeps fixed ports and named ports, caps the list at 3 plus `+N`, and writes the finished text to the cache. The render path still only reads one cache file.
- `sonar ports`: a new subcommand that never runs on the render path. It reads `ss -Hltnp` and `/proc/PID/{stat,cmdline,cwd}`, and prints PORT, PID, NAME, AGE, BAR, and NOTE. `--kill-strays` lists the orphans, asks once for confirmation, then sends SIGTERM.
- Tests: a guard around the dispatch `case` lets a test script source `bin/sonar` and call its functions. A plain bash test script at `test/run.sh` builds fixture repos in a temporary folder and checks each gap.

**Defense:** The pitch fixes the budget at one bash file, 0 network calls on the hot path, and less than 25 ms per render. The developer confirmed that the budget includes startup and that the 23 ms median must not rise (CD4). This approach adds no fork to the render path. The worktree and path data come from flags on a `git` call that already runs, and the branch and drift forms come from string operations on data that the code already has. All port work moves into `refresh`, which already runs in the background. The two-pass layout is the algorithm that the pitch mockup itself runs, so the real bar and the mockup shorten and drop in the same order.

**Alternatives considered:**
| Alternative | Reason rejected |
|-------------|-----------------|
| Rewrite Sonar as a compiled binary in Go or Rust | A binary renders faster, but the pitch commits to one bash file, and the task is to close gaps, not to rewrite (Problem Statement exclusions). |
| Call each segment function again with a level argument to get a shorter form | Segments such as git and drift fork for their data, so a second call adds forks on the render path and breaks the CD4 budget. |
| Filter and cap ports at render time | Render would need to read the `.sonar` file and the ephemeral range on every prompt. That adds file reads to the hot path for data that changes rarely. |
| Put `sonar ports` in a second script | The pitch says one file. A second script also needs its own install symlink and its own copy of the port parsing code. |
| Detect a worktree by reading the `.git` file by hand | This saves no fork, because `collect` already calls `git rev-parse`. Hand parsing also misses git edge cases that `rev-parse` handles, such as `GIT_DIR` set in the environment. |
| Use bats for tests | The repo has no test harness, and bats is a new dependency. A plain bash script covers fixture repos and string checks without one. |

**Assumptions this depends on:**
- A1: A listener is an orphan when its parent is PID 1, or when its parent's command is `systemd --user`, which adopts orphaned user processes as a subreaper. Confidence MEDIUM, INFERENCE FROM CONVENTION.
- A2: The flags `--git-common-dir --show-prefix` add no measurable time to the existing `git rev-parse` call. Confidence MEDIUM, INFERENCE FROM CONVENTION. I verify this with a timing run in Phase 5.
- A3: A `.sonar` file holds one `name=port` pair per line. Blank lines and lines that start with `#` are ignored. Confidence MEDIUM, INFERENCE FROM CONVENTION from the pitch example.
- A4: The ticket form of a branch uses the first group of digits in the name. Confidence MEDIUM, INFERENCE FROM CONVENTION from the pitch example.
- A5: tmux and the terminal draw `…` and `⧉` as one column each, so the width arithmetic counts each as 1. Confidence MEDIUM, INFERENCE FROM CONVENTION.
- A6: A guard around the dispatch `case` does not change how tmux, the bash hook, or Claude Code run `bin/sonar`. Confidence HIGH, DIRECT EVIDENCE, because all three run the file as a program and none sources it.

## Pre-Mortem Report
Assumed: this implementation failed in production. Most likely causes:
| Failure mode | Likelihood | Impact | Developer response (rebuttal or mitigation) | Monitoring signal | Implemented at |
|--------------|------------|--------|---------------------------------------------|-------------------|----------------|
| PM-1: `sonar ports --kill-strays` kills a server that the developer wants running, for example the ADP mission control server. | H | H | Mitigation, confirmed by the developer on 2026-11-22. On 2026-11-22 I read the live process table. Five ADP servers listen with parent PID 1160, which is `/usr/lib/systemd/systemd --user`. They detach from the shell on purpose. Under the CD1 and A1 rule, all five count as orphans, including the server for this run. Their cgroup is an app scope, the same as a GUI app, so cgroups do not separate them. Their working directories are skill folders or project folders, so the working directory does not separate them either. The design change is that `--kill-strays` asks y/N for each orphan, with N as the default. Each question shows the PID, port, age, working directory, and full command line. The option sends SIGTERM only. | The count of processes that `--kill-strays` terminates without a `y` answer typed for that PID. It fires at a count above 0. A process that exits by itself between the listing and the question gives the nearest benign look-alike, and the per-process prompt then reports "already gone" and does not count it. | `bin/sonar` § "confirm_kill() { # $1 pid, $2 start ticks seen in the listing, $3 port, $4 age, $5 cwd, $6 command" (line 474, advisory) |
| PM-2: `--git-common-dir` returns a relative path (`.git`) in the main worktree, so a naive comparison reads every main checkout as a linked worktree and shows `⧉` everywhere. | H | M | Mitigation. Call `git rev-parse --path-format=absolute --show-toplevel --git-common-dir --show-prefix`. git 2.56.0 on this host supports `--path-format`, which arrived in git 2.31. A repo is a linked worktree only when the common directory is not `<toplevel>/.git`. | The `⧉` glyph shows in a repo that `git worktree list` reports as the main worktree. It fires at any occurrence. A bare-repo worktree layout gives the nearest benign look-alike, where every checkout is linked and `⧉` is correct. | `bin/sonar` § "--path-format=absolute --show-toplevel --git-common-dir --show-prefix" (line 408, advisory) |
| PM-3: The two-pass layout makes a render slower than the 23 ms median baseline (CD4). | M | M | Mitigation. The layout loop uses only the `${ ; }` substitution, which does not fork, and arithmetic. `test/run.sh` times 20 renders in this repo and fails when the median exceeds 25 ms. That threshold leaves 2 ms of headroom over the baseline for machine noise. | The median of 20 `sonar prompt` runs in this repo, from `test/run.sh`. It fires above 25 ms. Another heavy process on the machine gives the nearest benign look-alike, and running the baseline commit `c944908` at the same time tells the two apart. | `test/run.sh` § "median render in this repo is 25 ms or less" (line 171, advisory) |
| PM-4: Width arithmetic miscounts glyphs such as `…`, `⧉`, and `⎇`, so the bar shortens too early or overflows the pane. | M | M | Mitigation. Every width comes from `${#var}` on plain text before styling, and bash counts characters when the locale is UTF-8. The shell and tmux run with `LANG=en_US.UTF-8` on this host. `test/run.sh` checks that the visible width of each rendered line, with escapes removed, is not larger than the requested width at 140, 100, 72, and 56 columns. | The visible length of a rendered line, with escapes removed, compared with the width argument. It fires when the line is longer by 1 column or more. A tmux pane whose width changed during the render gives the nearest benign look-alike, and it corrects itself on the next refresh. | `test/run.sh` § "fits() { # $1 dir: no rendered line is wider than its width" (line 100, advisory) |
| PM-5: A branch name with no slash, a detached SHA, or a very short name produces a broken short form, such as a bare `…`. | M | L | Mitigation. A shorter form exists only when it is shorter than the form before it and keeps at least 4 characters of the name. `test/run.sh` covers `main`, a 7-character SHA, `feat/x`, the two pitch examples, and a 60-character name with no slash. | Any rendered branch text that is only `…` or that starts with `…`. It fires at any occurrence. No benign condition produces this text. | `bin/sonar` § "(( ${#f} < ${#prev} )) && BRANCH_FORMS+=("$f")" (line 219, advisory) |
| PM-6: A `.sonar` file in a cloned repo runs code when Sonar reads it. | L | H | Mitigation. `refresh` reads `.sonar` line by line with `read`, and it accepts only lines that match `^[A-Za-z0-9_-]+=[0-9]+$`. Sonar never sources or evaluates the file. `test/run.sh` feeds a `.sonar` file that holds `$(touch pwned)` and checks that no file named `pwned` appears. | A file that a `.sonar` line names appears after a render. It fires at any occurrence. No benign condition produces it. | `bin/sonar` § "[[ $line =~ ^([A-Za-z0-9_-]+)=([0-9]+)$ ]]" (line 79, advisory) |
| PM-7: The ephemeral-range filter hides a dev server that listens on a port in 32768 to 60999. | L | L | Rebuttal. The pitch hides those ports on purpose. A port named in `.sonar` shows even inside the range, and `sonar ports` lists every listener. | — | — |
| PM-8: After the upgrade, the bar shows the old unfiltered port list from a cache file in the old format. | M | L | Rebuttal. `PORT_TTL` is 15 s, so `refresh` rewrites the cache within 15 s of the first render after the upgrade. The old cache text renders as plain port numbers and does not break the line. | — | — |
| PM-9: The dispatch guard that lets tests source `bin/sonar` changes how a caller runs Sonar. | L | M | Rebuttal. tmux, the bash hook, and Claude Code run `~/.local/bin/sonar` as a program, and none of them sources it (A6, DIRECT EVIDENCE from `tmux.conf:110`, `hook.bash`, and `settings.json:129-159`). | — | — |

## Implementation Authorization
All HIGH-likelihood items resolved: YES
Authorized by: developer, 2026-11-22

## Decision Log

### [DL-001] Each segment record carries its forms
- **Decision:** `add` takes the side, the priority, then one width and text pair for each form, longest form first. It joins all of them with tabs into one `SEGS` entry.
- **Alternatives considered:** A second array for the shorter forms, indexed in parallel with `SEGS`. A segment function that takes a level argument and runs again.
- **Rationale:** One record for each segment keeps the forms next to the priority that controls them, and segments with one form need no change at their `add` call. A parallel array can fall out of step with `SEGS`. Running a function again forks again (Recommendation Brief).
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the smoke run on 2026-11-22 rendered single-form and multi-form segments at 140, 40, and 20 columns.
- **Assumptions:** Styled text never holds a tab.
- **Monitoring signal:** A rendered line that holds a raw width number or a split segment — fires at any occurrence — distinguishes: a branch name with digits, which is real text and sits after `⎇`.
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED — 2026-11-22: `test/run.sh` passes 33 of 33 checks, and every rendered line in the width checks holds whole segments.

### [DL-002] Shorten by priority, and let priority 1 segments shorten
- **Decision:** Pass 1 moves one step at a time. Each step picks the kept segment with the largest priority number that still has a shorter form, and the first such segment wins a tie. Priority 1 segments, such as path and branch, can shorten but never drop.
- **Alternatives considered:** Shorten every segment to its shortest form at once. Shorten only segments with a priority number above 1.
- **Rationale:** The pitch mockup's `fit()` moves one level at a time, and it lets the branch and the path shorten. The pitch "Shorten, then drop" rule names long branch names as the first thing to shorten. Shortening everything at once would hide detail that fits.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the `fit()` function in the pitch artifact, version 1795392286-bbd0.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-003] Read git status before any segment is added
- **Decision:** The status loop moves from `seg_git` into `git_read`, which sets `GIT_*` globals. `collect` calls `git_read` before `seg_danger`, and `seg_git` only builds text.
- **Alternatives considered:** Run `seg_git` first and reorder `SEGS` afterwards. Read the branch with a second `git` call inside the path segment.
- **Rationale:** The worktree path needs the branch name, but the path shows before the branch on the bar. Reordering `SEGS` hides the display order in the layout code. A second `git` call adds a fork to the render path (CD4).
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — `collect` in `bin/sonar` still runs one `git status` call.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-004] The middle cut keeps 14 leading and 13 trailing characters
- **Decision:** A branch name longer than 28 characters keeps its first 14 and its last 13 characters with `…` between them. A separator at the inner edge of either part is removed.
- **Alternatives considered:** A cut that scales with the pane width. A cut at word boundaries only.
- **Rationale:** These numbers reproduce both pitch examples exactly: `feat/crc-calib…wins-baseline` and `fix/aromatica…flow-electron`. A cut that scales with the width needs the layout to call back into the segment, which DL-001 avoids.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — both pitch strings, which `test/run.sh` checks.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-005] A ticket number is a group of digits between separators
- **Decision:** The ticket form uses the first group of digits that sits between `-`, `_`, or the edges of the name after the type. This refines A4.
- **Alternatives considered:** The first group of digits anywhere, which is A4 as written.
- **Rationale:** Under A4, `feat/oauth2-login` gives `feat/2…`, and that is not a ticket. The pitch example `fix/aromatica-017-add-to-cart-flow-electron` still gives `fix/017…`.
- **Confidence:** MEDIUM
- **Confidence basis:** INFERENCE FROM CONVENTION — ticket ids in branch names usually stand between hyphens.
- **Assumptions:** Branch names in the developer's repos put ticket numbers between separators.
- **Monitoring signal:** A narrow bar shows `type/NNN…` where NNN is not a ticket number — fires at any occurrence the developer notices — distinguishes: a version number in a branch name, such as `bump-node-22`, which also reads as a ticket.
- **Created:** 2026-11-22, Phase 5
- **Status:** OPEN

### [DL-006] A worktree folder counts as named after the branch in three ways
- **Decision:** The worktree folder is hidden when it equals the branch, the branch with `/` replaced by `-`, or the last path part of the branch.
- **Alternatives considered:** Hide the folder only on an exact match with the branch.
- **Rationale:** A folder name cannot hold `/`. So the pitch case, a folder `crc-calibration-larger-wins-baseline` for branch `feat/crc-calibration-larger-wins-baseline`, never matches exactly. The pitch shows only `crc ⧉` for that case.
- **Confidence:** MEDIUM
- **Confidence basis:** INFERENCE FROM CONVENTION — tools that create worktrees name the folder after the last part of the branch, or after the branch with slashes replaced.
- **Assumptions:** No other naming scheme is in use.
- **Monitoring signal:** A worktree bar shows a folder name that repeats the branch name — fires at any occurrence — distinguishes: a folder that shares only a prefix with the branch, which is a different name and shows correctly.
- **Created:** 2026-11-22, Phase 5
- **Status:** OPEN

### [DL-007] The repo name is always bold, and the subdirectory is dim
- **Decision:** Inside a repo, the repo name renders bold blue at every depth, and `/sub/dir` follows it in dim.
- **Alternatives considered:** Keep the old rule, which made the name bold only at the repo root.
- **Rationale:** The pitch "In flow" scenario shows `proj` bold with `/src/parser` dim. The old rule made the deepest folder bold, and under the new path the deepest folder is no longer the first word.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the pitch mockup segment `S("c-blue b","proj"),S("c-dim","/src/parser")`.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-008] The ephemeral range comes from the kernel at refresh time
- **Decision:** `ephemeral_range` reads `/proc/sys/net/ipv4/ip_local_port_range`, and it falls back to 32768 to 60999 when the file cannot be read. `refresh` and `sonar ports` call it. The render path does not.
- **Alternatives considered:** A fixed range in the script.
- **Rationale:** The pitch says "the kernel's ephemeral range", and the kernel value can change with `sysctl`. The read runs in the background, so it costs the render path nothing.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the file exists on this host and holds 32768 to 60999.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-009] `.sonar` lines must match a strict pattern
- **Decision:** `sonar_names` accepts only lines that match `^[A-Za-z0-9_-]+=[0-9]+$`. It ignores every other line, which includes comments, blank lines, and lines that end in a carriage return. It also reads a last line that has no newline.
- **Alternatives considered:** Source the file as shell assignments. Strip spaces and carriage returns before the match.
- **Rationale:** A cloned repo can hold any `.sonar` file, and sourcing one runs its code (PM-6). A strict match is the smallest rule that makes A3 hold. Lenient parsing was rejected because no `.sonar` file exists yet that needs it.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the code reads the file with `read` and a regex match only.
- **Assumptions:** The developer writes `.sonar` files without spaces around `=`.
- **Monitoring signal:** → Pre-Mortem: "PM-6: A `.sonar` file in a cloned repo runs code when Sonar reads it."
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED — 2026-11-22: the check "a .sonar file never runs code" passes, and the baseline `c944908` has no `.sonar` reader to compare.

### [DL-010] `sonar ports` names a script by its file name
- **Decision:** The NAME column shows the `.sonar` name for the port when one exists. If not, and the process is `node`, `bun`, `deno`, `python`, `ruby`, or `perl`, it shows the first non-option argument without its folder and extension. Otherwise it shows `/proc/PID/comm`.
- **Alternatives considered:** Always show `/proc/PID/comm`.
- **Rationale:** On this host, `comm` for every ADP server is `node-MainThread`, and the pitch shows `adp-server` and `vite`. The script file name gives those names.
- **Confidence:** MEDIUM
- **Confidence basis:** DIRECT EVIDENCE — the live run on 2026-11-22 printed `adp-server` for `adp-server.mts`. INFERENCE FROM CONVENTION for `vite`, which I did not run.
- **Assumptions:** Interpreters take the script as their first non-option argument.
- **Monitoring signal:** The NAME column shows an option value or a folder name for an interpreter process — fires at any occurrence — distinguishes: a script that really carries that name.
- **Created:** 2026-11-22, Phase 5
- **Status:** OPEN

### [DL-011] "Child of" wins over "orphan" in the NOTE column
- **Decision:** When the parent of a listener is another listener, the note is `child of NAME PID`, and the listener does not count as an orphan. Otherwise the CD1 and A1 rule decides: the parent is PID 1, or `systemd` with `--user`. A duplicate note adds to either note.
- **Alternatives considered:** Mark every listener whose parent is not a shell.
- **Rationale:** The pitch shows the workerd processes under Vite as `child of vite 11113`. A process whose parent still runs is not an orphan under CD1.
- **Confidence:** MEDIUM
- **Confidence basis:** DIRECT EVIDENCE — the live run flagged the 6 ADP servers whose parent is `systemd --user` as orphans and did not flag `claude` or `steam`. DEVELOPER ASSERTION for the definition, at CD1.
- **Assumptions:** A1. Some other subreaper, such as a container init, is not in use for dev servers on this host.
- **Monitoring signal:** → Pre-Mortem: "PM-1: `sonar ports --kill-strays` kills a server that the developer wants running, for example the ADP mission control server."
- **Created:** 2026-11-22, Phase 5
- **Status:** OPEN

### [DL-012] `confirm_kill` checks the start time before it kills
- **Decision:** Before the SIGTERM, `confirm_kill` reads the process start time again. It kills only when that start time equals the start time from the listing.
- **Alternatives considered:** Kill by PID alone.
- **Rationale:** The developer can wait at the y/N question for any length of time. In that time the process can exit and the kernel can give its PID to a new process. Without the check, a `y` answer would kill the new process.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — field 22 of `/proc/PID/stat` is the start time, and a reused PID gets a new start time.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-013] A return guard before dispatch
- **Decision:** `[[ ${BASH_SOURCE[0]} != "$0" ]] && return 0` runs before the `case` dispatch.
- **Alternatives considered:** Move the functions into a library file that `bin/sonar` sources.
- **Rationale:** The pitch budget is one file. The guard lets `test/run.sh` source the script and call its functions.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — A6, and the smoke run of `sonar prompt` through the symlink.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-014] `sonar ports` lists every listener on the machine
- **Decision:** `sonar ports` prints one row for each port and PID pair from `ss -Hltnp`, sorted by port. That includes rows that `ss` gives without a PID, which show `-`.
- **Alternatives considered:** List only listeners inside the current repo.
- **Rationale:** The pitch says that `sonar ports` "lists every listener", and the pitch mockup lists an ADP server from `~/.claude` while it runs in another repo. BAR shows which rows the bar for the current folder would show.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the pitch segment table and the "Many ports" scenario.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-015] The tests fake `ss` and `gh` with scripts on PATH
- **Decision:** `test/run.sh` puts fake `ss` and `gh` scripts first on PATH. The fake `ss` prints one listener line for each port and PID pair in a fixture file. Real `sleep` processes started in the fixture folders supply the PIDs and working directories that `refresh` reads from `/proc`.
- **Alternatives considered:** Override `ss` with a shell function after sourcing the script. Start real servers on real ports.
- **Rationale:** A PATH fake works when the suite runs `sonar` as a program, so the same checks run against the baseline `c944908`, which cannot be sourced. Real servers would make the result depend on which ports are free on the machine.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the suite passes 33 of 33 checks on the new code and fails 20 of 33 on `c944908`, and every gap from the Problem Statement is among the 20.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-016] The render-time check compares against the baseline in the same conditions
- **Decision:** I judge CD4 with an A/B run of 25 interleaved renders for each version, live state included. The suite check uses a fixed 25 ms ceiling.
- **Alternatives considered:** Compare against the 23 ms median from Phase 2.
- **Rationale:** The Phase 2 median came from 5 runs at a different time. On 2026-11-22 the interleaved run gave a 24 ms median for both the new code and `c944908`, so the change adds no render time that I can measure. The fixed ceiling in the suite catches a large regression without failing on machine noise.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — the interleaved A/B run, 24 ms against 24 ms. This also validates A2.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 5
- **Status:** VALIDATED

### [DL-017] tmux mode counts glyph widths correctly under the tmux server locale
- **Decision:** Sonar keeps character counts from `${#var}` for every width, with no locale override at the top of the script.
- **Alternatives considered:** Force `LC_ALL=C.UTF-8` at the top of `bin/sonar`.
- **Rationale:** The tmux server environment holds `LANG=en_US.UTF-8`, and `#()` status commands inherit that environment. Under that environment, `sonar tmux` in this repo printed 50 visible columns at 140, 100, 72, and 56 columns, and 37 at 40 columns, which shortened the drift dial and the agents segment. Every line fit its width. A forced locale would also change how `sort` behaves in `refresh`, with no measured gain.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — `/proc/3345569/environ` of the tmux server, and a `sonar tmux` run under that environment on 2026-11-22. This validates A5 and closes the open check for PM-4.
- **Assumptions:** The tmux server starts from a login session with a UTF-8 `LANG`.
- **Monitoring signal:** The tmux status row wraps or cuts its right side in a pane where `sonar prompt` fits — fires at any occurrence — distinguishes: a pane narrower than the shortest form of the priority 1 segments, which overflows in every mode.
- **Created:** 2026-11-22, Phase 5
- **Status:** OPEN

### [DL-018] A subfolder inside a worktree follows the worktree head
- **Decision:** Inside a linked worktree, the subfolder follows the head of the path segment, with `/` between them: `crc ⧉/src/parser`, or `crc ⧉ scratch/src/parser` when the folder shows. The forms shorten in the same way as in a main checkout.
- **Alternatives considered:** Put a space before the subfolder, for example `crc ⧉ src/parser`.
- **Rationale:** The pitch shows a worktree only at its root, so it gives no example to copy. One join rule for both checkouts keeps `seg_repo_path` as one code path. A space before the subfolder would read as a worktree folder name.
- **Confidence:** LOW
- **Confidence basis:** INFERENCE FROM CONVENTION — the pitch has no worktree subfolder example, and I chose the join.
- **Assumptions:** The developer reads `crc ⧉/src` as the `src` folder of the `crc` worktree.
- **Monitoring signal:** The developer cannot tell the worktree subfolder from the worktree folder name on the bar — fires at the first report — distinguishes: a worktree folder that itself holds a `/`, which git does not create.
- **Created:** 2026-11-22, Phase 6
- **Status:** VALIDATED — 2026-11-22: the developer accepted `crc ⧉/src/parser` at the Phase 6 gate. DEVELOPER ASSERTION.

### [DL-019] tmux markup in folder names stays out of scope
- **Decision:** This task does not escape `#[` in folder names or branch names before the tmux mode prints them.
- **Alternatives considered:** Escape `#` as `##` in every text that `style` receives in tmux mode.
- **Rationale:** tmux reads `#[...]` in the status command output as style markup. So a folder named `#[bg=red]x` restyles the bar. The baseline `c944908` already has this behavior in `seg_path`, and the Problem Statement does not list it. Git rejects `[` in branch names, so only folder names can trigger it.
- **Confidence:** HIGH
- **Confidence basis:** DIRECT EVIDENCE — `style` in `bin/sonar` prints text into `#[fg=...]` markup with no escaping, and `git check-ref-format` rejects `[`.
- **Assumptions:** The developer does not work in folders whose names hold `#[`.
- **Monitoring signal:** The tmux status row shows colors or alignment that no Sonar segment sets, in a folder whose name holds `#` — fires at any occurrence — distinguishes: the danger segment, which sets a red background on purpose.
- **Created:** 2026-11-22, Phase 6
- **Status:** OPEN

## Test Adversary Document
**What passing tests prove:** `test/run.sh` passes 50 of 50 checks on 2026-11-22. The suite fails 25 of 50 against the baseline `c944908`, and each Problem Statement gap has at least one check that fails on the baseline. Four mutations of `bin/sonar` each fail at least one check. The mutations remove the absolute-path flag, the start-time check in `confirm_kill`, and the rule that a short form must be shorter, and they reintroduce an invalid width expansion. Within the fixtures, the checks prove these things:
- The path starts at the repo, and it shortens to `repo/…/leaf` and then to `repo`.
- A worktree shows the main repo name and `⧉`. The folder shows only when it is not named after the branch. A bare-repo worktree shows the bare repo name, and a main checkout shows no `⧉`.
- Both pitch branch examples produce the pitch forms. Short names, names with no slash, digits inside a word, and a detached HEAD produce no bare `…` and no form longer than the name.
- Segments shorten before any segment drops. Rendered lines fit at 140, 100, 72, and 56 columns, and a width of 1 still ends with the priority 1 segments.
- Renders write nothing to stderr in a subfolder, in two worktrees, in a repo with no commits, outside any repo, and at `/`.
- Ephemeral ports stay off the bar, named ports show by name, IPv6 listeners show, and the bar caps at 3 ports plus `+N`. A `.sonar` file never runs code.
- `sonar ports` prints the pitch columns and the correct BAR value, and it marks duplicates and children of listeners. It does not call a child of a live shell an orphan.
- `confirm_kill` keeps the process on an empty answer, on a closed stdin, and on a changed start time. It sends SIGTERM on `y`.
- The median prompt render in this repo is 25 ms or less.

**What passing tests do not prove:**
| Gap | Why untestable / untested | Risk if the assumption is wrong | dl_ref |
|-----|---------------------------|---------------------------------|--------|
| The orphan rule finds only strays that the developer wants gone. | The suite checks `is_orphan` with PID 1 only. A fixture cannot make the systemd user manager adopt a process without a real detach, and the suite does not run `--kill-strays` end to end on a real orphan. The "no terminal" check uses a process that is not an orphan, so that check proves only that nothing else is killed. | The developer sees wanted servers in the y/N list. The per-process question with No as the default stops any kill without a typed `y` (PM-1). | DL-011 |
| Ticket numbers in real branch names stand between separators. | The rule comes from one pitch example and a naming convention. Only the developer's real branches can test it. | A narrow bar shows a version number or a year as a ticket, for example `bump/22…`. | DL-005 |
| Worktree tools name folders in one of the three ways that DL-006 checks. | The suite builds worktrees with `git worktree add` and chosen folder names. Other tools can name folders in other ways. | The bar prints the branch words twice, as it did before this task. | DL-006 |
| `sonar ports` names interpreter scripts correctly for real dev servers such as Vite. | The suite uses `sleep`, which is not an interpreter. Only the live ADP servers checked the `node` path. | The NAME column shows `vite.js` as `vite`, as intended, or shows an option value for an interpreter that takes options with values. | DL-010 |
| The tmux server always starts with a UTF-8 locale. | The check ran against one tmux server on 2026-11-22. A server that starts from a non-UTF-8 environment counts bytes, and the suite forces `LANG=C.UTF-8`. | The tmux row shortens and drops segments too early, because each glyph counts as 3 columns. | DL-017 |
| Render time stays within budget in tmux mode and under load. | The timing check runs prompt mode on this machine only. tmux mode prints a different format and runs on every status refresh. | A busy machine makes the status row lag. The A/B run shows no difference from the baseline, so the lag would exist before this task too. | DL-016 |
| The worktree subfolder join reads clearly. | Readability needs a human reader. | The developer misreads `crc ⧉/src` and the format changes in a later task. | DL-018 |
| tmux markup in folder names. | The suite does not test this behavior, which the baseline already has. | A folder named with `#[` restyles the tmux row. | DL-019 |
| The danger, remote, CI, toolchain, and agents segments, and the `claude` mode, behave as before. | This task does not change their logic, and the suite has no checks for them. The agents segment only gained a short form, which the smoke run showed as `✦1`. | A regression in an unchanged segment goes unseen until the developer notices it on the bar. | DL-001 |

**Untestable assumptions logged to Decision Log:** DL-005, DL-006, DL-010, DL-011, DL-017, DL-018, DL-019

## PR Summary
**Problem being solved:** `bin/sonar` at `c944908` did not implement 7 behaviors from the Sonar pitch artifact (Problem Statement, gaps 1 to 7). Segments dropped without shortening first. The path did not start at the repo and had no worktree form. The bar showed every port, including ephemeral ports, with no names and no cap. The `sonar ports` subcommand did not exist. Gap 8, the red danger rule, went out of scope at the Phase 1 gate.

**Approach taken:** The approach follows the Recommendation Brief, with two deviations. First, `--kill-strays` asks y/N for each orphan, with No as the default, and does not ask once for the whole list. The Pre-Mortem found that the orphan rule also matches wanted ADP servers (PM-1), and the developer confirmed the change. Second, the ticket-number rule needs the digits to stand between separators, which refines A4 (DL-005). The changes in `bin/sonar` are these:
- Each segment record carries its shorter forms, and `render` shortens before it drops (DL-001, DL-002).
- One `git rev-parse` call with absolute paths gives the repo root, the shared `.git`, and the subfolder (PM-2).
- All port filtering runs in the background `refresh`.
- `sonar ports` lists every listener on the machine (DL-014).

The new `test/run.sh` holds 50 checks, and `.gitignore` un-ignores `.adp/` for this repo.

**Key decisions:**
- HIGH: DL-001, the segment record format. DL-002, the shorten order. DL-003, git status runs before any segment. DL-004, the 14 and 13 character middle cut. DL-007, the bold repo name. DL-008, the kernel ephemeral range. DL-009, the strict `.sonar` pattern. DL-012, the start-time check before a kill. DL-013, the dispatch guard. DL-014, the machine-wide listing. DL-015, the PATH fakes in tests. DL-016, the A/B render timing. DL-019, tmux markup stays out of scope.
- MEDIUM, flagged: DL-005, ticket numbers between separators. DL-006, the three ways a worktree folder can match its branch. DL-010, interpreter script names. DL-011, "child of" before "orphan". DL-017, the tmux UTF-8 locale. Each one rests on a naming or process convention that only real use confirms.

## 🚩 Mandatory Review Items (LOW-confidence decisions)
- [x] [DL-018]: A subfolder inside a worktree renders as `crc ⧉/src/parser` — the pitch has no example for this case — the developer accepted the format at the Phase 6 gate on 2026-11-22.

## Residual Risk
- The orphan rule matches every listener whose parent is the systemd user manager, so wanted detached servers appear in the `--kill-strays` list. The y/N question for each process, with No as the default, is the only guard (PM-1, DL-011).
- DL-005, DL-006, DL-010, and DL-017 stay OPEN until real branches, worktree tools, dev servers, and tmux restarts confirm them.
- A folder name that holds `#[` restyles the tmux row. The baseline already has this behavior (DL-019).
- Render time matches the baseline at a 24 ms median, but the baseline itself sits close to the 25 ms pitch budget (DL-016).

## Test Coverage Gaps
The Test Adversary Document lists 9 gaps. Reviewers need to know these four first:
- No check runs `--kill-strays` end to end on a real orphan.
- The suite forces a UTF-8 locale, so it cannot catch a tmux server that starts without one.
- Timing runs in prompt mode only.
- The danger, remote, CI, toolchain, and agents segments and the `claude` mode have no checks, because this task did not change their logic.

### [DL-020] Publish the repo in public with its audit log and author email
- **Decision:** The repo is public at https://github.com/russbeye/sonar on branch `master`. It includes `.adp/`, and its commits keep the author email that they already carry.
- **Alternatives considered:** Remove `.adp/` from history before the push. Rewrite the commits to the GitHub noreply address.
- **Rationale:** The developer chose both options on 2026-11-22, after a question that named what the audit log exposes: the home path, other local project names, process command lines, and the pitch artifact link. The question also said that the commits carry a personal email. A scan for tokens and private keys found nothing before the push.
- **Confidence:** HIGH
- **Confidence basis:** DEVELOPER ASSERTION — the developer's answers to the publish question. DIRECT EVIDENCE — `gh repo view` reports the visibility as PUBLIC.
- **Assumptions:** none
- **Created:** 2026-11-22, Phase 7
- **Status:** VALIDATED
