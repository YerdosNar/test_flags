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

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

uninstall() {
    info "Uninstalling benchmark test directory"
    echo -e "Press ${YELLOW}ENTER${NC} to proceed"
    read
    warn "Uninstalling..."
    find ~ -type d -name "TEMP_TEST_DIR" -exec rm -rf {} + 2>/dev/null || true
    success "Removed TEMP_TEST_DIR (if ever existed)"
    exit 0
}

install() {
    local packages=("$@")
    local os_id=$(detect_os)
    case "$ID" in
        arch)
            sudo pacman -S --noconfirm "${packages[@]}" ;;
        ubuntu|kali|debian)
            sudo apt update && sudo apt install -y "${packages[@]}" ;;
        fedora)
            sudo yum install -y "${packages[@]}" ;;
        *)
            error "Sorry, Could not determine OS..."
            exit 1 ;;
    esac
}

check_packages() {
    info "Checking packages..."
    local missing=()
    for pac in bc sed gcc;
    do
        if ! command -v "$pac" &>/dev/null; then
            missing+=("$pac")
        else
            success "$pac exists!"
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        error "Missing required packages: ${RED}${missing[*]}${NC}"
        read -p "Install [Y/n]: " install_pac
        install_pac=${install_pac:-Y}
        if [[ "$install_pac" =~ ^[Yy]$ ]]; then
            install ${missing[*]}
        else
            warn "Install manually to run this script"
            uninstall
            exit 1
        fi
    else
        success "All packages are installed"
    fi
}

read_set_dimension() {
    read -p "Enter size [default=1500]: " SIZE
    SIZE=${SIZE:-1500}

    sed -i "s/^#define SIZE .*/#define SIZE $SIZE/" matrix_bench.c
    info "Matrix dimensions set to ${BLUE}${SIZE}x${SIZE}${NC}"
}

clean_up() {
    rm -rf matrix_bench Assembly_codes 2>/dev/null || true
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
        echo "Matrix Dimensions: $SIZE x $SIZE"
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
            info "Updated ${GREEN}MIN_TIME${NC} to $min_time ${GREEN}MIN_FLAG${NC} to $min_flag"
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
    if [[ $# -eq 1 && "$1" == "uninstall" ]]; then
        uninstall
    fi

    banner "🚀 GCC Optimization Flag Benchmark"
    check_packages

    if [ "$(basename $PWD)" == "TEMP_TEST_DIR" ]; then
        info "Skipped cloning"
    else
        info "Cloning GitHub repo..."
        git clone --depth=1 https://github.com/YerdosNar/test_flags.git
        mkdir TEMP_TEST_DIR
        mv test_flags/* TEMP_TEST_DIR/
        rm -rf test_flags
        success "Repository cloned into TEMP_TEST_DIR"
        cd TEMP_TEST_DIR
    fi

    info "Cleaning up previous results"
    clean_up
    mkdir Assembly_codes

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

