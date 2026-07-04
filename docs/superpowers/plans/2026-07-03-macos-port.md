# macOS (Darwin) Port — Phase 1 MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `darwin/` OS port to cfg2html so `sudo ./cfg2html` produces a real HTML/text disaster-recovery report on macOS, covering the 7 collector categories common to every existing port (System, Hardware, Filesystem, Kernel, Network, Software, Applications), using macOS-native tools.

**Architecture:** New top-level `darwin/` directory mirroring the existing `aix`/`bsd`/`hpux`/`linux`/`sunos` shape (driver script, `lib/*.sh`, `etc/{default.conf,local.conf}`). The generic report-primitive lib files (`html-functions.sh`, `input-output-functions.sh`, `shell-functions.sh`) are copied verbatim from `linux/lib/` — exactly the same "pure fork" pattern every other port already uses for these files (verified: `aix`/`bsd`/`sunos` all carry byte-identical copies, unedited, including a decade-old vestigial "cfg2html for Linux" string nobody has ever corrected). `global-functions.sh` is copied verbatim plus two new comment-only annotations documenting zsh-specific incompatibilities discovered during this plan's research. `help-functions.sh` (usage text) and `darwin-functions.sh` (macOS version detection) are new, OS-specific content. The top-level `cfg2html` wrapper gets one new respawn-shell case (targeting `/bin/zsh` in sh-emulation mode) and one `TMP_DIR` case addition — no changes to its generic `BASE_DIR`/`OS` resolution logic, because naming the port `darwin` (matching lowercased `uname` output) makes that resolution work automatically.

