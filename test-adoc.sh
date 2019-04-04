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
  printf "  %-10s %s\n" "[ $status ]" "$explanation"
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

# Deduces the documentat type from the file name and prints the result to
# standard output. If the document type cannot be determined, prints
# 'unknown'.
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
    master.adoc) echo 'master';;
    *attributes.adoc) echo 'attributes';;
    *) echo 'unknown';;
  esac
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

  # Determine the document type:
  local -r type=$(detect_type "$filename")

  # Print the header:
  echo -e "Testing file: $(realpath $filename)\n"
  echo -e "  Document type: $type\n"

  # Run test cases depending on the detected document type. If the document
  # type could not be determined, treat the file just like a module or
  # assembly:
  if [[ "$type" == 'attributes' ]]; then
    # Do nothing with attribute definition files:
    :
  elif [[ "$type" == 'master' ]]; then
    # Run test cases for master.adoc:
    test_context_definition "$filename"
  else
    # Run test cases for modules and assemblies:
    test_module_prefix "$filename"
    test_steps_in_proc "$filename"
    test_context_in_ids "$filename"
  fi

  # Print the summary:
  echo -e "\nChecked $CHECKED item(s), found $ISSUES problem(s)."
}


# -------------------------------------------------------------------------
#                TEST CASES AND FUNCTIONS RELATED TO THEM
# -------------------------------------------------------------------------

# Parses the AsciiDoc file and prints all IDs to standard output.
#
# Usage: list_ids FILE
function list_ids {
  local -r filename="$1"

  # Parse IDs:
  print_adoc "$filename" | sed -ne "s/^\[id=['\"]\(.*\)['\"]\].*/\1/p"
}

# Parses the AsciiDoc file and determines whether it contains any steps.
#
# Usage: has_steps FILE
function has_steps {
  local -r filename=$1

  # Parse steps:
  print_adoc "$filename" | grep -qP '^\.+\s+\S+'
}

# Verifies that the AsciiDoc file sets the value of the 'context' attribute
# to a non-empty string.
#
# Usage: test_context_definition FILE
function test_context_definition {
  local -r filename="$1"

  # Check if the file contains the attribute definition and report the
  # result:
  if grep -qP '^:context:\s*\S+' "$filename"; then
    pass "The 'context' attribute is set to a non-empty string."
  else
    fail "The 'context' attribute is not set to a non-empty string."
  fi
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
    pass "The file name uses a prefix to identify itself as '$type'."
  else
    fail "The file name does not use the con_, ref_, proc_, or assembly_ prefix."
  fi
}

# Verifies that a procedure module contains at least one step.
#
# Usage: test_steps_in_proc FILE
function test_steps_in_proc {
  local -r filename="$1"

  # Determine the document type:
  local -r type=$(detect_type "$filename")

  # Check if the document type is procedure, otherwise do nothing:
  if [[ "$type" == 'procedure' ]]; then
    # Check if the file contains at least one step:
    if has_steps "$filename"; then
      pass "The procedure module contains at least one step."
    else
      fail "The procedure module does not contain any steps."
    fi
  fi
}

# Verifies that all IDs have the 'context' attribute in them to remain
# reusable in different assemblies.
#
# Usage: test_context_in_ids FILE
function test_context_in_ids {
  local -r filename="$1"

  # Locate all IDs used in the AsciiDoc file:
  for unique_id in $(list_ids "$filename"); do
    # Check if the ID contains the 'context' attribute and report the
    # result:
    if echo "$unique_id" | grep -q '{context}'; then
      pass "The '$unique_id' ID includes the 'context' attribute."
    else
      fail "The '$unique_id' ID does not include the 'context' attribute."
    fi
  done
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

# Verify that the supplied file is an AsciiDoc file:
[[ "${file##*.}" == 'adoc' ]] || exit_with_error "$file: Not an AsciiDoc file" 22

# Verify that the supplied file exists and is readable:
[[ -e "$file" ]] || exit_with_error "$file: No such file or directory" 2
[[ -r "$file" ]] || exit_with_error "$file: Permission denied" 13
[[ -f "$file" ]] || exit_with_error "$file: Not a file" 21

# Process the file and print the report:
print_report "$file"

# Terminate the script:
[[ "$ISSUES" -eq 0 ]] && exit 0 || exit 1
