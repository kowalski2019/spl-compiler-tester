#!/usr/bin/env bash

tmpdir=$(mktemp -d)
curr_dir=`pwd`

trap 'echo "removing directory $tmpdir ..." && rm -rf "${tmpdir}"' INT TERM

if [ ! -d "$curr_dir/eco32tools" ]; then
    echo "The 'eco32tools' directory does not exists"
    echo "Tester cannot continue bye!".
    exit 0
fi

if [ ! -d "$curr_dir/spl-testfiles" ]; then
    echo "The 'spl-testfiles' directory does not exits"
    echo "Tester cannot continue bye!"
    exit 0
fi


help(){

    cat <<EOF
Usage: ./run_tests.sh  OPTION...
Performs all tests according to the option passed with the reference machine and the user's machine, compares the 2 results and attests whether the user's compiler behaves as the reference does

Options:
  tokens            Phase 1: Scans for tokens and prints them.
  parse             Phase 2: Parses the stream of tokens to check for syntax errors.
  absyn             Phase 3: Creates an abstract syntax tree from the input tokens and prints it.
  tables            Phase 4a: Builds a symbol table and prints its entries.
  semant            Phase 4b: Performs the semantic analysis.
  vars              Phase 5: Allocates memory space for variables and prints the amount of allocated memory.
  codegen	    Phase 6: Generate assembly code
  build		    Build the user compiler
  --help            Show this help.
  --version         Show tester version
EOF
    exit 0
}

version() {
    echo "spl-compiler-tester version 1.0.0 (compiled Dec 01 2023)" && exit 0
}

# NOT TO BE RUN
echo "This script is no to be run. Please use 'run_tests.sh' instead!" && exit 0

build=false

for ((i = 1; i <= "$#"; i++)); do
    arg="${!i}"

    if [[ $arg = --* ]]; then
	case "$arg" in
	    "--help") help ;;
	    "--version") version ;;	
	esac

        #options="$options $arg"
    else
	case "$arg" in
	    "tokens") phase="--tokens" ;;
	    "parse") phase="--parse" ;;
            "absyn") phase="--absyn" ;;
            "tables") phase="--tables" ;;
            "semant") phase="--semant" ;;
            "vars") phase="--vars" ;;
	    "codegen") phase="--codegen" ;;
        esac

        [ $arg == "build" ] && build=true 
    fi
done

[ -z "$phase" ] && help

runtime_test_dir="$curr_dir/spl-testfiles/runtime_tests"
semant_test_dir="$curr_dir/spl-testfiles/semant_errors"
syntax_error_test_dir="$curr_dir/spl-testfiles/syntax_errors"
codegen_test_dir="$curr_dir/spl-testfiles/runtime_tests"

assembler="$curr_dir/eco32tools/compile_s.sh"

java_ref_path="$curr_dir/java_ref"
c_ref_path="$curr_dir/eco32tools/bin"

user_c_compiler_path="__user_c_compiler_path__"
user_java_compiler_path="__user_java_compiler_path__"

compiler_written_lang="__comp_lang__"

if [ $build == true ]; then
    echo "Build user code first ..."
    if [ $compiler_written_lang == "java" ]; then
        code_dir=`dirname $user_java_compiler_path`
        pushd $code_dir && mvn clean package && popd && echo "Code successfully compiled"
    else
        code_dir=`dirname $user_c_compiler_path`
    fi
fi

if [ "$phase" == "--tables" ]; then
    tests_dirs="$runtime_test_dir $semant_test_dir"
elif [ "$phase" == "--semant" ]; then
    tests_dirs="$runtime_test_dir $semant_test_dir"
elif [ "$phase" == "--parse" ]; then
    tests_dirs="$runtime_test_dir $syntax_error_test_dir"
else
  tests_dirs="$runtime_test_dir"
fi

tests_dirs_arr=($(echo $tests_dirs | tr ' ' '\n'))

echo "tests_dirs: $tests_dirs phase: $phase" | tee test_results.log

