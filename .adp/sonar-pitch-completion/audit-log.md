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
**Confirmed by:** PENDING   **Date:** PENDING
**Revision history:** none
