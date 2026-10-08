#!/bin/bash

if [[ "$#" != "1" ]]; then
    echo "Usage: "$(basename $0)" <file or directory to examine>" >&2
    echo
    cat <<EOF >&2

The DUNE C++ style guide this script tries to look for violations of can be found in
https://github.com/DUNE-DAQ/styleguide/blob/dune-daq-cppguide/dune-daq-cppguide.md

Given a file, it will apply a linter (dunecpplint.py) to that file

Given a directory, it will apply dunecpplint.py to all the source
(*.cxx, *.cpp) and header (*.hpp) files in that directory as well as all of its
subdirectories.

EOF

    exit 1
fi

filename=$1

# -build/c++11/14 : No headers are explicitly disallowed

# -build/explicit_make_pair : related to a bug in g++ 4.6 where it couldn't handle explicit template arguments in make pair; no longer relevant

# -build/namespaces: for source (not header) files, allow using-directives

# -runtime/indentation_namespace: worry about whitespace with our formatting tools

# -readability/check: described in cpplint.py as "Checks the use of
# -CHECK and EXPECT macros" - i.e., DUNE doesn't need it as we don't
# -use those

# -readability/constructors: refers to unused Google macros

# -runtime/references: DUNE doesn't require that function arguments
#  which can be altered need to be pointers

# -runtime/string: DUNE doesn't require that static/global variables
#  be trivially destructible

# -runtime/vlog: refers to Google-specific VLOG function

# -whitespace: worry about this with our formatting tools

# -build/unsigned Artdaq assumes that you know what you are doing with unsigned variables


header_filters="-build/c++11,-build/c++14,-readability/check,-readability/constructors,-runtime/indentation_namespace,-runtime/references,-runtime/string,-runtime/vlog,-whitespace,-build/explicit_make_pair,-build/unsigned"
source_filters="-build/c++11,-build/c++14,-build/namespaces,-readability/check,-readability/constructors,-runtime/indentation_namespace,-runtime/references,-runtime/string,-runtime/vlog,-whitespace,-build/explicit_make_pair,-build/unsigned"

dev_filters=""
#dev_filters=",-build/include_order,-build/include_what_you_use,-legal/copyright,-build/header_guard,-build/define_used,-readability/namespace,-runtime/output_format"

header_files=""
source_files=""

if [[ -d $filename ]]; then
    header_files=$( find $filename -name "*.hh" )" "$( find $filename -name "*.h" )" "$( find $filename -name "*.hpp" )
    source_files=$( find $filename -name "*.cc" )" "$( find $filename -name "*.cpp" )" "$( find $filename -name "*.cxx" )
elif [[ -f $filename ]]; then

    if [[ "$filename" =~ ^.*cc$ || "$filename" =~ ^.*cpp$ || "$filename" =~ ^.*cxx$ ]]; then
	source_files=$filename
    elif [[ "$filename" =~ ^.*hh$ || "$filename" =~ ^.*h$ || "$filename" =~ ^.*hpp$ ]]; then
	header_files=$filename
    else
	echo "Filename $(basename $filename) has unknown extension; exiting..." >&2
	exit 1
    fi

else
    echo "Unable to find $filename; exiting..." >&2
    exit 2
fi

function is_file_excluded() {
    path_to_check=$1
    filename=$2
    if [[ "$path_to_check" == "/" || "$path_to_check" == "." ]]; then
        return 0
    fi
    if [[ -f $path_to_check/.clang_tidy_exclude ]]; then
        relpath=$(realpath --relative-to=$path_to_check $filename)
        if grep -q "^$relpath$" $path_to_check/.clang_tidy_exclude; then
            return 1
        fi
        return 0
    else
        is_file_excluded $(dirname $path_to_check) $filename
        return $?
    fi
}

for header_file in $header_files; do
    is_file_excluded $(dirname $header_file) $header_file
    if [ $? -eq 1 ]; then
        #echo "Skipping excluded header file: $header_file"
        continue
    fi
    if [ -L $header_file ]; then
        #echo "Skipping symlink header file: $header_file"
        continue
    fi
    $( dirname $0 )/dunecpplint.py --quiet --extensions=h,hpp,hh,cc,cpp,cxx --headers=hh,hpp,h --filter=${header_filters}${dev_filters} $header_file

done

for source_file in $source_files; do
    is_file_excluded $(dirname $source_file) $source_file
    if [ $? -eq 1 ]; then
        #echo "Skipping excluded source file: $source_file"
        continue
    fi
    if [ -L $source_file ]; then
        #echo "Skipping symlink source file: $source_file"
        continue
    fi
    $( dirname $0 )/dunecpplint.py --quiet --extensions=h,hpp,hh,cc,cpp,cxx --headers=hh,hpp,h --filter=${source_filters}${dev_filters} $source_file

done
