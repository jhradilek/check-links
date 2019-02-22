#!/bin/bash

# check-db-links.sh - list broken external links in a DocBook XML file
# Copyright (C) 2013, 2014 Jaromir Hradilek <jhradilek@gmail.com>

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

# Default options:
OPT_ALL=0
OPT_LIST=0
OPT_PARALLEL=0
OPT_XINCLUDE=0

# Color settings:
CLR_FAILED=
CLR_IGNORED=
CLR_PASSED=
CLR_RESET=

# Prints an error message to standard error output and terminates the
# script with a selected exit status.
#
# Usage: exit_with_error ERROR_MESSAGE [EXIT_STATUS]
function exit_with_error {
  local error_message=${1:-'An unexpected error has occurred.'}
  local exit_status=${2:-1}

  # Print the given message to standard error output:
  echo -e "$NAME: $error_message" >&2

  # Terminate the script with the given exit status:
  exit $exit_status
}

# Prints usage information to standard output.
#
# Usage: print_usage
function print_usage {
  echo "Usage: $NAME [-acip] FILE"
  echo "       $NAME [-i] -l FILE"
  echo
  echo '  -a           print the status of all links'
  echo '  -c           enable colored output'
  echo '  -i           perform XInclude processing'
  echo '  -l           list all links without checking their status'
  echo '  -p           check links in parallel'
  echo '  -h           display this help and exit'
}

# Determines whether an external link is functional and prints the result
# to standard output.
#
# Usage: print_link_status LINK
function print_link_status {
  local link="$1"
  local status=0

  # Make sure the link is not empty:
  [[ -z "$link" ]] && return

  # Check whether the link is broken:
  if [[ "$link" =~ ^mailto: ]] || \
     [[ "$link" =~ ^file:/// ]] || \
     [[ "$link" =~ ^[a-z]+://(localhost|127\.0\.0\.1) ]]; then
    # Mark the link as ignored:
    status=2
  elif [[ "$link" =~ ^[a-z]+:// ]] && check_link "$link"; then
    # Mark the link as functional:
    status=1
  fi

  # Check the status of the link:
  if [[ "$status" -eq 0 ]]; then
    # Report a broken link:
    echo "${CLR_FAILED}FAILED:${CLR_RESET} $link"
  elif [[ "$status" -eq 1 ]]; then
    # Report a functional link:
    [[ "$OPT_ALL" -ne 0 ]] && echo "${CLR_PASSED}PASSED:${CLR_RESET} $link"
  else
    # Report an ignored link:
    [[ "$OPT_ALL" -ne 0 ]] && echo "${CLR_IGNORED}IGNORED:${CLR_RESET} $link"
  fi
}

# Locates external links in a DocBook XML file and prints their list to
# standard output.
#
# Usage: print_links FILE
function print_links {
  local file="$1"

  # Check whether XInclude processing is enabled:
  if [[ "$OPT_XINCLUDE" -ne 0 ]]; then
    # Locate the links:
    xmllint --xinclude --postvalid "$file" 2>/dev/null | \
    xmlstarlet sel -t -v '//ulink/@url' 2>/dev/null | \
    sort -u | sed '/^$/d'
  else
    # Locate the links:
    xmlstarlet sel -t -v '//ulink/@url' "$file" 2>/dev/null | \
    sort -u | sed '/^$/d'
  fi
}

# Determines whether an external link is functional. If the link is valid,
# returns 0, otherwise returns a non-zero value.
#
# Usage: check_link LINK
function check_link {
  local link="$1"

  # Check the link:
  curl -A 'Mozilla/5.0 (X11; Linux x86_64; rv:28:0) Gecko/20100101 Firefox/28.0' \
       --connect-timeout 5 --retry 3 \
       -4ILfks "$link" &>/dev/null
}

# Process command-line options:
while getopts ':achilp' OPTION; do
  case "$OPTION" in
    a)
      # Enable listing of all links:
      OPT_ALL=1
      ;;
    c)
      # Enable colored output:
      bold=$(tput bold)
      CLR_IGNORED="$bold$(tput setaf 3)"
      CLR_FAILED="$bold$(tput setaf 1)"
      CLR_PASSED="$bold$(tput setaf 2)"
      CLR_RESET=$(tput sgr0)
      ;;
    h)
      # Print usage information to standard output:
      print_usage

      # Terminate the script:
      exit 0
      ;;
    i)
      # Enable XInclude processing:
      OPT_XINCLUDE=1
      ;;
    l)
      # Enable listing of links without checking their status:
      OPT_LIST=1
      ;;
    p)
      # Enable parallel processing:
      OPT_PARALLEL=1
      ;;
    *)
      # Report an error and terminate the script:
      exit_with_error "Invalid option -- '$OPTARG'" 22
      ;;
  esac
