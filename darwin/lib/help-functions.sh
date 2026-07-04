
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
