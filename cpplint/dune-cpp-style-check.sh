#!/bin/env bash

HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

if [[ "$#" != "2" ]]; then

cat<<EOF >&2

    Usage: $(basename $0) <directory containing the compile_commands.json file for your build> <file or directory to examine> <exclude regex>

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
    files=$( find $filename -name "*.cc" )" "$( find $filename -name "*.cpp" )" "$( find $filename -name "*.hh" )
elif [[ -f $filename ]]; then

    if [[ "$filename" =~ ^.*cc$ || "$filename" =~ ^.*cpp$ || "$filename" =~ ^.*hh$ ]]; then
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

for file in $files ; do

     $DIR/dunecpplint.sh $file

     if [[ "$file" =~ .*cc$ || "$file" =~ .*cpp$ ]]; then
	 $DIR/duneclang-tidy.sh $compile_commands_dir $file
     fi

done


exit 0