: '
execute cmd and return res and exit code 
'
compiler() {
    t_file="$1"
    t_file_without_extension=${t_file%.*}
    t_dir="$2"
    t_dir_base=`basename $t_dir`
    #echo "In Compiler $t_dir_base"
    res=""
    exit_code="0"

    prog_lang="$3"
    compiler_path="$4"
    filename_tail="$5"

    if [ "$phase" == "--codegen" ]; then
        # redirect to output_dir
        output_file="${tmpdir}/${t_file_without_extension}_${t_dir_base}_${filename_tail}.s"
        output_file_without_ext="${tmpdir}/${t_file_without_extension}_${t_dir_base}_${filename_tail}"

        # compiler the test file
        #echo "Compile ${t_dir}/${t_file} " | tee -a test_results.log
        if [ $prog_lang == "java" ]; then
            java -jar $compiler_path "${t_dir}/${t_file}" "$output_file"
        else
            $compiler_path "${t_dir}/${t_file}" "$output_file"
        fi

        # assemble to bin
        #echo "Assemble $output_file_without_ext " | tee -a test_results.log
        [ $? -eq 0 ] && $assembler "$output_file"

        # exec and return exit code
        [ $? -eq 0 ] && res=$(echo "1 2 3 4 5 6 7 8 9" | "${c_ref_path}/sim" -l "${output_file_without_ext}.bin" -x -s 1)
        exit_code="$?"


    else
        if [ $prog_lang == "java" ]; then
            res=$(java -jar "$compiler_path" "$phase" "$t_dir/$t_file" 2>&1)    
        else
            res=$("$compiler_path" "$phase" "$t_dir/$t_file" 2>&1)
        fi
        exit_code="$?"
    fi
    case $phase in
	--tables)
	    echo "$exit_code"
        ;;
	--semant)
	    echo "$exit_code"
	    ;;
	--codegen)
	    echo -e "$res \n $exit_code"
	    ;;
	*)
	    echo -e "$res"
	    ;;
    esac
  
}

run_user_java_compiler() {
    _res=`compiler $1 $2 "java" "$user_java_compiler_path/spl-0.1.jar" "user" `
    echo $_res
}

run_user_c_compiler() {
    _res=`compiler $1 $2 "c" $user_c_compiler_path/spl "user" `
    echo $_res
}

run_java_ref_compiler() {
    _res=`compiler $1 $2 "java" "$java_ref_path/spl-0.1.jar" "ref" `
    echo $_res
}

run_c_ref_compiler() {
    _res=`compiler $1 $2 "c" $c_ref_path/refspl "ref" `
    echo $_res
}


echo "YOUR TURN" | tee -a test_results.log
for test_dir in ${tests_dirs_arr[*]}; do
    test_dir_base=`basename $test_dir`
    tests=($(ls $test_dir | grep .*.spl))
    test_dir_without_path="${tests[*]}"
    for f in ${test_dir_without_path[*]}; do
	echo "$test_dir_base/$f"
    f_without_extension=${f%.*}
	if [ "$phase" == "--codegen" ] && [ "$f" == "lambda.spl" ]; then
	    echo "0" >"${tmpdir}/${f_without_extension}_${test_dir_base}_user"
	else
	    if [ "$compiler_written_lang" == "java" ]; then
		    tmp_user_res=$(run_user_java_compiler "$f" "$test_dir")
	    else
		    tmp_user_res=$(run_user_c_compiler "$f" "$test_dir")
	    fi
	    echo "$tmp_user_res" >"${tmpdir}/${f_without_extension}_${test_dir_base}_user"
	fi

    done
done


echo "REF TURN" | tee -a test_results.log
for test_dir in ${tests_dirs_arr[*]}; do
    test_dir_base=`basename $test_dir`
    tests=($(ls $test_dir | grep .*.spl))
    test_dir_without_path="${tests[*]}"
    for f in ${test_dir_without_path[*]}; do
	echo "$test_dir_base/$f"
    f_without_extension=${f%.*}
	if [ "$phase" == "--codegen" ] && [ "$f" == "lambda.spl" ]; then
	    echo "0" >"${tmpdir}/${f_without_extension}_${test_dir_base}_ref"
	else
	    tmp_ref_res=$(run_c_ref_compiler "$f" "$test_dir")
	    echo "$tmp_ref_res" >"${tmpdir}/${f_without_extension}_${test_dir_base}_ref"
	fi

    done
done


passed=0
nbr_test=0
for test_dir in ${tests_dirs_arr[*]}; do
    tests=($(ls $test_dir | grep .*.spl))
    test_dir_base=`basename $test_dir`
    test_dir_without_path="${tests[*]}"
    for f in ${test_dir_without_path[*]}; do
    f_without_extension=${f%.*}
	tmp_res=$(diff "${tmpdir}/${f_without_extension}_${test_dir_base}_user" "${tmpdir}/${f_without_extension}_${test_dir_base}_ref")
	if [ -z "$tmp_res" ]; then
	    echo "TEST: $test_dir_base/$f is fine" | tee -a test_results.log
	    passed=`expr $passed + 1`
	else
	    echo -e "TEST: $test_dir_base/$f is not fine \n $tmp_res " | tee -a test_results.log
	fi
	nbr_test=`expr $nbr_test + 1`
    done
done

echo -e "\n TMPDIR $tmpdir"

#echo "removing directory $tmpdir ..."
echo "removing directory $tmpdir ..." && rm -rf "${tmpdir}"

echo -e "\nFINAL RES FOR $phase"
echo "PASSED ( $passed/$nbr_test )"

