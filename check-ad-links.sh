#!/bin/bash

# check-ad-links.sh - list broken external links in an AsciiDoc file
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

# General information about the script:
NAME=${0##*/}

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

# Determines whether an external link is functional. If the target URL is
# accessible, the function returns 0, otherwise it returns a non-zero
# value.
#
# Usage: check_link URL
function check_link {
  local -r url="$1"

  # Verify whether the supplied link is accessible:
  curl -A 'Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' \
       --connect-timeout 5 --retry 3 \
       -4ILfks "$url" &>/dev/null
}

# Removes comments from an AsciiDoc file and prints the result to standard
# output.
#
# Usage: print_adoc FILE
function print_adoc {
  local -r filename="$1"

  # Remove both single-line and multi-line comments from the supplied file:
  perl -0pe 's{^////\s*\n.*?^////\s*\n}{}msg;s{^//\s.*\n}{}gm;' "$filename"
}

# Locates external links in an AsciiDoc file and prints them on individual
# lines to standard output:
function print_links {
  local -r filename="$1"

  # Read the AsciiDoc file and isolate external links:
  print_adoc "$filename" | \
    sed -ne 's|.*\(https\?://[^ \t[]\+\).*|\1|p' | \
    grep -ve '//\(localhost\|127\.0\.0\.1\|::1\)/\?' | \
    grep -ve '//example\.\(com\|org\|net\|edu\)/\?'
}

# Determines whether an external link is functional and prints the result
# to standard output.
#
# Usage: print_link_status LINK
function print_link_status {
  local -r url="$1"

  # Ignore empty URLs:
  [[ -z "$url" ]] && return

  # Check whether the supplied link is functional:
  if ! check_link "$url"; then
    echo "$url"
  fi
}

# Verify the status of all external links and print all broken links to
# standard output:
export -f print_link_status check_link
print_links "$1" | xargs -n 1 -P 0 bash -c 'print_link_status "$@"' --

# Terminate the script:
exit 0
