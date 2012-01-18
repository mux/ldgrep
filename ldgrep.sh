#!/bin/sh
# vim:ts=4

PKGDB="/var/db/pkg"
PREFIX="/usr/local"

# A typical use of this tool (simplified by not using the -I % parameter to
# xargs(1) to properly cope with potential whitespace in filenames).
#
#   ldgrep <pattern> | sort -u | xargs -n1 pkg_info -qW | xargs portmaster

print_usage()
{
	echo "usage: $0 [-Eh] [-d pkgdb] [-p prefix] [-L dir...] pattern"
}

add_lib_path()
{
	if [ -z "$LD_LIBRARY_PATH" ]; then
		LD_LIBRARY_PATH=$1
	else
		LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$1"
	fi
}

while getopts "EL:d:hp:" OPTION; do
case "$OPTION" in
	E) SED_OPTS="-E"
       ;;
	L) add_lib_path "$OPTARG"
	   ;;
	d) PKGDB=$OPTARG
	   ;;
	p) PREFIX=$OPTARG
	   ;;
	h) print_usage
	   exit
	   ;;
	*) print_usage
	   exit 1
	   ;;
esac
done

shift $(($OPTIND - 1))

if [ $# -ne 1 ]; then
	print_usage
	exit 1
fi
pattern=$1

# Add a few known directories that require to be in LD_LIBRARY_PATH.
add_lib_path "$PREFIX/lib/firefox"
export LD_LIBRARY_PATH

script=$(cat <<EOF
/:$/ {
  s/:$//
  h
  d
}
/ => /!d
s/^.*=> //
s/ (.*$//
/$pattern/!d
g
EOF
)

find "$PKGDB" -depth 2 -type f -name +CONTENTS -print0 |
    xargs -0 sed -n "/^[^@]/s#^#$PREFIX/#p" |
    xargs -I % ldd -a -- % 2>/dev/null |
    sed $SED_OPTS "$script" | uniq
