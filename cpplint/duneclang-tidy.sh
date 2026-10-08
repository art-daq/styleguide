#!/bin/env bash

HERE=$(cd $(dirname $(readlink -f ${BASH_SOURCE})) && pwd)

if [[ "$#" != "2" ]]; then

cat<<EOF >&2

    Usage: $(basename $0) <directory containing the compile_commands.json file for your build> <file or directory to examine>

Given a file, it will apply a linter (clang-tidy) to that file

Given a directory, it will apply clang-tidy to all the
source (*.cxx, *.cpp) and header (*.hpp) files in that directory as well as all
of its subdirectories.


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

EOF
    exit 5
fi


filename=$2

source_files=""

if [[ -d $filename ]]; then
    source_files=$( find $filename -name "*.cxx" )" "$( find $filename -name "*.cpp" )" "$( find $filename -name "*.cc" )
elif [[ -f $filename ]]; then

    if [[ "$filename" =~ ^.*cc$ || "$filename" =~ ^.*cpp$ || "$filename" =~ ^.*cxx$ ]]; then
	source_files=$filename
    elif [[ "$filename" =~ ^.*hh$ || "$filename" =~ ^.*h$ ]]; then
	echo $(basename $0)" can only accept source files, not header files; exiting..." >&2
	exit 1
    else
	echo "Filename $(basename $filename) has unknown extension; exiting..." >&2
	exit 1
    fi

else
    echo "Unable to find $filename; exiting..." >&2
    exit 2
fi

which clang-tidy > /dev/null 2>&1
retval=$?

if [[ "$retval" != "0" ]]; then
    echo "This script expects clang-tidy to be available in your PATH; exiting..." >&2
    exit 1
fi

# Some of the warnings/errors left out:

# misc-non-private-member-variables-in-classes: since clang-tidy
# bizarrely includes this complaint for structs

# modernize-use-default-member-init: we don't really have a
# policy on this - not forbidden, not encouraged, use your best
# judgement

# misc-no-recursion: recursive functions aren't prohibited, and can be
# useful (cf. the create_config_plot code in daqconf)

# cppcoreguidelines-special-member-functions: as this is overly picky
# ("if you explicitly define one of the five special member functions,
# you must define them all")

# performance-unnecessary-value-param: this *would* be useful, but
# tragically it appears _all the time_ when it comes to defining
# parameters for the ERS exception macro. For DUNE DAQ, then, this
# warning's cost outweighs its benefit.


musts="bugprone-assert-side-effect,\
bugprone-copy-constructor-init,\
bugprone-infinite-loop,\
bugprone-integer-division,\
bugprone-macro-parentheses,\
bugprone-macro-repeated-side-effects,\
bugprone-move-forwarding-reference,\
bugprone-multiple-statement-macro,\
bugprone-reserved-identifier,\
bugprone-sizeof-expression,\
bugprone-string-integer-assignment,\
bugprone-throw-keyword-missing,\
bugprone-undefined-memory-manipulation,\
bugprone-unhandled-self-assignment,\
bugprone-unused-raii,\
bugprone-unused-return-value,\
bugprone-use-after-move,\
cert-dcl58-cpp,\
cert-env33-c,\
cert-err34-c,\
cert-err58-cpp,\
cert-oop57-cpp,\
cppcoreguidelines-init-variables,\
cppcoreguidelines-interfaces-global-init,\
cppcoreguidelines-macro-usage,\
cppcoreguidelines-narrowing-conversions,\
cppcoreguidelines-no-malloc,\
cppcoreguidelines-pro-bounds-constant-array-index,\
cppcoreguidelines-pro-bounds-pointer-arithmetic,\
cppcoreguidelines-pro-type-const-cast,\
cppcoreguidelines-pro-type-cstyle-cast,\
cppcoreguidelines-pro-type-reinterpret-cast,\
cppcoreguidelines-pro-type-static-cast-downcast,\
cppcoreguidelines-slicing,\
#cppcoreguidelines-special-member-functions,\
fuchsia-trailing-return,\
fuchsia-virtual-inheritance,\
google-default-arguments,\
google-global-names-in-headers,\
misc-definitions-in-headers,\
misc-misplaced-const,\
misc-throw-by-value-catch-by-reference,\
misc-uniqueptr-reset-release,\
misc-unused-alias-decls,\
misc-unused-using-decls,\
modernize-avoid-bind,\
modernize-avoid-c-arrays,\
modernize-concat-nested-namespaces,\
modernize-deprecated-headers,\
modernize-deprecated-ios-base-aliases,\
modernize-shrink-to-fit,\
modernize-use-auto,\
modernize-use-bool-literals,\
modernize-use-nullptr,\
performance-for-range-copy,\
performance-implicit-conversion-in-loop,\
performance-inefficient-algorithm,\
performance-inefficient-string-concatenation,\
performance-inefficient-vector-operation,\
performance-move-const-arg,\
performance-move-constructor-init,\
performance-unnecessary-copy-initialization,\
readability-const-return-type,\
#readability-container-size-empty,\
readability-deleted-default,\
readability-redundant-access-specifiers,\
readability-redundant-control-flow,\
readability-redundant-preprocessor,\
readability-redundant-smartptr-get,\
readability-static-definition-in-anonymous-namespace,\
readability-uniqueptr-delete-release"


