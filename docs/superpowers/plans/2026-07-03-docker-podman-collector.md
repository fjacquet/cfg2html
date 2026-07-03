# Docker/Podman Container Runtime Collector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Linux-only cfg2html collector that reports Docker/Podman container runtime inventory (version, info, images, containers, networks, volumes, disk usage), gated by a new `CFG_CONTAINERS` toggle, following the exact structural pattern of the existing `CFG_VMWARE` section.

**Architecture:** Two independent, additive changes to `linux/`: (1) plumb a new `CFG_CONTAINERS` toggle through `default.conf`, the `getopts` CLI parser, and the `usage()` help text — the same three-file pattern every other `CFG_*` toggle already follows; (2) add a new top-level `if [ "${CFG_CONTAINERS}" != "no" ]` section to `linux/cfg2html-linux.sh`, placed immediately after the `CFG_VMWARE` block, that loops over `docker` and `podman`, and for each binary found on `$PATH` runs a fixed set of inventory-only commands via the existing `exec_command` helper.

**Tech Stack:** POSIX/Bourne-family shell (bash on Linux), the project's existing `paragraph`/`inc_heading_level`/`dec_heading_level`/`exec_command` report primitives from `linux/lib/html-functions.sh`. No new dependencies.

## Global Constraints

- No `inspect` output (Docker/Podman `inspect` commonly leaks env vars containing secrets) — inventory-level commands only. Source: design spec, "Non-goals".
- No new automated test suite — this repo has none (per `CLAUDE.md`); verification is manual/scripted-but-throwaway, matching existing project convention. Source: design spec, "Non-goals".
- Follow existing `CFG_*` toggle conventions exactly: default `"yes"` in `default.conf`, opt-out flag in `getopts`, one line in `usage()`. Source: design spec, sections 1-3.
- New section must be its own top-level paragraph (like `CFG_VMWARE`), not folded into "Applications and Subsystems". Source: user confirmation in brainstorming.
- Run `shellcheck` on every modified file before committing (project's Differential ShellCheck CI check, severity `warning`). Source: `CLAUDE.md`, "Linting / CI".

---

### Task 1: Wire up the `CFG_CONTAINERS` toggle

**Files:**
- Modify: `linux/etc/default.conf:25-26`
- Modify: `linux/cfg2html-linux.sh:102` (getopts option string)
- Modify: `linux/cfg2html-linux.sh:111` (getopts case block)
- Modify: `linux/lib/help-functions.sh:33` (usage text)

**Interfaces:**
- Produces: shell variable `CFG_CONTAINERS`, either inherited as `"yes"` from `default.conf` or set to `"no"` if the user passes `-C` on the command line. Task 2 consumes this variable as `${CFG_CONTAINERS}` to gate its new section.

- [ ] **Step 1: Add the toggle to `default.conf`**

In `linux/etc/default.conf`, the toggle block currently reads (lines 24-26):

```sh
CFG_ALTIRISAGENTFILES="yes"  # Added by jeroen kleen HP ISS CC Engineer
CFG_APPLICATIONS="yes"
CFG_CRON="yes"
```

Change it to:

```sh
CFG_ALTIRISAGENTFILES="yes"  # Added by jeroen kleen HP ISS CC Engineer
CFG_APPLICATIONS="yes"
CFG_CONTAINERS="yes" # collect Docker/Podman container runtime information
CFG_CRON="yes"
```

- [ ] **Step 2: Verify the config change**

Run: `grep -n "CFG_CONTAINERS" linux/etc/default.conf`
Expected: `26:CFG_CONTAINERS="yes" # collect Docker/Podman container runtime information`

- [ ] **Step 3: Write a throwaway harness to prove the getopts change before editing the 3000-line driver file**

Create `/private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_getopts.sh`:

```sh
#!/usr/bin/env bash
CFG_CONTAINERS="yes"
CFG_CRON="yes"

while getopts ":o:shxOcCSTflzkenaHLvhpPAV2:10w:" Option
do
  case ${Option} in
    c     ) CFG_CRON="no";;
    C     ) CFG_CONTAINERS="no";;
    *     ) : ;;
  esac
done

echo "CFG_CRON=${CFG_CRON}"
echo "CFG_CONTAINERS=${CFG_CONTAINERS}"
```

- [ ] **Step 4: Run the harness with no flags, `-C` alone, and `-c` alone, and confirm each behaves independently**

Run: `bash /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_getopts.sh`
Expected:
```
CFG_CRON=yes
CFG_CONTAINERS=yes
```

Run: `bash /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_getopts.sh -C`
Expected:
```
CFG_CRON=yes
CFG_CONTAINERS=no
```

Run: `bash /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_getopts.sh -c`
Expected:
```
CFG_CRON=no
CFG_CONTAINERS=yes
```

This confirms `-C` and `-c` are independent, unambiguous flags before touching the real file.

- [ ] **Step 5: Apply the same getopts option string and case-block change to the real driver file**

In `linux/cfg2html-linux.sh`, line 102 currently reads:

```sh
while getopts ":o:shxOcSTflzkenaHLvhpPAV2:10w:" Option   ##  -T -0 -1 -2 backported from HPUX # added new options -x and -O and removed the need for an argument on -A, also added -w, -z  and -V # modified on 20240119 by edrulrd
```

Change it to:

```sh
while getopts ":o:shxOcCSTflzkenaHLvhpPAV2:10w:" Option   ##  -T -0 -1 -2 backported from HPUX # added new options -x and -O and removed the need for an argument on -A, also added -w, -z  and -V # modified on 20240119 by edrulrd
```

Line 111 currently reads:

```sh
    c     ) CFG_CRON="no";;
```

Change it to:

```sh
    c     ) CFG_CRON="no";;
    C     ) CFG_CONTAINERS="no";; # disable Docker/Podman container runtime collection
```

- [ ] **Step 6: Add the disable-flag line to `usage()`**

In `linux/lib/help-functions.sh`, line 33 currently reads:

```sh
  echo "    -c      disable: Cron"
```

Change it to:

```sh
  echo "    -c      disable: Cron"
  echo "    -C      disable: Docker/Podman container runtime information"
```

- [ ] **Step 7: Syntax-check both modified real files**

Run: `bash -n linux/cfg2html-linux.sh && bash -n linux/lib/help-functions.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK` (no syntax errors printed)

- [ ] **Step 8: ShellCheck both modified real files at the CI's severity level**

Run: `shellcheck -S warning linux/cfg2html-linux.sh linux/etc/default.conf`
Expected: no output (0 warnings) — this matches the pre-change baseline for these two files.

Run: `shellcheck -S warning linux/lib/help-functions.sh`
Expected: exactly one pre-existing warning, unrelated to this change:
```
In linux/lib/help-functions.sh line 1:

^-- SC2148 (error): Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.
```
(This warning exists on `master` before this change — it's about the missing shebang on line 1, not the line you added. If ShellCheck reports anything else, fix it before continuing.)

- [ ] **Step 9: Remove the throwaway harness and commit**

```bash
rm -f /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_getopts.sh
git add linux/etc/default.conf linux/cfg2html-linux.sh linux/lib/help-functions.sh
git commit -m "new: dev: Add CFG_CONTAINERS toggle (-C flag) for Docker/Podman collector"
```

---

### Task 2: Add the Docker/Podman collector section

**Files:**
- Modify: `linux/cfg2html-linux.sh:2956-2957` (insert new section immediately after the `CFG_VMWARE` block)

**Interfaces:**
- Consumes: `CFG_CONTAINERS` (from Task 1, values `"yes"`/`"no"`), and the report primitives `paragraph(title)`, `inc_heading_level()`, `dec_heading_level()`, `exec_command(command, label)` (all defined in `linux/lib/html-functions.sh`, already used identically by the neighboring `CFG_VMWARE` block).
- Produces: nothing consumed by later tasks — this is the final task in the plan.

- [ ] **Step 1: Write a throwaway harness that stubs the report primitives, to prove the loop logic before editing the real 3000-line file**

Create `/private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh`:

```sh
#!/usr/bin/env bash
# Stubs for the real report primitives in linux/lib/html-functions.sh
paragraph() { echo "PARAGRAPH: $1"; }
inc_heading_level() { :; }
dec_heading_level() { :; }
exec_command() { echo "  EXEC: $1 | LABEL: $2"; }

CFG_CONTAINERS="${CFG_CONTAINERS:-yes}"

if [ "${CFG_CONTAINERS}" != "no" ]
then # else skip to next paragraph

  for RUNTIME in docker podman; do
    BIN=$(which "${RUNTIME}" 2>/dev/null)
    if [ -n "${BIN}" ]; then

      paragraph "${RUNTIME} container runtime"
      inc_heading_level
        # Deliberately no "inspect" here: container env vars often carry
        # secrets (DB passwords, API keys) and this report may be shared
        # for DR/support purposes.
        exec_command "${BIN} version"    "${RUNTIME} version"
        exec_command "${BIN} info"       "${RUNTIME} system info"
        exec_command "${BIN} images"     "${RUNTIME} images"
        exec_command "${BIN} ps -a"      "${RUNTIME} containers (running + stopped)"
        exec_command "${BIN} network ls" "${RUNTIME} networks"
        exec_command "${BIN} volume ls"  "${RUNTIME} volumes"
        exec_command "${BIN} system df"  "${RUNTIME} disk usage"
      dec_heading_level

    fi
  done

fi  # end of CFG_CONTAINERS paragraph
```

- [ ] **Step 2: Run the harness with both runtimes on `$PATH` (the normal case on this dev machine)**

Run: `chmod +x /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh && /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh`
Expected: a `PARAGRAPH: docker container runtime` block followed by 7 `EXEC:` lines, then a `PARAGRAPH: podman container runtime` block followed by 7 more `EXEC:` lines — 2 paragraphs, 14 exec lines total. Confirm no `inspect` command appears anywhere in the output.

- [ ] **Step 3: Run the harness with only one runtime visible, to prove the "only found binaries are reported" behavior**

Run:
```bash
mkdir -p /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/fakebin
cp "$(which docker)" /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/fakebin/docker 2>/dev/null || ln -s "$(which docker)" /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/fakebin/docker
PATH="/private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/fakebin" /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh
```
Expected: only a `PARAGRAPH: docker container runtime` block with its 7 `EXEC:` lines — no `podman` paragraph at all.

- [ ] **Step 4: Run the harness with `CFG_CONTAINERS=no`, to prove the toggle disables the whole section**

Run: `CFG_CONTAINERS=no /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh`
Expected: no output at all.

- [ ] **Step 5: Insert the same block into the real driver file, immediately after the `CFG_VMWARE` section**

In `linux/cfg2html-linux.sh`, lines 2956-2957 currently read:

```sh
fi  # end of CFG_VMWARE paragraph
##############################################################################
```

Change it to:

```sh
fi  # end of CFG_VMWARE paragraph
##############################################################################

##############################################################################
###   Docker / Podman container runtime information
##############################################################################

if [ "${CFG_CONTAINERS}" != "no" ]
then # else skip to next paragraph

  for RUNTIME in docker podman; do
    BIN=$(which "${RUNTIME}" 2>/dev/null)
    if [ -n "${BIN}" ]; then

      paragraph "${RUNTIME} container runtime"
      inc_heading_level
        # Deliberately no "inspect" here: container env vars often carry
        # secrets (DB passwords, API keys) and this report may be shared
        # for DR/support purposes.
        exec_command "${BIN} version"    "${RUNTIME} version"
        exec_command "${BIN} info"       "${RUNTIME} system info"
        exec_command "${BIN} images"     "${RUNTIME} images"
        exec_command "${BIN} ps -a"      "${RUNTIME} containers (running + stopped)"
        exec_command "${BIN} network ls" "${RUNTIME} networks"
        exec_command "${BIN} volume ls"  "${RUNTIME} volumes"
        exec_command "${BIN} system df"  "${RUNTIME} disk usage"
      dec_heading_level

    fi
  done

fi  # end of CFG_CONTAINERS paragraph
##############################################################################
```

- [ ] **Step 6: Syntax-check the real file**

Run: `bash -n linux/cfg2html-linux.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 7: ShellCheck the real file at the CI's severity level**

Run: `shellcheck -S warning linux/cfg2html-linux.sh`
Expected: no output (0 warnings) — matches the pre-change baseline.

- [ ] **Step 8: Remove the throwaway harness and its fake bin dir**

```bash
rm -rf /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/verify_containers.sh /private/tmp/claude-501/-Users-fjacquet-Projects-cfg2html/27102793-6025-44ec-8ee7-ef269fc5d776/scratchpad/fakebin
```

- [ ] **Step 9: Commit**

```bash
git add linux/cfg2html-linux.sh
git commit -m "new: dev: Add Docker/Podman container runtime collector section"
```

- [ ] **Step 10: Manual full-run verification (requires a real Linux host — cannot be done on this macOS dev machine)**

This repo's own `cfg2html` wrapper OS-detects via `uname` and only knows how to source `cfg2html-linux.sh` on an actual Linux host (see `cfg2html:14,41-42,124-125`) — it cannot run end-to-end on macOS. Note this for the person merging the change: before release, run `sudo ./cfg2html` on a real Linux host that has Docker and/or Podman installed, and confirm:
- the new "docker container runtime" / "podman container runtime" section(s) appear in both the generated `.html` and `.txt` report files, in the expected position (right after any VMware section, before whatever section follows it in the full report),
- `sudo ./cfg2html -C` produces a report with the section fully absent,
- on a host with neither Docker nor Podman installed, the section is silently absent (no errors in `$ERROR_LOG`).

---

## Self-Review Notes

- **Spec coverage:** toggle in `default.conf` (Task 1, Step 1) ✓; getopts opt-out flag (Task 1, Step 5) ✓; usage text (Task 1, Step 6) ✓; own top-level paragraph placed after `CFG_VMWARE` (Task 2, Step 5) ✓; per-runtime sub-paragraph only when binary present (Task 2, Steps 2-3) ✓; inventory-only commands, no `inspect` (Task 2, Step 1 code + comment) ✓; error handling relies on existing `exec_command` (no new code needed — documented in Task 2 intro) ✓; manual verification convention (Task 2, Step 10) ✓.
- **Placeholder scan:** none found — every step has literal commands, exact file content, and exact expected output.
- **Type consistency:** the single shared symbol across tasks is the shell variable `CFG_CONTAINERS`; Task 1 defines and sets it, Task 2 reads it via `"${CFG_CONTAINERS}"` — consistent naming throughout.
