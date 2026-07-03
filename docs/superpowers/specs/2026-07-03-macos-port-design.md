# macOS (Darwin) Port — Phase 1 MVP Design

## Context

cfg2html ships a distinct implementation per OS family — Linux, HP-UX, AIX,
SunOS/Solaris, and *BSD — each a self-contained tree under a top-level
directory (driver script, `lib/`, `etc/`, optionally `plugins/`/`packaging/`),
all dispatched from one OS-detecting wrapper (`cfg2html`). There is currently
no macOS/Darwin support: the only trace of Darwin-awareness anywhere in the
codebase is one incidental `linux|darwin)` branch in the `_echo` portability
helper (choosing an `echo -e` flag style), duplicated identically across
several per-OS `lib/shell-functions.sh` files. This is a genuinely new port.

Creating full parity with an existing port (every collector category:
hardware, filesystem, LVM-equivalent, network, cron, software, kernel,
enhancements, applications...) is comparable in scope to the project's other
OS ports, each of which grew incrementally over years of contributions. This
design scopes a **Phase 1 MVP**: a working, genuinely useful macOS report
covering the 7 collector categories common to every existing port. Further
categories (launchd/cron equivalents, packaging, printer/license-style
extras) are explicit non-goals here and can follow as their own
spec/plan cycles.

## Goal

Ship a `darwin/` OS port that a user can run via `sudo ./cfg2html` on a real
Mac and get a genuinely useful HTML/text disaster-recovery report covering
System, Hardware, Filesystem, Kernel, Network, Software, and Applications,
using macOS-native tools, following the exact same `CFG_*` toggle,
`paragraph`/`exec_command` report-primitive, and directory-structure
conventions every other port already uses.

## Architecture

### Directory & file naming

New top-level `darwin/` directory, mirroring the existing `aix/`/`bsd/`/
`hpux/`/`linux/`/`sunos/` shape:

```
darwin/
  cfg2html-darwin.sh       # driver — dot-sourced by the wrapper, never executed directly
  lib/
    global-functions.sh
    help-functions.sh
    html-functions.sh
    input-output-functions.sh
    shell-functions.sh
    darwin-functions.sh    # macOS-specific helpers (mirrors linux-functions.sh / freebsd-functions.sh)
  etc/
    default.conf
    local.conf
```

No shebang line on `cfg2html-darwin.sh` — it is always dot-sourced by the
top-level `cfg2html` wrapper into an already-running interpreter, never
executed as its own process. This matches the existing `aix`/`sunos`/`bsd`
drivers, none of which carry a shebang either (only `hpux`'s does, since HP-UX
predates this convention in the codebase).

**Naming is driven by `uname`, not aesthetics.** The wrapper computes:

```sh
OS="$(uname)"
OS="$(echo ${OS} | tr 'A-Z' 'a-z' | sed -e 's/-//')"   # -> "darwin" on macOS
```

and resolves `BASE_DIR="${MYPATH}/${OS}"` (checkout mode) or `${SHARE_DIR}`
(installed mode), then dot-sources `${BASE_DIR}/${PROGRAM}-${OS}.sh` — with
**no** special-casing, unlike the explicit BSD-grep override
(`" $(echo ${MY_OS} | grep BSD)" ) . ${BASE_DIR}/${PROGRAM}-bsd.sh`). Naming
the directory and driver file `darwin`/`cfg2html-darwin.sh` means this
generic resolution logic finds the new port with **zero changes** — the only
wrapper edit needed is a new respawn-shell case arm (below). Naming it
`macos` instead would require patching the shared `BASE_DIR`/`OS` resolution
logic that every other port also depends on — a needless, riskier
cross-cutting change for a cosmetic gain. "Darwin" is also the correct,
well-understood technical name for macOS's kernel/userland layer, so this
reads clearly to any Mac developer.

### Shell target: zsh in sh/ksh-emulation mode

macOS has shipped zsh (not bash) as its default shell since Catalina
(10.15), pre-installed on every Mac at `/bin/zsh` — this machine has zsh 5.9.
Apple's bundled `/bin/bash` is a frozen, ancient 3.2.57 (GPLv2 licensing
freeze); Homebrew bash would add an install dependency this sysadmin tool
shouldn't require. zsh avoids both problems.

