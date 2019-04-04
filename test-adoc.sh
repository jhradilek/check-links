#!/bin/bash

# test-adoc.sh - test an AsciiDoc file and report possible issues
# Copyright (C) 2013, 2014, 2019 Jaromir Hradilek <jhradilek@gmail.com>

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
#
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
#
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

# -------------------------------------------------------------------------
#                            GLOBAL VARIABLES
# -------------------------------------------------------------------------

# General information about the script:
declare -r NAME=${0##*/}
declare -r VERSION='0.0.1'

# Counters for tested items:
declare -i ISSUES=0
declare -i CHECKED=0

# Command line options:
declare -i OPT_VERBOSITY=0


# -------------------------------------------------------------------------
#       GENERIC FUNCTIONS REQUIRED FOR TESTING OF ASCIIDOC MODULES
# -------------------------------------------------------------------------

# Prints an error message to standard error output and terminates the
# script with a selected exit status.
#
# Usage: exit_with_error ERROR_MESSAGE [EXIT_STATUS]
function exit_with_error {
  local -r error_message=${1:-'An unexpected error has occurred.'}
  local -r exit_status=${2:-1}

  # Print the supplied message to standard error output:
  echo -e "$NAME: $error_message" >&2

  # Terminate the script with the selected exit status:
  exit $exit_status
}

# Prints a warning message to standard error output.
#
# Usage: warn WARNING_MESSAGE
function warn {
  local -r warning_message="$1"

  # Print the supplied message to standard error output:
  echo -e "$NAME: $warning_message" >&2
}

# Formats a test result message result and prints it to standard output.
#
# Usage: print_test_result STATUS EXPLANATION
function print_test_result {
  local -ru status="$1"
  local -r  explanation="$2"

  # Format the message and print it to standard output:
  printf "%-15s %s\n" "  [ $status ]" "$explanation"
}

# Records a test as passed and prints a related message to standard output.
#
# Usage: pass EXPLANATION
function pass {
  local -r explanation="$1"

  # Update the counter:
  (( CHECKED++ ))

  # Report a successfully passed test:
  [[ "$OPT_VERBOSITY" -gt 0 ]] && print_test_result "pass" "$explanation"
}

# Records a test as failed and prints a related message to standard output.
#
# Usage: fail EXPLANATION
function fail {
  local -r explanation="$1"

  # Update the counters:
  (( CHECKED++ ))
  (( ISSUES++ ))

  # Raport a failed test:
  print_test_result "fail" "$explanation"
}

# Reads an AsciiDoc file, removes unwanted content such as comments from
# it, and prints the result to standard output.
#
# Usage: print_adoc FILE
function print_adoc {
  local -r filename="$1"

  # Remove both single-line and multi-line comments from the supplied file:
  perl -0pe 's{^////\s*\n.*?^////\s*\n}{}msg;s{^//\s.*\n}{}gm;' "$filename"
}

# Processes the supplied AsciiDoc file and reports problems to standard
# output.
#
# Usage: print_report FILE
function print_report {
  local -r filename="$1"

  # Extract the base file name, without the full path:
  local -r basename=${filename##*/}

  # Print the header:
  echo -e "Testing file: $(realpath $filename)\n"

  # Try to deduce what the AsciiDoc file is from its file name and run
  # dedicated test cases for that documentation type:
  if [[ "$basename" = 'master.adoc' ]]; then
    # Run test cases for master.adoc
    test_context "$filename"
  else
    # Run test cases for modules and assemblies:
    test_module_prefix "$filename"
  fi

  # Print the summary:
  echo -e "\nChecked $CHECKED item(s), found $ISSUES problem(s)."
}


# -------------------------------------------------------------------------
#                TEST CASES AND FUNCTIONS RELATED TO THEM
# -------------------------------------------------------------------------

# Deduces the documentation type from the file name and prints the result
# to standard output. If the documentation type cannot be determined,
# prints 'unknown'.
#
# Usage: detect_type FILE
function detect_type {
  local -r filename="${1##*/}"

  # Analyze the file name:
  case "$filename" in
    con_*) echo 'concept';;
    ref_*) echo 'reference';;
    proc_*) echo 'procedure';;
    assembly_*) echo 'assembly';;
    *) echo 'unknown';;
  esac
}

# Verifies that modules and assemblies follow prescribed naming conventions
# and use one of the following prefixes to signify their type:
#
#   con_      - a concept module
#   ref_      - a reference module
#   proc_     - a procedure module
#   assembly_ - an assembly
#
# Usage: test_module_prefix FILE
function test_module_prefix {
  local -r filename="$1"

  # Deduce the documentation type from the file name:
  local -r type=$(detect_type "$filename")

  # Check if the type could be deduced and report the result:
  if [[ "$type" != 'unknown' ]]; then
    pass "Found correct prefix to identify the file as '$type'."
  else
    fail "Missing prefix con_, ref_, proc_, or assembly_ in the file name."
  fi
}

# Verifies that the AsciiDoc file sets the value of the 'context' attribute
# to a non-empty string.
#
# Usage: test_context FILE
function test_context {
  local -r filename="$1"

  # Check if the file contains the attribute definition:
  if grep -qP '^:context:\s*\S+' "$filename"; then
    pass "The 'context' attribute is set to a non-empty string."
  else
    fail "Missing definition of the 'context' attribute."
  fi

}

# -------------------------------------------------------------------------
#                               MAIN SCRIPT
# -------------------------------------------------------------------------

# Process command-line options:
while getopts ':hvV' OPTION; do
  case "$OPTION" in
    h)
      # Print usage information to standard output:
      echo "Usage: $NAME [-v] FILE"
      echo -e "       $NAME -hV\n"
      echo '  -v           include successful test results in the report'
      echo '  -h           display this help and exit'
      echo '  -V           display version and exit'

      # Terminate the script:
      exit 0
      ;;
    v)
      # Increase the verbosity level:
      OPT_VERBOSITY=1
      ;;
    V)
      # Print version information to standard output:
      echo "$NAME $VERSION"

      # Terminate the script:
      exit 0
      ;;
    *)
      # Report invalid option and terminate the script:
      exit_with_error "Invalid option -- '$OPTARG'" 22
      ;;
  esac
done

# Shift positional parameters:
shift $(($OPTIND - 1))

# Verify the number of command line arguments:
[[ "$#" -eq 1 ]] || exit_with_error 'Invalid number of arguments' 22

# Get the name of the AsciiDoc file:
declare -r file="$1"

# Verify that the supplied file exists and is readable:
[[ -e "$file" ]] || exit_with_error "$file: No such file or directory" 2
[[ -r "$file" ]] || exit_with_error "$file: Permission denied" 13
[[ -f "$file" ]] || exit_with_error "$file: Not a file" 21

# Process the file and print the report:
print_report "$file"

# Terminate the script:
[[ "$ISSUES" -eq 0 ]] && exit 0 || exit 1