done

# Shift positional parameters:
shift $(($OPTIND - 1))

# Verify the number of command line arguments:
[[ "$#" -eq 1 ]] || exit_with_error 'Invalid number of arguments' 22

# Get the name of the XML file:
file="$1"

# Verify that the file exists:
[[ -e "$file" ]] || exit_with_error "$file: No such file or directory" 2
[[ -r "$file" ]] || exit_with_error "$file: Permission denied" 13
[[ -f "$file" ]] || exit_with_error "$file: Not a file" 21

# Verify that all required utilities are in the system:
for dependency in curl xmllint xmlstarlet; do
  if ! type "$dependency" &>/dev/null; then
    exit_with_error "Missing dependency -- '$dependency'" 1
  fi
done

# Check which action to perform:
if [[ "$OPT_LIST" -ne 0 ]]; then
  # Locate all external links and print them to standard output:
  print_links "$file"
elif [[ "$OPT_PARALLEL" -ne 0 ]]; then
  # Export required functions and variables:
  export -f print_link_status check_link
  export OPT_ALL CLR_IGNORED CLR_FAILED CLR_PASSED CLR_RESET

  # Check the status of all external links and print it to standard output:
  print_links "$file" | xargs -n 1 -P 0 bash -c 'print_link_status "$@"' --
else
  # Check the status of all external links and print it to standard output:
  print_links "$file" | while read -r link; do
    print_link_status "$link"
  done
fi

# Terminate the script:
exit 0

:<<-=cut

=head1 NAME

check-db-links - list broken external links in a DocBook XML file

=head1 SYNOPSIS

B<check-db-links> [B<-acips>] I<file>

B<check-db-links> [B<-i>] B<-l> I<file>

B<check-db-links> B<-h>

=head1 DESCRIPTION

The B<check-db-links> utility reads a DocBook XML file, locates all
external links and prints a list of those that are no longer functional to
standard output. In addition, it can be used to print all external links in
the selected file without checking their status, or configured to perform
XInclude processing.

By default, the B<check-db-links> utility treats external links as follows:

=over

=item *

If the external link is functional, the utility does not produce any output
and proceeds to check the next link in the queue.

=item *

If the external link is not functional, the utility prints the keyword
B<FAILED> followed by the URL.

=back

To change this behavior, use one or more of the command-line options listed
below.

=head1 OPTIONS

=over

=item B<-a>

Prints the current status of all external links, that is, B<PASSED> for
links that are functional, B<FAILED> for links that appear to be broken,
and B<IGNORED> for links that are explicitly ignored (typically email
addresses). By default, the B<check-db-links> utility prints only broken
links.

=item B<-c>

Enables colored output.

=item B<-i>

Performs XInclude processing. By default, the B<check-db-links> utility
checks only those links that are present in the selected file. With this
option, the utility also checks links in files that are included in the
selected file by using the B<E<lt>xi:includeE<gt>> statement.

=item B<-l>

Lists all external links in the selected file without checking their status.
This option can be used in conjunction with the B<-i> option.

=item B<-p>

Checks the current status of external links in parallel. By default, the
B<check-db-links> utility checks external links one at a time.

=item B<-h>

Displays usage information and exits.

=back

=head1 EXAMPLES

=over

=item *

To list all broken links in a selected DocBook XML file, type the following
at a shell prompt:

    check-db-links FILE

=item *

To list all links in a selected DocBook XML file along with their current
status (B<PASSED>, B<FAILED>, or B<IGNORED>), run the following command:

    check-db-links -a FILE

=item *

To list all links in a selected DocBook XML file without checking their
status, type:

    check-db-links -l FILE

=item *

To list all broken links in a selected DocBook XML file and all files that
are included in it using the B<E<lt>xi:includeE<gt>> statement, run:

    check-db-links -i FILE

=back

=head1 SEE ALSO

B<curl>(1), B<xmllint>(1), B<xmlstarlet>(1)

=head1 BUGS

To report a bug or submit a patch, please, send an email to
E<lt>jhradilek@gmail.comE<gt>.

=head1 COPYRIGHT

Copyright (C) 2013, 2014 Jaromir Hradilek E<lt>jhradilek@gmail.comE<gt>

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