zsh is not bash-compatible by default (different word-splitting rules,
1-indexed arrays, etc.), and the codebase's shared shell code — including the
`darwin/lib/*.sh` files this design adds, based on the Linux reference (see
below) — is written in bash/ksh-compatible style. To keep that code working
unmodified under zsh, the wrapper's respawn step targets zsh explicitly in
compatibility mode:

```sh
"Darwin" ) exec /bin/zsh ${PRGNAME} ${args} 2>&1 ;;
```

added to the existing respawn `case ${MY_OS} in ... esac` block, plus —
immediately after the respawn guard, before any other logic runs —
activating sh/ksh emulation for the rest of the process:

```sh
[ -n "${ZSH_VERSION}" ] && emulate -R sh
```

(`emulate -R` applies the emulation restrictively/persistently for the rest
of the script and everything it sources, not just locally.) The exact zsh
option set (`emulate -R sh` vs `emulate -R ksh` vs targeted `setopt`s like
`SH_WORD_SPLIT KSH_ARRAYS`) needs to be pinned empirically against the real
`darwin/lib/*.sh` files during implementation — this machine has zsh 5.9
available for that verification directly.

**Side benefit:** ShellCheck has no zsh dialect at all (`shellcheck
--shell=zsh` errors with "Unknown shell"). Because the new `darwin/*.sh`
files are deliberately written in the same bash/ksh-compatible dialect as
the rest of the codebase (that's the whole point of the emulation step),
they remain lintable by ShellCheck's default bash-dialect fallback — the
same fallback the shebang-less `aix`/`sunos`/`bsd` drivers already rely on.
No `.shellcheckrc` or per-file dialect override needed.

### Reference implementation base

`darwin/lib/*.sh` should be based on **`linux/lib/*.sh`**, not the top-level
`./lib/*.sh`. CLAUDE.md currently describes the top-level `lib/*.sh` as
"shared across every OS variant," but this was verified inaccurate during
this design's research: the wrapper only ever dot-sources
`${BASE_DIR}/lib/*.sh`, where `BASE_DIR` resolves to the per-OS directory
(e.g. `./linux`) in checkout mode — the top-level `./lib/*.sh` is never
sourced at all in that flow. Each OS's `lib/*.sh` is an independently
maintained fork that has drifted from the top-level copy over time. Linux's
is explicitly called out elsewhere in CLAUDE.md as "the most developed and a
good reference," and is the most complete/modern function set (`paragraph`/
`exec_command`/`AddText` in `html-functions.sh`, etc.) to adapt from.
(Correcting the stale CLAUDE.md description is worth doing, but as a
separate, unrelated change — not bundled into this feature.)

## Collector categories (Phase 1 MVP)

All 7 collector categories common to every existing port, each its own
`CFG_*="yes"` toggle in `darwin/etc/default.conf` with a corresponding
opt-out `getopts` flag and `usage()` line — exactly the same three-file
plumbing pattern used for `CFG_VMWARE`/`-V`, `CFG_CRON`/`-c`, and this
project's own recent `CFG_CONTAINERS`/`-C` addition on Linux.

| Toggle | macOS data source |
|---|---|
| `CFG_SYSTEM` | `sw_vers`, `system_profiler SPSoftwareDataType`, `uname -a`, `hostname`, `uptime`, selected `sysctl` values |
| `CFG_HARDWARE` | `system_profiler SPHardwareDataType`, `system_profiler SPMemoryDataType`, `sysctl hw.*` |
| `CFG_FILESYS` | `diskutil list`, `diskutil apfs list`, `df -h`, `mount` |
| `CFG_KERNEL` | `sysctl kern.*`, `kextstat` (or `kmutil showloaded` on newer macOS where `kextstat` is deprecated), `nvram boot-args` |
| `CFG_NETWORK` | `ifconfig`, `networksetup -listallhardwareports`, `netstat -rn`, `scutil --dns` |
| `CFG_SOFTWARE` | `system_profiler SPApplicationsDataType`, `pkgutil --pkgs`, `softwareupdate --history`, Homebrew package list if `brew` is present |
| `CFG_APPLICATIONS` | `/Applications` directory listing, `launchctl list` (LaunchAgents/LaunchDaemons), Homebrew/MacPorts presence detection |

