#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
#   GCC Optimization Flag Benchmark Script
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────
# ANSI Colors
# ───────────────────────────────
readonly NC="\033[0m"
readonly RED="\033[31m"
readonly GREEN="\033[32m"
readonly YELLOW="\033[33m"
readonly BLUE="\033[34m"
readonly CYAN="\033[36m"
readonly BOLD="\033[1m"

# ───────────────────────────────
# Benchmark Flags
# ───────────────────────────────
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
    "-O3 -march=native -fopenmp"
)

# ───────────────────────────────
# Helper Functions
# ───────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
banner()  { echo -e "${CYAN}${BOLD}$1${NC}"; }

# ───────────────────────────────
# Read matrix dimensions
# ───────────────────────────────
read_set_dimension() {
    read -p "Enter rows [default=1500]: " ROWS
    ROWS=${ROWS:-1500}
    read -p "Enter cols [default=1500]: " COLS
    COLS=${COLS:-1500}

    sed -i -E "s|^#define[[:space:]]+ROWS[[:space:]]+[0-9]+|#define ROWS $ROWS|" matrix_bench.c
    sed -i -E "s|^#define[[:space:]]+COLS[[:space:]]+[0-9]+|#define COLS $COLS|" matrix_bench.c

    info "Matrix dimensions set to ${BLUE}${ROWS}x${COLS}${NC}"
}

# ───────────────────────────────
# Clean up old results
# ───────────────────────────────
clean_up() {
    rm -f matrix_bench result.txt assembly_* 2>/dev/null || true
}

# ───────────────────────────────
# Compilation step
# ───────────────────────────────
compile() {
    local flag=$1 ef_name=$2 af_name=$3 cf_name=$4
    info "Compiling with ${BLUE}$flag${NC}"
    gcc -o "$ef_name" "$cf_name" $flag -Wall
    gcc -S "$cf_name" -o temp.s $flag
    mv temp.s "$af_name"
    success "Compiled successfully → ${GREEN}$ef_name${NC}, ${CYAN}$af_name${NC}"
}

# ───────────────────────────────
# Generate benchmark results
# ───────────────────────────────
generate_result_file() {
    local min_time=1e9
    local min_flag="none"
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
        local assembly_file="assembly_${sanitized_name}.txt"

        compile "$flag" "matrix_bench" "$assembly_file" "matrix_bench.c"

        local raw_time_output=$(./matrix_bench 2>/dev/null || true)

        local sanitized_time=$(echo "$raw_time_output" | awk '{print $3}' | tr -d '\r')

        if [[ -z "$sanitized_time" || ! "$sanitized_time" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            warn "Invalid output for '$flag' → '$raw_time_output'"
            continue
        fi

        info "Compare"
        if [[ $(echo "$sanitized_time < $min_time" | bc -l) -eq 1 ]]; then
            min_time=$sanitized_time
            min_flag="$flag"
            info "Min time update to $min_time"
        fi
        info "Comparison done"

        printf "|%-30s | %-34s|\n" "$flag" "$raw_time_output" >> "$result_file"
    done

    {
        echo "+-------------------------------+-----------------------------------+"
        printf "|%-30s | %-34s|\n" "Best flag" "$min_flag"
        printf "|%-30s | %-34s|\n" "Best time" "$min_time seconds"
        echo "+-------------------------------+-----------------------------------+"
    } >> "$result_file"

    success "✅ Benchmark complete. Results → ${BLUE}$result_file${NC}"
}

# ───────────────────────────────
# Main execution
# ───────────────────────────────
main() {
    banner "🚀 GCC Optimization Flag Benchmark"

    info "Cleaning up previous results..."
    clean_up

    read_set_dimension
    info "Starting Matrix Multiplication Benchmark..."
    generate_result_file

    mkdir -p Assembly_codes
    info "Moving assembly files → Assembly_codes/"
    mv assembly_* Assembly_codes/ 2>/dev/null || true

    rm -f matrix_bench
    success "All done! Results saved in ${GREEN}result.txt${NC} and ${CYAN}Assembly_codes/${NC}"
}

main "$@"

