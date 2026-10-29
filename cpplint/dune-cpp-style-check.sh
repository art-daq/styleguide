#!/bin/env bash

HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

if [[ "$#" != "2" ]]; then

cat<<EOF >&2

    Usage: $(basename $0) <directory containing the compile_commands.json file for your build> <file or directory to examine>

Given a file, it will apply two linters to that file:

-dunecpplint.sh, which calls dunecpplint.py, a DUNE version of Google's cpplint.py
-duneclang-tidy.sh, which wraps clang-tidy (if the file is a sourcefile and not a header)

Given a directory, it will apply these linters to all the source
(*.cpp, *.cxx) and header (*.hpp) (if applicable) files in that directory as
well as all of its subdirectories.


compile_commands.json is a file which this script needs to forward to
clang-tidy. It can be automatically produced in a cmake build; to get
cmake to do this, add the following line to your CMakeLists.txt file:

set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Set to ON to produce a compile_commands.json file which clang-tidy can use" FORCE)

More detail can be found in
https://cmake.org/cmake/help/v3.5/variable/CMAKE_EXPORT_COMPILE_COMMANDS.html

EOF

    exit 1
fi

compile_commands_dir=$1

# May also want to add logic making sure compile_commands.json is up-to-date

if [[ ! -e $compile_commands_dir ]]; then

    cat<<EOF >&2

Directory meant to provide compile_commands.json file,
"$compile_commands_dir", doesn't appear to exist; exiting...

EOF
    exit 3
elif [[ ! -d $compile_commands_dir ]]; then

    cat<<EOF >&2

"$compile_commands_dir" appears to be a file; all this script needs is
the directory which contains compile_commands.json. Exiting...

EOF

    exit 4

elif [[ ! -f $compile_commands_dir/compile_commands.json ]]; then

cat<<EOF >&2

Expected file "compile_commands.json" not found in provided directory,
$compile_commands_dir; exiting...

JCF, May-26-2022: in order for the nightly build to work, for the time
being this will result in an exit value of 0 rather than 5 (i.e. "success")

EOF
#exit 5
exit 0
fi


filename=$2

files=""

if [[ -d $filename ]]; then
    files=$( find $filename -name "*.cc" )" "$( find $filename -name "*.cpp" )" "$( find $filename -name "*.hh" )" "$( find $filename -name "*.h" )
elif [[ -f $filename ]]; then

    if [[ "$filename" =~ ^.*cc$ || "$filename" =~ ^.*cpp$ || "$filename" =~ ^.*hh$ || "$filename" =~ ^.*h$ ]]; then
	files=$filename
    else
	echo "Filename $(basename $filename) has unknown extension; exiting..." >&2
	exit 1
    fi

else
    echo "Unable to find $filename; exiting..." >&2
    exit 2
fi

files=$( echo $files | tr " " "\n" | sort | tr "\n" " " )
DIR="$(dirname "$(readlink -f "$0")")"

max_jobs=${DUNE_STYLE_CHECK_JOBS:-$(nproc 2>/dev/null || echo 4)}
if [[ ! "$max_jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "DUNE_STYLE_CHECK_JOBS must be a positive integer; got \"$max_jobs\"" >&2
    exit 1
fi
outdir=$(mktemp -d)
trap 'rm -rf "$outdir"' EXIT

check_file() {
    local file=$1 out=$2
    {
        $DIR/dunecpplint.sh $file

        if [[ "$file" =~ .*cc$ || "$file" =~ .*cpp$ ]]; then
            $DIR/duneclang-tidy.sh $compile_commands_dir $file
        fi
    } > "$out" 2>&1
}

# Files that produced no output are recorded, with their modification time, in
# a cache file next to compile_commands.json so unchanged files are skipped on
# later runs. Delete the file to force a full re-check.
passed_file=$compile_commands_dir/dune-cpp-style-check.passed
declare -A passed
if [[ -f $passed_file ]]; then
    while read -r mtime cached; do
        passed[$cached]=$mtime
    done < "$passed_file"
fi

to_check=""
for file in $files ; do
    key=$(readlink -f $file)
    if [[ "${passed[$key]}" != "$(stat -c %Y $file)" ]]; then
        to_check="$to_check $file"
    fi
done
skipped=$(( $(echo $files | wc -w) - $(echo $to_check | wc -w) ))
files=$to_check

# Each file's output goes to its own buffer so it can be printed collated,
# in sorted file order, once all jobs are done
total=0
for file in $files ; do
    total=$((total + 1))
done

processed=0
report_progress() {
    local remaining=$((total - processed))
    if [[ -t 2 ]]; then
        printf '\r%s: Processed %d of %d files; %d remaining' "$filename" "$processed" "$total" "$remaining" >&2
    else
        printf '%s: Processed %d of %d files; %d remaining\n' "$filename" "$processed" "$total" "$remaining" >&2
    fi
}

i=0
for file in $files ; do
    check_file $file "$outdir/$i.out" &
    i=$((i + 1))
    while (( $(jobs -rp | wc -l) >= max_jobs )); do
        wait -n || true
        processed=$((processed + 1))
        report_progress
    done
done
while (( $(jobs -rp | wc -l) > 0 )); do
    wait -n || true
    processed=$((processed + 1))
    report_progress
done

if [[ -t 2 ]]; then
    printf '\r\033[K' >&2
fi

i=0
for file in $files ; do
    key=$(readlink -f $file)
    if [[ -s "$outdir/$i.out" ]]; then
        cat "$outdir/$i.out"
        unset "passed[$key]"
    else
        passed[$key]=$(stat -c %Y $file)
    fi
    i=$((i + 1))
done

for key in "${!passed[@]}"; do
    echo "${passed[$key]} $key"
done | sort -k2 > "$passed_file" 2>/dev/null

if (( skipped > 0 )); then
    echo "$filename: Skipped $skipped previously passed unchanged file(s); see $passed_file" >&2
fi


exit 0
