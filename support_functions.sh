SCRIPT_CMD_COLOR='\033[0;34m'  # <== red
SCRIPT_STEP_COLOR='\033[0m'    # <== default
SCRIPT_TITLE_COLOR='\033[1;32m'    # <== green
SCRIPT_RESET_COLOR='\033[0m'
SCRIPT_ERROR_COLOR='\033[1;31m'    # <== bold red

if [ -z "$LOGFILE" ]; then
    LOGFILE="$(pwd)/$(basename $0)-$(date --iso-8601=minutes).log"
fi


function LOG {
    printf "$*" >> "$LOGFILE"
}

function REPORT_COLOR {
    color="$1"
    shift
    LOG "$@"
    printf "${color}$*${SCRIPT_RESET_COLOR}"
}

function REPORT {
    REPORT_COLOR "$SCRIPT_STEP_COLOR" "$@\n"
}

function ERROR {
    REPORT_COLOR "${SCRIPT_ERROR_COLOR}" "ERROR: $@\n"
}

function EXEC {
    REPORT_COLOR "${SCRIPT_CMD_COLOR}" "  + $@\n"
    eval "$@" >>"$LOGFILE" 2>&1 || ERROR "command failed!"
}


# Convenience function to produce a prominent colourised 
# section title (e.g. ID of subject currently being processed)
#
# Usage:
#   title 'subject XYZ'
function title {
    printf "\n${SCRIPT_TITLE_COLOR}================================================================================\n" 
    printf "    $@\n"
    printf "================================================================================${SCRIPT_RESET_COLOR}\n"

    LOG '================================================================================\n'
}



function outputs_exist {
    for f in "$@"; do
        [ -e "$f" ] || return 1
    done
    return 0
}

function inputs_older_than {
    ref="$1"
    shift
    for f in "$@"; do
        [ "$f" -nt "$ref" ] && return 1
    done
    return 0
}



# Convenience function to run a step in the preprocessing if
# outputs are missing or inputs are newer than outputs. 
#
# usage:
#   run 'progress message' cmd [args...]
#
# where args can be prefixed with IN: (e.g. IN:image.nii) to denote an 
# input file, or prefixed with OUT: to denote an output
function run {
  REPORT_COLOR "$SCRIPT_STEP_COLOR" "> "$1"... "
  cmd=("$2")
  shift 2

  inputs=()
  outputs=()

  # build list of input & output arguments:
  for arg in "$@"; do
    if [[ "$arg" == IN:* ]]; then 
      arg="${arg#IN:}"
      inputs+=("$arg")
      cmd+=("$arg")
    elif [[ "$arg" == OUT:* ]]; then
      arg="${arg#OUT:}"
      outputs+=("$arg")
      cmd+=("tmp-$arg")
    else
      cmd+=("$arg")
    fi
  done

  #echo inputs=${inputs[@]}
  #echo outputs=${outputs[@]}

  # if everything is alread up to date, return now:
  (( "${#outputs[@]}" )) && { 
      outputs_exist "${outputs[@]}" && \
      inputs_older_than "${outputs[0]}" "${inputs[@]}" 
  } && {
      REPORT_COLOR "$SCRIPT_STEP_COLOR" "up to date\n"
      return 0
  }
  REPORT_COLOR "" "\n"

  # need to recompute: run command with temporary output names, 
  # then rename to final output filenames if successful.
  # This is necessary to ensure no confusion for the next run, 
  # since the creation of the output shouldn't by itself signify success.
  EXEC "${cmd[@]}" && {
    for out in "${outputs[@]}"; do
      mv "tmp-$out" "$out"
    done
  }
  rm -f "tmp-*"

  return $retval
}


# Convenience function to prefix all arguments with IN:
# This is useful when using pattern matching to capture all inputs
# when passing a command to the 'run' function above, using command substitution.
#
# For example:
#   run 'an example command aggregating a lot of input files' \
#     mrmath $(IN *.nii) mean OUT:mean.nii
function IN {
  for x in $@; do
    echo IN:$x
  done
}
