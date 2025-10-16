#!/usr/bin/env bash
set -euo pipefail

readonly NC="\033[0m"
readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly CYAN="\033[36m"
readonly BOLD="\033[1m"

declare -a FLAGS=(
    "-O0"
    "-O0 -march=native"
    "-O1"
    "-O1 -march=native"
    "-O2"
    "-O2 -march=native"
    "-O3"
    "-O3 -march=native"
    "-O3 -ffast-math"
    "-O3 -ffast-math -march=native"
    "-Ofast"
)

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
banner()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

read_set_dimension() {
    read -p "Enter rows [default=1500]: " ROWS
    ROWS=${ROWS:-1500}
    read -p "Enter cols [default=1500]: " COLS
    COLS=${COLS:-1500}

    sed -i "s/^#define ROWS .*/#define ROWS $ROWS/" matrix_bench.c
    sed -i "s/^#define COLS .*/#define COLS $COLS/" matrix_bench.c
    info "Matrix dimensions set to ${BLUE}${ROWS}x${COLS}${NC}"
}

clean_up() {
    rm -f matrix_bench Assembly_codes/*.txt 2>/dev/null || true
}

compile() {
    local flag=$1 ef_name=$2 af_name=$3 cf_name=$4
    info "Compiling with ${BLUE}$flag${NC}"
    gcc -o "$ef_name" "$cf_name" $flag -Wall
    gcc -S $flag -o temp.s "$cf_name"
    mv temp.s "$af_name"
    success "Compiled successfully ($ef_name, $af_name)"
}

generate_result_file() {
    local min_time=1000000.0
    local min_flag="no flag"
    local result_file="result.txt"

    info "Generating result file: $result_file"
    {
        echo "Matrix Dimensions: $ROWS x $COLS"
        echo "+-------------------------------+-----------------------------------+"
        printf "|%-30s | %-34s|\n" "Compiler Flags" "Execution Time"
        echo "+-------------------------------+-----------------------------------+"
    } > "$result_file"

    for flag in "${FLAGS[@]}"; do
        local sanitized_name=$(echo "$flag" | tr -d ' ' | tr -d '-' | tr '=' '_')
        local assembly_file="assembly_$sanitized_name.txt"

        compile "$flag" "matrix_bench" "$assembly_file" "matrix_bench.c"

        local raw_time_output=$(./matrix_bench)
        local sanitized_time=$(echo "$raw_time_output" | awk '{print $3}' | tr -d '\r' )
        if [[ ! $sanitized_time =~ ^[0-9]*\.?[0-9]+$ ]]; then
            warn "Invalid time format from output: '$raw_time_output'"
            continue
        fi

        if (( $(echo "$sanitized_time < $min_time" | bc -l) )); then
            min_time=$sanitized_time
            min_flag="$flag"
            info "Updated MIN_TIME to $min_time MIN_FLAG to $min_flag"
        fi

        printf "|%-30s | %-34s|\n" "$flag" "$raw_time_output" >> "$result_file"
    done

    {
        echo "+-------------------------------+-----------------------------------+"
        printf "|%-30s | %-34s|\n" "$min_flag" "$min_time"
        echo "+-------------------------------+-----------------------------------+"
    } >> "$result_file"

    success "✅ Benchmark complete. Results in ${BLUE}$result_file${NC}, assembly in ${GREEN}(*.txt)${NC}"
}

main() {
    banner "🚀 GCC Optimization Flag Benchmark"

    if [[ ! -d TEMP_TEST_DIR ]]; then
        info "Cloning GitHub repo..."
        git clone https://github.com/YerdosNar/test_flags.git
        mkdir TEMP_TEST_DIR
        mv test_flags/* TEMP_TEST_DIR/
        rm -rf test_flags
        success "Repository cloned into TEMP_TEST_DIR"
    fi

    info "Cleaning up previous results"
    clean_up

    read_set_dimension
    info "Starting Matrix Multiplication Benchmark..."
    generate_result_file

    info "Moving files to Assembly_codes/ directory"
    mv assembly* Assembly_codes

    info "Cleaning temporary binaries"
    rm -f matrix_bench
    success "All done!"
}

main "$@"