Exact `exec_command` call lists per category are plan-level detail, not
pinned here — consistent with how every other port's collector lines were
added incrementally. One caution worth carrying into the plan:
`system_profiler` can be slow with broad/unscoped data types, so collector
calls should request specific `SP*DataType` arguments rather than a full
dump, to keep report generation reasonably fast.

## Error handling & degradation

No new mechanism — this follows the existing `exec_command` model used
throughout the codebase (and matches the recent Docker/Podman collector
work): a failing subcommand's stderr routes to `$ERROR_LOG` without aborting
the run. Two macOS-specific wrinkles to carry into the implementation
(not new error-handling code, just things to expect):

- **Binary-presence gating**: use the same `BIN=$(which "${TOOL}" 2>/dev/null); [ -n "${BIN}" ] && [ -x "${BIN}" ]` idiom already established in this codebase for anything not guaranteed present on every macOS install (`brew`, `port`, `kmutil` vs `kextstat` depending on OS version).
- **SIP (System Integrity Protection)**: some `/System` paths and kernel-introspection points are SIP-restricted and return permission errors even running as root. These degrade the same way as any other failing command (routed to `$ERROR_LOG`) — no special-casing required, just worth a doc comment near the kernel/kext collector where it's most likely to surface.

## Testing / verification

No automated test suite exists in this repo (deliberate, documented project
convention) — verification is:

- **Syntax check** with the *actual* target interpreter: `zsh -n
  darwin/cfg2html-darwin.sh` and `zsh -n darwin/lib/*.sh` (not `bash -n` —
  a script can be valid bash but behave differently, or be invalid, under
  zsh emulation, so checking with zsh itself is the meaningful test here).
- **Static analysis**: `shellcheck -S warning darwin/cfg2html-darwin.sh
  darwin/lib/*.sh darwin/etc/default.conf` at the same severity the CI's
  Differential ShellCheck enforces, relying on ShellCheck's default
  bash-dialect fallback (no shebang, matching the `aix`/`sunos`/`bsd`
  precedent).
- **Real end-to-end run**: unlike prior work on this codebase constrained to
  a non-matching dev platform, this Mac *is* the target platform — `sudo
  ./cfg2html` can be run directly here for genuine end-to-end verification
  of the generated HTML/text report at each phase of implementation, not
  just isolated logic checks.

## Non-goals (out of scope for this MVP)

- **No packaging** — no `.pkg` installer, no Homebrew formula, no `make
  darwin` build target. Per CLAUDE.md, day-to-day development doesn't
  require a build step; `sudo ./cfg2html` runs directly from a checkout.
  Packaging can follow as its own later phase once the collector is proven
  out.
- **No `CFG_CRON`/launchd collector, no `CFG_ENHANCEMENTS`, no
  printer/license/cluster-style toggles** — present on some other ports
  (e.g. SunOS/BSD) but outside the common 7-category core and not an
  obvious MVP priority for macOS.
- **No parity requirement with any specific other port.** The goal is a
  genuinely useful macOS DR report using native tools, not a checkbox-matched
  feature set against Linux or any other variant.
- **No changes to the top-level `./lib/*.sh` files**, and no fix to the
  CLAUDE.md description of them as "shared across every OS variant" (verified
  inaccurate during this design's research) — worth doing, but as a
  separate, unrelated change.

## Open questions / follow-ups (not blocking this design)

- Exact `emulate`/`setopt` incantation for zsh sh/ksh-compatibility mode
  needs empirical verification against the real `darwin/lib/*.sh` files
  during implementation.
- Whether to test explicitly on both Apple Silicon and Intel Macs is left
  to whoever implements/reviews this — not blocking for a Phase 1 MVP spec.
- A follow-up phase could add packaging, launchd/cron collection, and
  broader parity with other ports' extra toggles, each its own spec/plan
  cycle.