**Tech Stack:** POSIX/Bourne-family shell, `/bin/zsh` (macOS's pre-installed default shell, 5.9 on this machine) running in `emulate -R sh` compatibility mode, macOS-native CLI tools (`sw_vers`, `system_profiler`, `diskutil`, `sysctl`, `ifconfig`, `networksetup`, `scutil`, `pkgutil`, `launchctl`, etc. — every command below was run and verified on this actual machine during planning, not guessed from memory).

## Global Constraints

- **Directory/file naming is fixed:** `darwin/cfg2html-darwin.sh`, matching lowercased `uname` output exactly (`"darwin"`) so the wrapper's existing generic `BASE_DIR="${MYPATH}/${OS}"` / `${PROGRAM}-${OS}.sh` resolution finds it with no changes beyond the respawn-shell case. Do not name anything `macos`.
- **No shebang line** on `darwin/cfg2html-darwin.sh` or any `darwin/lib/*.sh` file — it is always dot-sourced by the wrapper, never executed directly. This matches the `aix`/`sunos`/`bsd` precedent (verified: none of those three drivers has a shebang either).
- **Shell target is `/bin/zsh` in sh-emulation mode**, activated via `[ -n "${ZSH_VERSION}" ] && emulate -R sh` immediately after the wrapper's respawn guard. This exact incantation was verified on this machine (zsh 5.9) to produce byte-identical behavior to bash for every construct actually used in the copied lib files: word-splitting, `[[ ]]`, `let`, `local`, 0-indexed arrays, `eval`, `echo -e "...\c"`, `(( ))` arithmetic, `trap`/`kill -USR1`, `typeset`, and `$(<file)`. Two constructs do NOT work under this emulation and must be called out with a comment rather than silently fixed or silently left undocumented: bash's `${!var}` indirect expansion (breaks with "bad substitution") and `set -m` (breaks with "can't change option: -m"). Both are confirmed unused by any of this plan's 7 MVP categories — do not attempt to fix them.
- **No `shopt`** anywhere in the darwin driver — zsh has no `shopt` builtin (bash-only). The Linux driver's PATH-management block (lines ~56-92 of `linux/cfg2html-linux.sh`) uses `shopt -s extglob` and Linux-specific virtualization-detection logic; **do not copy that block** into the darwin driver. The darwin driver skeleton in Task 1 is deliberately smaller.
- **Every collector command below was run and verified on this real Mac** during planning (macOS 26.5.1, Apple Silicon, zsh 5.9) — exact output shapes are known, not guessed. If a task's exact command differs from what's below, treat that as a signal to stop and ask, not to improvise.
- **No `inspect`-style deep dumps of secrets** — not directly applicable here (no container-style secrets risk in these 7 categories), but keep the same spirit: don't add commands beyond what's specified per task.
- **No automated test suite** — this repo has none (documented in `CLAUDE.md`). Per-task automated verification is `zsh -n <file>` (syntax, using the real target interpreter — not `bash -n`) and `shellcheck -S warning <file>` (relying on ShellCheck's default bash-dialect fallback, same as the shebang-less `aix`/`sunos`/`bsd` drivers).
- **Root-requiring end-to-end verification (`sudo ./cfg2html ...`) is NOT something implementer subagents should attempt.** This machine has no cached `sudo` credential (verified: `sudo -n true` fails), and an unattended subagent cannot supply an interactive password. Each task's implementer runs only the root-free checks (`zsh -n`, `shellcheck`). The real end-to-end run on this machine is performed by the controller/human directly, interactively, between tasks — call this out in every task's verification section rather than asking the implementer to do it.
- **No packaging, no `CFG_CRON`/launchd collector, no parity requirement with other ports** — explicit non-goals carried over from the design spec.

---

### Task 1: Foundation — wrapper wiring, darwin/ scaffold, and CFG_SYSTEM

**Files:**
- Modify: `cfg2html:19-26` (respawn shell-selection case block)
- Modify: `cfg2html:62-66` (TMP_DIR case block)
- Create: `darwin/lib/html-functions.sh` (verbatim copy of `linux/lib/html-functions.sh`)
- Create: `darwin/lib/input-output-functions.sh` (verbatim copy of `linux/lib/input-output-functions.sh`)
- Create: `darwin/lib/shell-functions.sh` (verbatim copy of `linux/lib/shell-functions.sh`)
- Create: `darwin/lib/global-functions.sh` (copy of `linux/lib/global-functions.sh` + 2 comment-only additions)
- Create: `darwin/lib/help-functions.sh` (new)
- Create: `darwin/lib/darwin-functions.sh` (new)
- Create: `darwin/etc/default.conf` (new)
- Create: `darwin/etc/local.conf` (new)
- Create: `darwin/cfg2html-darwin.sh` (new)

**Interfaces:**
- Produces: the `CFG_SYSTEM`, `CFG_HARDWARE`, `CFG_FILESYS`, `CFG_KERNEL`, `CFG_NETWORK`, `CFG_SOFTWARE`, `CFG_APPLICATIONS` shell variables (all declared `"yes"` in `darwin/etc/default.conf`, all overridable to `"no"` via `getopts` in `darwin/cfg2html-darwin.sh`). Tasks 2-7 each consume one of `CFG_HARDWARE`/`CFG_FILESYS`/`CFG_KERNEL`/`CFG_NETWORK`/`CFG_SOFTWARE`/`CFG_APPLICATIONS` (already declared here, but with no collector body yet — Tasks 2-7 add the body) via `if [ "${CFG_X}" != "no" ] ... fi` in `darwin/cfg2html-darwin.sh`.
- Produces: `function identify_macos_version` in `darwin/lib/darwin-functions.sh`, setting `MACOS_VERSION` (e.g. `"macOS 26.5.1 (25F80)"`) for use in the `CFG_SYSTEM` paragraph heading.
- Consumes: `paragraph`, `inc_heading_level`, `dec_heading_level`, `exec_command`, `AddText`, `open_html`, `close_html` (from `darwin/lib/html-functions.sh`); `check_root`, `create_dirs`, `line`, `_banner`, `_echo` (from `darwin/lib/shell-functions.sh`); `define_outfile` (from `darwin/lib/global-functions.sh`); `usage` (from `darwin/lib/help-functions.sh`).

- [ ] **Step 1: Wire the wrapper's respawn shell selection**

In `cfg2html`, lines 19-26 currently read:

```sh
    case ${MY_OS} in
                              "AIX" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
     " $(echo ${MY_OS} | grep BSD)" ) exec /usr/local/bin/bash ${PRGNAME} ${args}  2>&1 ;;
                            "HP-UX" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
                            "Linux" ) exec /bin/bash -O extglob ${PRGNAME} ${args} 2>&1 ;;
                            "SunOS" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
                                 *  ) echo "WARNING: Unsupported Operating System, continuing anyway" # prior code just continued on # modified on 20201031 by edrulrd
                                        ;;
    esac
```

Change it to:

```sh
    case ${MY_OS} in
                              "AIX" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
     " $(echo ${MY_OS} | grep BSD)" ) exec /usr/local/bin/bash ${PRGNAME} ${args}  2>&1 ;;
                            "HP-UX" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
                            "Linux" ) exec /bin/bash -O extglob ${PRGNAME} ${args} 2>&1 ;;
                            "SunOS" ) exec /usr/bin/ksh ${PRGNAME} ${args}         2>&1 ;;
                           "Darwin" ) exec /bin/zsh ${PRGNAME} ${args}             2>&1 ;;
                                 *  ) echo "WARNING: Unsupported Operating System, continuing anyway" # prior code just continued on # modified on 20201031 by edrulrd
                                        ;;
    esac
fi

[ -n "${ZSH_VERSION}" ] && emulate -R sh
```

Note the added blank-then-`fi` line: the `emulate -R sh` activation line goes **immediately after** the existing `fi` that closes the `if [ ! -f /tmp/cfg2html.respawn ]; then` block (i.e., right before the `# [20200321] {jcw} Obviously the 'exec' continues through to here.` comment and `STARTTIME="${SECONDS}"` line). It must run unconditionally on every continued execution (including the respawned zsh process), not just inside the case block. Double-check the surrounding context with `grep -n "STARTTIME" cfg2html` before editing — insert the `emulate` line between the closing `fi` and `STARTTIME="${SECONDS}"`, not inside the `case` block.

- [ ] **Step 2: Wire the wrapper's TMP_DIR case block**

In `cfg2html`, the `TMP_DIR` case block currently reads:

```sh
case ${MY_OS} in
    HP-UX) TMP_DIR="$(mktemp -d /tmp -p cfg2html_)" ;;
    Linux|SunOS) TMP_DIR="$(mktemp -d /tmp/cfg2html.XXXXXXXXXXXXXXX)" ;;
    *) TMP_DIR="/tmp/${PROGRAM}_${RANDOM}" ;;	## hopefully AIX and SUN have $RANDOM too - why not using mktemp too, its safer! RR
esac
```

Change it to:

```sh
case ${MY_OS} in
    HP-UX) TMP_DIR="$(mktemp -d /tmp -p cfg2html_)" ;;
    Linux|SunOS|Darwin) TMP_DIR="$(mktemp -d /tmp/cfg2html.XXXXXXXXXXXXXXX)" ;;
    *) TMP_DIR="/tmp/${PROGRAM}_${RANDOM}" ;;	## hopefully AIX and SUN have $RANDOM too - why not using mktemp too, its safer! RR
esac
```

- [ ] **Step 3: Verify the wrapper's syntax after both edits**

Run: `bash -n cfg2html && zsh -n cfg2html && echo SYNTAX_OK`
Expected: `SYNTAX_OK` (the wrapper itself is dialect-neutral enough to check with both — it must parse cleanly under both since HP-UX/AIX/SunOS respawn into ksh, Linux/BSD into bash, and now Darwin into zsh, all executing this same file).

- [ ] **Step 4: Scaffold the darwin/ directory tree**

```bash
mkdir -p darwin/lib darwin/etc
```

- [ ] **Step 5: Copy the three fully-generic lib files verbatim**

```bash
cp linux/lib/html-functions.sh darwin/lib/html-functions.sh
cp linux/lib/input-output-functions.sh darwin/lib/input-output-functions.sh
cp linux/lib/shell-functions.sh darwin/lib/shell-functions.sh
```

These three files contain no Linux-specific logic (verified during planning) — `shell-functions.sh`'s `_echo` function already has a `linux|darwin)` branch, so it works correctly for macOS with zero changes. This exactly matches how `aix/lib/`, `bsd/lib/`, and `sunos/lib/` already carry byte-identical, unedited copies of these same three files.

- [ ] **Step 6: Copy global-functions.sh and add the two zsh-caveat comments**

```bash
cp linux/lib/global-functions.sh darwin/lib/global-functions.sh
```

Then, in `darwin/lib/global-functions.sh`, the `mount_url` function's `case` statement currently has this arm (around line 68-72):

```sh
        (var)
            ### The mount command is given by variable in the url host
            var=$(url_host ${url})
            mount_cmd="${!var} ${mountpoint}"
            ;;
```

Change it to:

```sh
        (var)
            ### The mount command is given by variable in the url host
            # NOTE (darwin port): "${!var}" is bash indirect expansion and
            # fails under this port's zsh sh-emulation mode ("bad
            # substitution", verified). This "var://" OUTPUT_URL scheme is
            # unsupported on macOS until someone needs it and fixes this.
            var=$(url_host ${url})
            mount_cmd="${!var} ${mountpoint}"
            ;;
```

And the `umount_url` function's matching `(var)` arm (around line 110-119):

```sh
        (var)
            var=$(url_host ${url})
            umount_cmd="${!var} ${mountpoint}"

            Log "Unmounting with '$umount_cmd'"
            $umount_cmd
            StopIfError "Unmounting failed."

            return 0
            ;;
```

Change it to:

```sh
        (var)
            # NOTE (darwin port): see matching NOTE in mount_url() above —
            # "${!var}" does not work under this port's zsh emulation mode.
            var=$(url_host ${url})
            umount_cmd="${!var} ${mountpoint}"

            Log "Unmounting with '$umount_cmd'"
            $umount_cmd
            StopIfError "Unmounting failed."

            return 0
            ;;
```

And the `TimeOut` function's opening line (around line 193-196):

```sh
function TimeOut {
    # simple timeout function - usage:
    # TimeOut secs command arguments
    (
    set -m
```

Change it to:

```sh
function TimeOut {
    # simple timeout function - usage:
    # TimeOut secs command arguments
    # NOTE (darwin port): "set -m" fails under this port's zsh emulation
    # mode ("can't change option: -m", verified). This function is unused
    # by the driver today — fix if/when something actually calls it.
    (
    set -m
```

- [ ] **Step 7: Write darwin/lib/help-functions.sh**

```sh

## $Id: help-functions.sh - macOS (Darwin) part

function usage {
  echo "WARNING, use this script AT YOUR OWN RISK"
  echo
  echo "    Usage: `basename $0` [OPTIONS]"
  echo "           creates host documentation in HTML and plain ASCII "
  echo "    Output modifier:"
  echo "    -o      set directory to write to; or use the environment"
  echo "            variable OUTDIR=\"/path/to/dir\""
  echo "    -0      append the current date+time to the output files (D-M-Y-hhmm)"
  echo "    -1      append the current date to the output files (Day-Month-Year)"
  echo "    -2 arg  like option -1, you can use date +modifier, e.g. -2%d%m or -2 %Y%m%d-%H%M"
  echo "            DO NOT use spaces for the filename, e.g. -2%c"
  echo
  echo "    Help:"
  echo "    -v      output version information and exit"
  echo "    -h      display this help and exit"
  echo

  echo "    use the following options to disable / enable collections:"
  echo "    -s      disable: System"
  echo "    -H      disable: Hardware"
  echo "    -f      disable: Filesystem"
  echo "    -k      disable: Kernel"
  echo "    -n      disable: Network"
  echo "    -S      disable: Software"
  echo "    -a      disable: Applications"
  echo "    -w arg  adjust the width of the section separators in the generated ASCII file and allow for columnar output"
  echo "    -T      enable:  trace timings in output (txt, html and err)"
}
```

- [ ] **Step 8: Write darwin/lib/darwin-functions.sh**

```sh

# cfg2html - macOS (Darwin) specific functions

function identify_macos_version {
    MACOS_VERSION="$(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
}
```

- [ ] **Step 9: Write darwin/etc/default.conf**

```sh
# shellcheck disable=SC2034,SC2148
# (note - shellcheck directive needs to be at the very top to be effective over the whole file)
# SC2034 - variable appears to be used
# SC2148 - we are shell agnostic

# default.conf file for macOS (Darwin)
#============================
# Do not change variables here!
# To override add yours to the local.conf file which is read after default.conf

#
# use "no" to disable a collection
#
CFG_APPLICATIONS="yes"
CFG_FILESYS="yes"
CFG_HARDWARE="yes"
CFG_KERNEL="yes"
CFG_NETWORK="yes"
CFG_SOFTWARE="yes"
CFG_STINLINE="yes"
CFG_SYSTEM="yes"
CFG_TRACETIME="no"  # show seconds spent in a function

CFG_TEXTWIDTH="74" # set the originally defined, hard-coded, default width of the section headers in lib/html-functions.sh
export COLUMNS=${CFG_TEXTWIDTH}

if [ -z "$OUTDIR" ]
then
  OUTDIR="${VAR_DIR}"
fi

LOCK=/tmp/LockFile-cfg2html

CFG_DATE=""	# used by options [012]
```

- [ ] **Step 10: Write darwin/etc/local.conf**

```sh
# Example of /etc/cfg2html/local.conf file for macOS (Darwin)
####
# OUTPUT_URL=[proto]://[host]/[share]
# example: nfs://lucky/temp/backup
# example: cifs://lucky/temp
# example: file:///path
####
#CFG_TRACETIME="yes"
```

- [ ] **Step 11: Write darwin/cfg2html-darwin.sh**

```sh
# cfg2html - macOS (Darwin) driver
# -----------------------------------------------------------------------------------------
#  system collector script - macOS (Darwin) port

CFGSH=$_

_VERSION="cfg2html-darwin version ${VERSION} "

#
# getopt
#

while getopts ":o:vhsHfknSaw:T2:10" Option
do
  case ${Option} in
    o     ) OUTDIR=${OPTARG};;
    v     ) echo "${_VERSION}""// $(uname -mrs)"; exit 0;;
    h     ) echo "${_VERSION}"; usage; exit 0;;
    s     ) CFG_SYSTEM="no";;
    H     ) CFG_HARDWARE="no";;
    f     ) CFG_FILESYS="no";;
    k     ) CFG_KERNEL="no";;
    n     ) CFG_NETWORK="no";;
    S     ) CFG_SOFTWARE="no";;
    a     ) CFG_APPLICATIONS="no";;
    w     ) CFG_TEXTWIDTH="${OPTARG}";;
    T     ) CFG_TRACETIME="yes";;
    2     ) CFG_DATE="_"$(date +"${OPTARG}") ;;
    1     ) CFG_DATE="_"$(date +%d-%b-%Y) ;;
    0     ) CFG_DATE="_"$(date +%d-%b-%Y-%H%M) ;;
    *     ) echo "Unimplemented command line option chosen. Try -h for help!"; exit 1;;
  esac
done

shift $((OPTIND - 1))

MAILTO="&#106;&#101;&#114;&#111;&#101;&#110;&#46;&#107;&#108;&#101;&#101;&#110;&#64;&#104;&#112;&#46;&#99;&#111;&#109;"
MAILTORALPH="cfg2html&#64;&#104;&#111;&#116;&#109;&#97;&#105;&#108;&#46;&#99;&#111;&#109;"

## test if user = root
check_root

# define the HTML_OUTFILE, TEXT_OUTFILE, ERROR_LOG
define_outfile

# create our VAR_DIR, OUTDIR before we continue
create_dirs

if [ ! -d "${OUTDIR}" ] ; then
  echo "can't create ${HTML_OUTFILE}, ${OUTDIR} does not exist - stop"
  exit 1
fi
touch "${HTML_OUTFILE}"
[ -s "${ERROR_LOG}" ] && rm -f "${ERROR_LOG}" 2> /dev/null
DATE=$(date "+%Y-%m-%d")
DATEFULL=$(date "+%Y-%m-%d@%H:%M:%S")

exec 2> "${ERROR_LOG}"

if [ ! -f "${HTML_OUTFILE}" ]; then
     line
     _banner "Error"
     _echo "You do not have the rights to create the file ${HTML_OUTFILE}! (NFS?)\n"
     exit 1
fi

[ "$(which logger 2>/dev/null)" ] && export _logger="$(which logger)" || export _logger='echo'
${_logger} "1st Start of cfg2html-darwin ${VERSION}"
RECHNER=$(hostname)
typeset -i HEADL=0

#
# identify macOS version
#
identify_macos_version

######################################################################
#############################  M A I N  ##############################
######################################################################

line
echo "Starting:          ${_VERSION}"
echo "Path to cfg2html:  $0"
echo "HTML Output File:  ${HTML_OUTFILE}"
echo "Text Output File:  ${TEXT_OUTFILE}"
echo "Errors logged to:  ${ERROR_LOG}"
[[ -f ${CONFIG_DIR}/local.conf ]] && { echo "Local config      ${CONFIG_DIR}"/local.conf "$(grep -vc -E '(^#|^$)' "${CONFIG_DIR}"/local.conf) lines"; }
echo "Started at        ${DATEFULL}"
echo "WARNING           USE AT YOUR OWN RISK!!! :-))           <<<<<"
line

if [[ "${CFG_TEXTWIDTH}" =~ ^[0-9]+$ ]]
then
  [ "${CFG_TEXTWIDTH}" -ne ${COLUMNS} ] && COLUMNS=${CFG_TEXTWIDTH}
else
  echo "Improper -w value given:  width value must be numerical. Try -h for help!"
  exit 1
fi

${_logger} "2nd Start of cfg2html-darwin ${VERSION}!"
open_html
inc_heading_level

#
# CFG_SYSTEM
#

if [ "${CFG_SYSTEM}" != "no" ]
then # else skip to next paragraph

paragraph "macOS System:  [${MACOS_VERSION}]"
inc_heading_level
  exec_command "sw_vers" "macOS version"
  exec_command "system_profiler SPSoftwareDataType" "System software overview"
  exec_command "uname -a" "Kernel/OS version string"
  exec_command "hostname" "Hostname"
  exec_command "uptime" "Uptime"
dec_heading_level

fi  # end of CFG_SYSTEM paragraph
##############################################################################

dec_heading_level
close_html

${_logger} "1st End of cfg2html-darwin ${VERSION}"
_echo "\n"
line
${_logger} "2nd End of cfg2html-darwin ${VERSION}"

[ ! -s "${ERROR_LOG}" ] && rm -f "${ERROR_LOG}" 2>/dev/null

sync;sync;sync
exit 0
```

- [ ] **Step 12: Syntax-check every new/copied darwin file with the real target interpreter**

Run: `zsh -n darwin/cfg2html-darwin.sh && for f in darwin/lib/*.sh; do zsh -n "$f" || echo "FAILED: $f"; done && echo SYNTAX_OK`
Expected: `SYNTAX_OK` with no `FAILED:` lines.

- [ ] **Step 13: ShellCheck every new/copied darwin file**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh darwin/lib/*.sh darwin/etc/default.conf`
Expected: no output (0 warnings) — ShellCheck falls back to its default bash dialect since none of these files has a shebang, and every construct used is bash/ksh-compatible by design.

- [ ] **Step 14: Confirm the three verbatim-copied files are byte-identical to their Linux source**

Run: `diff linux/lib/html-functions.sh darwin/lib/html-functions.sh; diff linux/lib/input-output-functions.sh darwin/lib/input-output-functions.sh; diff linux/lib/shell-functions.sh darwin/lib/shell-functions.sh; echo DONE`
Expected: no diff output for any of the three (silent), then `DONE`.

- [ ] **Step 15: Commit**

```bash
git add cfg2html darwin/
git commit -m "new: dev: Add macOS (Darwin) port foundation with CFG_SYSTEM collector"
```

- [ ] **Step 16 (controller/human only — do not delegate to an implementer subagent): real end-to-end verification**

This is the first task where the darwin port can actually run. From the repo root, with an interactive terminal that can supply the `sudo` password:

```bash
sudo ./cfg2html -o /tmp/darwin-test-1
```

Expected: the run completes without a fatal error, prints `No errors reported.` (or an `.err` file path if something in `CFG_SYSTEM`'s 5 commands failed), and produces `/tmp/darwin-test-1/<hostname>.html` and `.txt`. Confirm the HTML file contains a `macOS System:` heading and that all 5 commands (`sw_vers`, `system_profiler SPSoftwareDataType`, `uname -a`, `hostname`, `uptime`) show real output, not `n/a or not configured`. Also confirm `sudo ./cfg2html -h` prints the darwin `usage()` text (all 7 disable flags plus `-w`/`-T`/`-o`/`-v`/`-h`).

---

### Task 2: CFG_HARDWARE collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_SYSTEM` block's closing `fi`/`##...##` separator from Task 1)

**Interfaces:**
- Consumes: `CFG_HARDWARE` (declared in Task 1's `darwin/etc/default.conf` and `getopts`, no collector body until now), `paragraph`/`inc_heading_level`/`dec_heading_level`/`exec_command` (from Task 1's `darwin/lib/html-functions.sh`).

- [ ] **Step 1: Insert the CFG_HARDWARE section**

In `darwin/cfg2html-darwin.sh`, immediately after the line `##############################################################################` that follows `fi  # end of CFG_SYSTEM paragraph` (and before `dec_heading_level` / `close_html`), insert:

```sh
#
# CFG_HARDWARE
#

if [ "${CFG_HARDWARE}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Hardware"
inc_heading_level
  exec_command "system_profiler SPHardwareDataType" "Hardware overview"
  exec_command "system_profiler SPMemoryDataType" "Memory configuration"
  exec_command "sysctl hw" "hw.* sysctl values"
dec_heading_level

fi  # end of CFG_HARDWARE paragraph
##############################################################################
```

Verified on this machine: `system_profiler SPHardwareDataType` returns model/chip/core-count/memory/serial in ~0.2s; `system_profiler SPMemoryDataType` returns memory type/manufacturer in ~0.1s; `sysctl hw` dumps ~138 lines of `hw.*` values in well under a second. All three are fast enough to not need any timeout wrapper.

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_HARDWARE collector to macOS port"
```

- [ ] **Step 5 (controller/human only): real end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-2
```

Expected: report now contains both `macOS System:` and `macOS Hardware` headings; the Hardware section shows a real `Model Name`/`Chip` line (not `n/a or not configured`).

---

### Task 3: CFG_FILESYS collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_HARDWARE` block from Task 2)

**Interfaces:**
- Consumes: `CFG_FILESYS` (declared in Task 1), same report primitives as Task 2.

- [ ] **Step 1: Insert the CFG_FILESYS section**

Immediately after `fi  # end of CFG_HARDWARE paragraph` / `##############################################################################` from Task 2, insert:

```sh
#
# CFG_FILESYS
#

if [ "${CFG_FILESYS}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Filesystems"
inc_heading_level
  exec_command "diskutil list" "Disks and partitions"
  exec_command "diskutil apfs list" "APFS containers and volumes"
  exec_command "df -h" "Filesystem usage"
  exec_command "mount" "Mounted filesystems"
dec_heading_level

fi  # end of CFG_FILESYS paragraph
##############################################################################
```

Verified on this machine: `diskutil list` shows disk/partition layout including synthesized APFS disks; `diskutil apfs list` shows ~85 lines of container/volume detail; `df -h` and `mount` behave as expected. None require root beyond what the script already runs as.

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_FILESYS collector to macOS port"
```

- [ ] **Step 5 (controller/human only): real end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-3
```

Expected: report now also contains a `macOS Filesystems` heading with real `diskutil`/`df`/`mount` output.

---

### Task 4: CFG_KERNEL collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_FILESYS` block from Task 3)

**Interfaces:**
- Consumes: `CFG_KERNEL` (declared in Task 1), same report primitives.

- [ ] **Step 1: Insert the CFG_KERNEL section**

Immediately after `fi  # end of CFG_FILESYS paragraph` / `##############################################################################` from Task 3, insert:

```sh
#
# CFG_KERNEL
#

if [ "${CFG_KERNEL}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Kernel"
inc_heading_level
  exec_command "sysctl kern" "kern.* sysctl values"
  exec_command "kmutil showloaded" "Loaded kernel extensions"
  exec_command "nvram boot-args" "Kernel boot arguments"
dec_heading_level

fi  # end of CFG_KERNEL paragraph
##############################################################################
```

Verified on this machine: `sysctl kern` dumps ~431 lines; `kmutil showloaded` is the modern (non-deprecated) replacement for `kextstat` — running `kextstat` directly on this machine printed a deprecation notice ("Executing: /usr/bin/kmutil showloaded") and simply delegated to `kmutil showloaded` anyway, so this calls the real command directly instead of going through the deprecated wrapper. `nvram boot-args` returned a non-fatal "variable not found" error on this machine (no custom boot args set, the common case) — `exec_command` already handles this gracefully via its built-in `EXECRES="n/a or not configured"` fallback when a command's stdout is empty; no special-casing needed here.

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_KERNEL collector to macOS port"
```

- [ ] **Step 5 (controller/human only): real end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-4
```

Expected: report now also contains a `macOS Kernel` heading; `kern.*` and kext listings show real output; `boot-args` may legitimately show `n/a or not configured` (expected on a machine with no custom boot args) — that is a pass, not a failure.

---

### Task 5: CFG_NETWORK collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_KERNEL` block from Task 4)

**Interfaces:**
- Consumes: `CFG_NETWORK` (declared in Task 1), same report primitives.

- [ ] **Step 1: Insert the CFG_NETWORK section**

Immediately after `fi  # end of CFG_KERNEL paragraph` / `##############################################################################` from Task 4, insert:

```sh
#
# CFG_NETWORK
#

if [ "${CFG_NETWORK}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Network"
inc_heading_level
  exec_command "ifconfig" "Network interfaces"
  exec_command "networksetup -listallhardwareports" "Network hardware ports"
  exec_command "netstat -rn" "Routing table"
  exec_command "scutil --dns" "DNS configuration"
dec_heading_level

fi  # end of CFG_NETWORK paragraph
##############################################################################
```

Verified on this machine: all four commands run without root beyond what the script already has, and return real interface/hardware-port/routing/DNS data (confirmed non-empty output for all four during planning).

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_NETWORK collector to macOS port"
```

- [ ] **Step 5 (controller/human only): real end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-5
```

Expected: report now also contains a `macOS Network` heading with real interface/DNS output.

---

### Task 6: CFG_SOFTWARE collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_NETWORK` block from Task 5)

**Interfaces:**
- Consumes: `CFG_SOFTWARE` (declared in Task 1), same report primitives.

- [ ] **Step 1: Insert the CFG_SOFTWARE section**

Immediately after `fi  # end of CFG_NETWORK paragraph` / `##############################################################################` from Task 5, insert:

```sh
#
# CFG_SOFTWARE
#

if [ "${CFG_SOFTWARE}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Software"
inc_heading_level
  exec_command "system_profiler SPApplicationsDataType" "Installed applications (detailed)"
  exec_command "pkgutil --pkgs" "Installed Apple/vendor installer packages"
  exec_command "softwareupdate --history" "Software update history"

  BREW=$(which brew 2>/dev/null)
  if [ -n "${BREW}" ] && [ -x "${BREW}" ]; then
    exec_command "${BREW} list" "Homebrew packages installed"
  fi
dec_heading_level

fi  # end of CFG_SOFTWARE paragraph
##############################################################################
```

Verified on this machine: `system_profiler SPApplicationsDataType` takes ~5 seconds on a machine with a large `/Applications` folder (acceptable — comparable to other ports' bulk package-listing commands); `pkgutil --pkgs` returns ~276 lines; `softwareupdate --history` returns promptly; Homebrew is present at `/opt/homebrew/bin/brew` on this machine and `brew list` returns ~557 lines. The `which "${BREW}" && [ -x ]` gating follows the exact pattern already established in this codebase's recent Docker/Podman collector work (`linux/cfg2html-linux.sh`, the `for RUNTIME in docker podman` block) — only run `brew list` if Homebrew is actually installed, since not every Mac has it.

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_SOFTWARE collector to macOS port"
```

- [ ] **Step 5 (controller/human only): real end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-6
```

Expected: report now also contains a `macOS Software` heading; on this machine (Homebrew installed) it should include a Homebrew packages sub-section. Run this once more with `-o /tmp/darwin-test-6b` after temporarily renaming `/opt/homebrew` (or on a machine without Homebrew) to confirm the section is silently skipped — not required to block this task, but worth a spot-check.

---

### Task 7: CFG_APPLICATIONS collector

**Files:**
- Modify: `darwin/cfg2html-darwin.sh` (insert new section immediately after the `CFG_SOFTWARE` block from Task 6)

**Interfaces:**
- Consumes: `CFG_APPLICATIONS` (declared in Task 1), same report primitives.

- [ ] **Step 1: Insert the CFG_APPLICATIONS section**

Immediately after `fi  # end of CFG_SOFTWARE paragraph` / `##############################################################################` from Task 6, insert:

```sh
#
# CFG_APPLICATIONS
#

if [ "${CFG_APPLICATIONS}" != "no" ]
then # else skip to next paragraph

paragraph "macOS Applications and Subsystems"
inc_heading_level
  exec_command "ls -la /Applications" "Files in /Applications"
  exec_command "launchctl list" "Loaded launchd services (LaunchAgents/LaunchDaemons)"
dec_heading_level

fi  # end of CFG_APPLICATIONS paragraph
##############################################################################
```

This is deliberately not a duplicate of `CFG_SOFTWARE`'s `system_profiler SPApplicationsDataType` (which lists installed applications with version/signing detail) — this section covers subsystem/environment facts instead (what's in `/Applications` as plain files, and what launchd currently has loaded), matching the spirit of Linux's `CFG_APPLICATIONS` section (`ls -lisa /usr/local/bin`, `flatpak list`, etc. — subsystem listings, not a second copy of the package inventory). Verified on this machine: `ls -la /Applications` and `launchctl list` both run without root beyond what the script already has and return real, non-empty output.

- [ ] **Step 2: Syntax-check**

Run: `zsh -n darwin/cfg2html-darwin.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 3: ShellCheck**

Run: `shellcheck -S warning darwin/cfg2html-darwin.sh`
Expected: no output (0 warnings)

- [ ] **Step 4: Commit**

```bash
git add darwin/cfg2html-darwin.sh
git commit -m "new: dev: Add CFG_APPLICATIONS collector to macOS port"
```

- [ ] **Step 5 (controller/human only): final full end-to-end verification**

```bash
sudo ./cfg2html -o /tmp/darwin-test-final
```

Expected: the report now contains all 7 headings (`macOS System:`, `macOS Hardware`, `macOS Filesystems`, `macOS Kernel`, `macOS Network`, `macOS Software`, `macOS Applications and Subsystems`), `No errors reported.` or an `.err` file with only expected/benign entries (e.g. `nvram: boot-args not found`), and both `/tmp/darwin-test-final/<hostname>.html` and `.txt` are well-formed (open the `.html` file and visually confirm all 7 sections render). Also re-run `sudo ./cfg2html -s -H -f -k -n -S -a -o /tmp/darwin-test-empty` (all 7 disabled) and confirm the report generates with none of the 7 headings present — proving every toggle actually works.

## Self-Review Notes

- **Spec coverage:** new top-level `darwin/` directory (Task 1) ✓; naming matches lowercased `uname` with zero wrapper resolution-logic changes (Task 1, Step 1 only touches the respawn case + TMP_DIR case) ✓; zsh sh-emulation activation with the exact verified incantation (Task 1, Step 1) ✓; `linux/lib/*.sh`-based reference implementation, verbatim where possible (Task 1, Steps 5-6) ✓; all 7 MVP categories present with the exact macOS tool mapping from the design spec (Tasks 1-7) ✓; binary-presence gating for optional tools — Homebrew (Task 6) ✓; graceful degradation relying on existing `exec_command` error routing, no new error-handling code (called out per-task, e.g. Task 4's `nvram boot-args` note) ✓; no packaging/launchd-cron/parity work (absent from every task, consistent with Global Constraints) ✓.
- **Placeholder scan:** none found — every step has literal file content, exact commands, and exact expected output; no "TBD"/"similar to Task N"/unshown code.
- **Type consistency:** the shared symbols across tasks are the 7 `CFG_*` shell variables (declared once in Task 1's `darwin/etc/default.conf` and `getopts`, consumed identically as `"${CFG_X}" != "no"` in Tasks 2-7) and the report primitives (`paragraph`/`exec_command`/`inc_heading_level`/`dec_heading_level`, all from Task 1's copied `darwin/lib/html-functions.sh`) — consistent naming and call signature throughout every task.