maybes="bugprone-dynamic-static-initializers,\
#bugprone-exception-escape,\
bugprone-fold-init-type,\
bugprone-forward-declaration-namespace,\
bugprone-forwarding-reference-overload,\
bugprone-incorrect-roundings,\
bugprone-misplaced-widening-cast,\
bugprone-parent-virtual-call,\
bugprone-spuriously-wake-up-functions,\
bugprone-suspicious-include,\
bugprone-suspicious-memset-usage,\
bugprone-too-small-loop-variable,\
bugprone-undelegated-constructor,\
cert-err60-cpp,\
cert-mem57-cpp,\
cert-msc50-cpp,\
cert-msc51-cpp,\
google-readability-casting,\
google-runtime-int,\
google-runtime-operator,\
hicpp-exception-baseclass,\
hicpp-multiway-paths-covered,\
misc-unconventional-assign-operator,\
modernize-make-shared,\
modernize-use-emplace,\
#modernize-use-nodiscard,\
modernize-use-uncaught-exceptions,\
performance-type-promotion-in-math-fn,\
readability-delete-null-pointer,\
readability-function-size,\
readability-identifier-naming,\
#readability-inconsistent-declaration-parameter-name,\
readability-isolate-declaration"


tmpdir=$( mktemp -d )

if [[ ! -d $tmpdir ]]; then
    cat<<EOF >&2

There was a problem creating a temporary directory in which to modify a copy of
$compile_commands_dir/compile_commands.json; exiting...

EOF

    exit 1
fi

cp $compile_commands_dir/compile_commands.json $tmpdir/

if [[ -e $tmpdir/compile_commands.json ]]; then

    # JCF, Apr-14-2020

    # If you see an include directory of the form
    # /../v3_2_1/../include, have clang-tidy ignore any headers in
    # those directories, the logic being that they probably aren't
    # headers the developer would modify (e.g., ups products)

    sed -r -i 's!\-I(\s*\S+/v[0-9]\S+/include)(\s+)!\-isystem\1\2!g' $tmpdir/compile_commands.json

else
    cat<<EOF >&2

Was able to create temporary directory $tmpdir but couldn't copy
$compile_commands_dir/compile_commands.json into it; exiting...

EOF

    exit 1
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

for source_file in $source_files; do
    is_file_excluded $(dirname $source_file) $source_file
    if [ $? -eq 1 ]; then
        #echo "Skipping excluded source file: $source_file"
        continue
    fi

    clang-tidy -extra-arg=-ferror-limit=0 -p=$tmpdir -checks=${musts},${maybes} -config="{CheckOptions: [{key: cppcoreguidelines-narrowing-conversions.IgnoreConversionFromTypes, value: unsigned;size_t;ptrdiff_t;size_type;difference_type}]}" -header-filter=.* $source_file |& awk -f $(dirname $0)/duneclang-tidy_scrub_output.awk

done

#echo "Deleting $tmpdir/compile_commands.json"
rm -f $tmpdir/compile_commands.json
rmdir $tmpdir

