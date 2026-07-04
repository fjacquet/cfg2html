# shellcheck disable=SC2034,SC2148,SC2155
# (note - shellcheck directive needs to be at the very top to be effective over the whole file)
# SC2034 - variables are used across files sourced together (this file, darwin/lib/*.sh), not visible to a single-file scan
# SC2148 - dot-sourced by the wrapper, never executed directly, no shebang by design
# SC2155 - declare-and-assign-separately not needed (e.g., export _logger="$(which logger)")
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

dec_heading_level
close_html

${_logger} "1st End of cfg2html-darwin ${VERSION}"
_echo "\n"
line
${_logger} "2nd End of cfg2html-darwin ${VERSION}"

[ ! -s "${ERROR_LOG}" ] && rm -f "${ERROR_LOG}" 2>/dev/null

sync;sync;sync
exit 0
