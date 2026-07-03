# Docker/Podman Container Runtime Collector — Design

## Context

cfg2html (Linux variant) currently has no dedicated collector for container
runtimes. The only existing container-adjacent output is `machinectl` (systemd
containers/VMs) and a single `flatpak list` line under "Applications and
Subsystems". Docker and Podman are common on modern Linux hosts and their
absence is a real gap for disaster-recovery documentation and troubleshooting.

## Goal

Add a Linux collector that reports installed container runtimes (Docker
and/or Podman), their images, containers, networks, volumes, and disk usage —
at the same "config inventory" depth as existing collectors like VMware or
ZFS, and gated by the same `CFG_*` toggle convention.

## Non-goals

- No per-container `inspect` output. `docker inspect` / `podman inspect`
  commonly surface environment variables containing secrets (DB passwords,
  API keys, tokens) passed into containers. Given the HTML/text report may be
  shared with support teams or stored for DR purposes, this collector
  deliberately stops at inventory-level commands and does not run `inspect`.
- No Kubernetes/kubelet collection (out of scope for this design; could be a
  follow-up).
- No new automated test suite — this repo has none (per CLAUDE.md) and this
  change follows existing convention (manual verification + ShellCheck CI).

## Design

### 1. Config toggle

Add to `linux/etc/default.conf`, alongside the other `CFG_*` toggles:

```sh
CFG_CONTAINERS="yes" # collect Docker/Podman container runtime information
```

Default `"yes"` (enabled by default), matching `CFG_VMWARE`/`CFG_ZFS`/etc.

### 2. CLI opt-out flag

`linux/cfg2html-linux.sh` currently parses options via:

```sh
while getopts ":o:shxOcSTflzkenaHLvhpPAV2:10w:" Option
```

Add `C` to the option string and a corresponding case:

```sh
C     ) CFG_CONTAINERS="no";;
```

`-C` is unused today (`-c` is taken by `CFG_CRON`). This follows the existing
opt-out pattern (`-V` disables VMware, `-z` disables ZFS, etc.).

### 3. Usage/help text

Add a line in `linux/lib/help-functions.sh`'s `usage()` function, next to the
other disable-flag lines:

```sh
echo "    -C      disable: Collecting Docker/Podman container runtime information"
```

### 4. Collector section

New top-level section in `linux/cfg2html-linux.sh`, placed immediately after
the existing `CFG_VMWARE` block (~line 2956), following the same gating
idiom — its own `paragraph`/`inc_heading_level`/`dec_heading_level` block, not
folded into "Applications and Subsystems":

```sh
if [ "${CFG_CONTAINERS}" != "no" ]
then # else skip to next paragraph

  for RUNTIME in docker podman; do
    BIN=$(which ${RUNTIME} 2>/dev/null)
    if [ -n "${BIN}" ]; then

      paragraph "${RUNTIME} container runtime"
      inc_heading_level
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

Each runtime (Docker, Podman) gets its own sub-paragraph and is only reported
if its binary is present on `$PATH` — a host with only one runtime installed
won't show an empty section for the other. A host with neither installed
shows no "container runtime" heading at all, consistent with how the VMware
section behaves when `/proc/vmware` doesn't exist.

### 5. Error handling

No special-casing beyond what `exec_command` already provides: it captures
stdout into the report and routes stderr to `$ERROR_LOG`, and a failing
subcommand (e.g. `docker info` when the daemon isn't running but the CLI is
installed) doesn't abort the run. This matches how every other `exec_command`
call in the codebase behaves.

### 6. Testing / verification

No automated test suite exists in this repo. Verification is manual, matching
existing convention:

- Run `sudo ./cfg2html` on a host with Docker installed, Podman installed,
  both, and neither — confirm the section appears/doesn't appear correctly in
  both the HTML and text output.
- Run `shellcheck linux/cfg2html-linux.sh` and `shellcheck
  linux/lib/help-functions.sh` locally before pushing (CI's Differential
  ShellCheck will also check the diff).

## Open questions / follow-ups (not blocking this design)

- Kubernetes/kubelet collection could be a natural follow-up section using
  the same toggle pattern, but is out of scope here.
- Whether to extend this same collector to other OS variants (AIX, SunOS,
  HP-UX, BSD) is a separate decision — those platforms rarely run
  Docker/Podman natively, so no action taken there for now.
