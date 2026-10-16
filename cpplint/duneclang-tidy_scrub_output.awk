BEGIN {

    RS="^"

    in_boost_lint=0

    work_area_dir=ENVIRON["DBT_AREA_ROOT"]
}


{
    # Get rid of complaints about external headers
    if ($0 ~ /\n[[:space:]~]*\/cvmfs\/.*opensciencegrid.org/) {
       next
    }
    if ($0 ~ /\n[[:space:]~]*\/.*\/spack\/opt\/spack\//) {
       next
    }
    if ($0 ~ /\n[[:space:]~]*\/.*\/\.spack-env\/view\//) {
       next
    }

    # Ignore default implementation messages
    if ($0 ~ /warning: Using default implementation of/) {
        next
    }

    # Don't complain about TLVL_** defines
    if ($0 ~ /TLVL_/) {
       next
    }

    # Get rid of complainst about BOOST expansions
    if ($0 ~ /Calling.*test_method/) {
	    in_boost_lint=1
        next
    }

    if (in_boost_lint == 1 || in_serialization_lint == 1) {
        if ($0 ~ /note:/) {
            next
        }
    }
    in_boost_lint = 0

    # Also ignore bad things that happen in exception tests
    if ($0 ~ /BOOST_.*_EXCEPTION/) {
        next
    }

    # Users don't need to know about low-level clang-tidy details
    if ($0 ~ /Use -system-headers to display errors from system headers as well/) {
	next
    }

    if ($0 ~ /TRACE_NAME/) {
        next
    }

    if ($0 ~ /xpanded from here[[:space:]~:]*\/cvmfs/) {
	next
    }

    if ($0 ~ /note:.*requested here/) {  # Possibly too draconian
	next
    }

    if ($0 ~ /compiler\/gcc\/compilerSpecific\.h is not for use with the clang compiler/) { # Ignore issue from cadef.h
    next
    }

    # Catch instances of external header errors where the awk record includes the opening blurb

    if ($0 ~ /Error while processing/ && $0 ~ /\/cvmfs/) {
	next
    }

    # JCF, May-27-2022: a frequent idiom is to use bind to register a
    # member function as a callback (with "this" as the bound
    # variable); this strikes me as easier for both the programmer and
    # the reader than the lambda function clang-tidy recommends

    if ($0 ~ /\[modernize-avoid-bind\].*,[[:space:]]*this[[:space:]]*(?:,|\))/ ) {
	next
    }
    if ($0 ~ /\[modernize-avoid-bind\].*boost::thread/ ) {
	next
    }

    # JCF, May-27-2022: clang-tidy's good at catching situations where
    # using auto would be helpful, but we don't want it to complain if
    # someone skipped auto to make it clear what the type passed to a
    # templated function is. For example,
    # serialization::deserialize<trigger_record_ptr_t>(trigger_record_bytes);

    if ($0 ~ /\[modernize-use-auto\].*[[:alnum:]]+<[[:alnum:]]+>\(/ ) {
	next
    }

    # Don't have header linting repeated
    match($0, /[[:alnum:]]+.h[px][px]:[0-9]+:[0-9]+/)

    repeat = 0
    if (RLENGTH != -1) {
      header_line_and_loc = substr($0, RSTART, RLENGTH)
      if (header_line_and_loc in header_complaints) {
	  next
      }
      header_complaints[header_line_and_loc] = 1
    }

    pos = index($0, work_area_dir)
    if (pos > 0) {
	$0 = substr($0, pos + length(work_area_dir) + 1)  # + 1 to shave off starting "/"
    }

    print
}
