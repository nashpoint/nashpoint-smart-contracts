#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
SCOPE_FILE="scope.csv"
CORPUS_DIR="echidna-corpus"
VERBOSE=""
ALL_FLAG=""
CONTRACTS=""
SPECIFIC_COVERAGE_FILE=""
OUTPUT_FORMAT="summary" # summary, detailed, json, or markdown
MARKDOWN_FILE="" # Optional markdown output file

# Function to print colored output
print_color() {
    local color=$1
    shift
    printf "${color}%s${NC}\n" "$*"
}

# Function to print usage
usage() {
    cat << EOF
${BOLD}Echidna Coverage Analyzer${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}OPTIONS:${NC}
    -s, --scope FILE        Path to scope.csv file (default: scope.csv)
    -d, --corpus-dir DIR    Path to echidna-corpus directory (default: echidna-corpus)
    -c, --contracts LIST    Comma-separated list of contracts or "[contract1,contract2]" format
                           If not specified, all contracts from scope.csv will be analyzed
    -f, --file FILE        Use specific coverage file instead of latest
    -o, --output FORMAT    Output format: summary, detailed, json, or markdown (default: summary)
    -m, --markdown FILE    Save results to markdown file (can be used with any output format)
    -a, --all              Include all contracts (pass -af to echidna-coverage)
    -v, --verbose          Verbose output (pass -vv to echidna-coverage)
    -h, --help             Show this help message

${BOLD}EXAMPLES:${NC}
    # Analyze all contracts from scope.csv with latest coverage file
    $0

    # Analyze specific contracts
    $0 -c "BSwap,BFactory"
    $0 -c "[BSwap.sol, BFactory.sol]"

    # Use specific coverage file
    $0 -f echidna-corpus/covered.1757499345.txt

    # Verbose output with all contracts
    $0 -v -a

    # Analyze contracts from custom scope file
    $0 -s custom-scope.csv -c "Contract1,Contract2"

${BOLD}OUTPUT:${NC}
    The script will display coverage information for each contract and provide
    a summary at the end including:
    - Total lines covered
    - Coverage percentage
    - Uncovered lines details (if available)

EOF
}

# Function to get the latest coverage txt file
get_latest_coverage_file() {
    local corpus_dir=$1
    if [[ ! -d "$corpus_dir" ]]; then
        print_color "$RED" "Error: Corpus directory '$corpus_dir' not found"
        exit 1
    fi
    
    local latest_file
    latest_file=$(find "$corpus_dir" -name "covered.*.txt" -type f 2>/dev/null | sort -t. -k2 -n | tail -1)
    
    if [[ -z "$latest_file" ]]; then
        print_color "$RED" "Error: No coverage txt files found in '$corpus_dir'"
        exit 1
    fi
    
    printf "%s" "$latest_file"
}

# Function to extract contract names from scope.csv
get_contracts_from_scope() {
    local scope_file=$1
    if [[ ! -f "$scope_file" ]]; then
        print_color "$RED" "Error: Scope file '$scope_file' not found"
        exit 1
    fi

    # Extract contract names from the first column (contract path)
    # Format: amm-pool-type-dynamic/src/Constants.sol -> /Constants.sol
    # Returns in array format: [/Constants.sol, /DataTypes.sol, ...]
    # The leading / ensures we match the exact filename at the end of the path
    local contracts
    # Extract filenames, remove any path if present, then add leading /
    contracts=$(tail -n +2 "$scope_file" | cut -d',' -f1 | sed 's|.*/||' | sed 's|^|/|' | tr '\n' ',' | sed 's/,$//')
    # Convert to array format for echidna-coverage
    contracts="[${contracts}]"
    printf "%s" "$contracts"
}

# Function to check if scope.csv contains test files
has_test_files_in_scope() {
    local scope_file=$1
    if [[ ! -f "$scope_file" ]]; then
        return 1
    fi

    # Use grep safely with set -e
    if grep -q "/test/" "$scope_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to extract test files from scope.csv
get_test_files_from_scope() {
    local scope_file=$1
    if [[ ! -f "$scope_file" ]]; then
        printf ""
        return
    fi

    local test_files
    # Extract only files that contain /test/ in their path (grep with || true for set -e safety)
    test_files=$(tail -n +2 "$scope_file" | cut -d',' -f1 | { grep "/test/" || true; } | sed 's|.*/||' | sed 's|^|/|' | tr '\n' ',' | sed 's/,$//')

    if [[ -n "$test_files" ]]; then
        printf "[%s]" "$test_files"
    else
        printf ""
    fi
}

# Function to get contracts from src directory as fallback
get_contracts_from_src() {
    local src_dir="${BASH_SOURCE[0]%/*}/src"

    if [[ ! -d "$src_dir" ]]; then
        printf ""
        return
    fi

    local contracts
    # Find all .sol files in src directory
    contracts=$(find "$src_dir" -name "*.sol" -type f | sed 's|.*/||' | sed 's|^|/|' | tr '\n' ',' | sed 's/,$//')

    if [[ -n "$contracts" ]]; then
        printf "[%s]" "$contracts"
    else
        printf ""
    fi
}

# Function to build package mapping from scope.csv
get_package_mapping() {
    local scope_file=$1
    declare -A package_map

    # Read scope.csv and build mapping of contract -> package
    while IFS=',' read -r path source total comment; do
        if [[ "$path" == "contract" ]]; then
            continue  # Skip header
        fi
        # Extract package and filename
        local package=$(echo "$path" | cut -d'/' -f1)
        local filename=$(basename "$path")
        package_map["$filename"]="$package"
    done < "$scope_file"

    # Export as string (key:value pairs)
    for key in "${!package_map[@]}"; do
        echo "${key}:${package_map[$key]}"
    done
}

# Function to parse contract list argument
parse_contracts() {
    local input=$1
    # If input doesn't have brackets, add them
    # If it does, keep them
    # Ensure .sol extension is present and add leading / for exact matching
    if [[ "$input" == \[* ]]; then
        # Already has brackets, ensure each contract has leading /
        # Remove brackets, process, then re-add
        local content
        content=$(printf "%s" "$input" | sed 's/^\[//; s/\]$//')
        # Add leading / to each contract name if not present
        content=$(printf "%s" "$content" | sed 's/\([^/,]\+\)/\/\1/g' | sed 's/\/\//\//g')
        printf "[%s]" "$content"
    else
        # Convert comma-separated to array format
        # Add .sol if not present and leading / for each contract
        local formatted
        formatted=$(printf "%s" "$input" | sed 's/,/, /g')
        # Add leading / and .sol extension if needed
        formatted=$(printf "%s" "$formatted" | sed 's/\([^/, ]\+\)/\/\1/g' | sed 's/\([^.]\)$/\1.sol/g' | sed 's/\.sol\.sol/.sol/g' | sed 's/\/\//\//g')
        printf "[%s]" "$formatted"
    fi
}

# Function to run echidna-coverage for a set of contracts
run_echidna_coverage() {
    local coverage_file=$1
    local contracts=$2
    local verbose=$3
    local all_flag=$4
    local scope_file=$5
    local source_only=$6
    local logical=$7

    local cmd="echidna-coverage -f \"$coverage_file\" -vv"

    if [[ -n "$all_flag" ]]; then
        cmd="$cmd -af"
    fi

    # Always use -vv for detailed output, but add extra -vv if verbose requested
    if [[ -n "$verbose" ]]; then
        # Already have -vv, so this gives us maximum verbosity
        cmd="$cmd"
    fi

    if [[ -n "$contracts" ]]; then
        # Contracts should already be in array format [contract1.sol, contract2.sol]
        cmd="$cmd -c \"$contracts\""
    fi

    # Add scope file for total coverage calculation
    if [[ -n "$scope_file" ]]; then
        cmd="$cmd -s \"$scope_file\""
    fi

    # Add filter flags
    if [[ -n "$source_only" ]]; then
        cmd="$cmd --source-only"
    fi

    if [[ -n "$logical" ]]; then
        cmd="$cmd --logical"
    fi

    print_color "$CYAN" "Running: $cmd"
    echo ""

    # Run the command and capture output
    local output
    if output=$(eval "$cmd" 2>&1); then
        printf "%s\n" "$output"
        return 0
    else
        print_color "$RED" "Error running echidna-coverage:"
        printf "%s\n" "$output"
        return 1
    fi
}

# Function to check if logicalCoverage files exist in coverage file
check_logical_coverage_exists() {
    local coverage_file=$1
    if grep -q "/logicalCoverage/logical.*\.sol" "$coverage_file"; then
        return 0
    else
        return 1
    fi
}

# Function to generate markdown report with package grouping
generate_markdown_report() {
    local output=$1
    local contracts=$2
    local coverage_file=$3
    local timestamp=$4
    local markdown_file=$5
    
    # Start building markdown content
    local md_content=""
    
    # Header
    md_content+="# Echidna Coverage Report\n\n"
    md_content+="**Generated:** $(date '+%Y-%m-%d %H:%M:%S')\n"
    md_content+="**Coverage File:** \`${coverage_file}\`\n"
    md_content+="**Timestamp:** ${timestamp}\n\n"
    
    # Overall Summary Section
    md_content+="## 📊 Overall Summary\n\n"
    
    # Parse output to extract contract data
    local total_contracts=0
    local below_threshold=0
    local total_lines=0
    local covered_lines=0
    local contract_data=""
    local current_contract=""
    local in_contract=false
    local use_scoped_totals=false
    local scoped_total_lines=0
    local scoped_covered_lines=0
    local scoped_coverage_pct=0
    
    # Arrays to store contract details
    local contract_names=()
    local contract_coverages=()
    local contract_functions=()
    local contract_details=()
    local contract_uncovered_functions=()
    local contract_uncovered_lines=()

    # Build package mapping from scope.csv (Bash 3.2 compatible)
    # Use parallel arrays instead of associative arrays
    local scope_contract_names=()
    local scope_contract_packages=()
    local scope_contract_covered=()
    local all_packages=()
    local package_list=""

    # Read scope.csv and build mappings
    if [[ -f "$SCOPE_FILE" ]]; then
        while IFS=',' read -r path source total comment; do
            if [[ "$path" == "contract" ]]; then
                continue  # Skip header
            fi
            # Extract package and filename
            local package=$(echo "$path" | cut -d'/' -f1)
            local basename_no_ext=$(basename "$path" .sol)

            # Store in parallel arrays
            scope_contract_names+=("$basename_no_ext")
            scope_contract_packages+=("$package")
            scope_contract_covered+=("0")  # 0 = not covered, 1 = covered

            # Track unique packages
            if [[ ! " $package_list " =~ " $package " ]]; then
                package_list+=" $package"
                all_packages+=("$package")
            fi
        done < "$SCOPE_FILE"
    fi
    
    # Parse the echidna-coverage output
    local current_function=""
    local in_function_details=false
    local uncovered_functions_data=""
    local uncovered_lines_data=""
    
    while IFS= read -r line; do
        # Strip ANSI color codes and convert box-drawing chars to pipes
        local clean_line=$(printf "%s" "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/│/|/g')
        
        # Detect contract name
        if [[ "$clean_line" =~ "File: "(.+)$ ]]; then
            current_contract="${BASH_REMATCH[1]}"
            current_contract=$(basename "$current_contract" .sol)
            contract_names+=("$current_contract")
            in_contract=true
            contract_data=""
            uncovered_functions_data=""
            uncovered_lines_data=""

            # Mark this contract as covered in our tracking
            for idx in "${!scope_contract_names[@]}"; do
                if [[ "${scope_contract_names[$idx]}" == "$current_contract" ]]; then
                    scope_contract_covered[$idx]="1"  # 1 = covered
                    break
                fi
            done
        fi
        
        # Capture contract details
        if [[ "$in_contract" == true ]]; then
            # Store clean line for details
            local clean_detail=$(printf "%s" "$line" | sed 's/\x1b\[[0-9;]*m//g')
            contract_data+="$clean_detail\n"
            
            # Extract coverage percentage from clean line (table format with | separator)
            # The line looks like: |   lineCoveragePercentage   | 61.33  |
            if [[ "$clean_line" =~ lineCoveragePercentage.*\|[[:space:]]*([0-9]+\.?[0-9]*)[[:space:]]*\| ]]; then
                local coverage="${BASH_REMATCH[1]}"
                contract_coverages+=("$coverage")
                if (( $(echo "$coverage < 70" | bc -l) )); then
                    below_threshold=$((below_threshold + 1))
                fi
            fi
            
            # Extract function coverage from clean line (table format with | separator)
            if [[ "$clean_line" =~ totalFunctions.*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
                contract_functions+=("${BASH_REMATCH[1]}")
            fi
            
            # Detect start of uncovered functions table
            if [[ "$clean_line" =~ "Not fully covered functions:" ]]; then
                uncovered_functions_data+="## ⚠️ Uncovered Functions\n\n"
                uncovered_functions_data+="| Index | Function Name | Touched | Reverted | Untouched Lines |\n"
                uncovered_functions_data+="|-------|---------------|---------|----------|----------------|\n"
            fi
            
            # Capture uncovered functions table data rows (skip the original table header/separator lines)
            if [[ "$clean_line" =~ ^\|[[:space:]]*[0-9]+[[:space:]]*\|.*functionName.*\| ]] ||
               [[ "$clean_line" =~ ^\|[[:space:]]*[0-9]+[[:space:]]*\|.*\'.*\|.*\|.*\|.*\| ]]; then
                # Parse the row and reformat it
                if [[ "$clean_line" =~ \|[[:space:]]*([0-9]+)[[:space:]]*\|[[:space:]]*\'?([^\'|]+)\'?[[:space:]]*\|[[:space:]]*([a-z]+)[[:space:]]*\|[[:space:]]*([a-z]+)[[:space:]]*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
                    local idx="${BASH_REMATCH[1]}"
                    local func="${BASH_REMATCH[2]}"
                    local touched="${BASH_REMATCH[3]}"
                    local reverted="${BASH_REMATCH[4]}"
                    local untouched="${BASH_REMATCH[5]}"
                    uncovered_functions_data+="| $idx | \`$func\` | $touched | $reverted | $untouched |\n"
                fi
            fi
            
            # Detect function details section
            if [[ "$clean_line" =~ ^Function:[[:space:]]*(.+)$ ]]; then
                current_function="${BASH_REMATCH[1]}"
                uncovered_lines_data+="### Function: \`$current_function\`\n\n"
                in_function_details=true
            fi
            
            # Capture untouched lines (code lines that are not table separators or headers)
            if [[ "$in_function_details" == true ]] && [[ ! "$clean_line" =~ ^Function: ]] && 
               [[ ! "$clean_line" =~ ^\|.*\|$ ]] && [[ ! "$clean_line" =~ ^[[:space:]]*$ ]] && 
               [[ ! "$clean_line" =~ ^═+ ]] && [[ -n "$clean_line" ]]; then
                # This looks like a code line
                uncovered_lines_data+="\`\`\`solidity\n$clean_line\n\`\`\`\n\n"
            fi
            
            # Reset function details when we see another Function: or end
            if [[ "$clean_line" =~ ^Function: ]] && [[ -n "$current_function" ]] && [[ "$clean_line" != *"$current_function"* ]]; then
                in_function_details=false
            fi
            
            # Store full details and stop processing when we see Warning line
            if [[ "$clean_line" =~ "Warning:" ]] && [[ -n "$current_contract" ]]; then
                contract_details+=("$contract_data")
                contract_uncovered_functions+=("$uncovered_functions_data")
                contract_uncovered_lines+=("$uncovered_lines_data")
                in_contract=false
                in_function_details=false
            fi
        fi
        
        # Detect TOTAL COVERAGE (Scoped Contracts) section
        if [[ "$clean_line" =~ "TOTAL COVERAGE (Scoped Contracts)" ]]; then
            use_scoped_totals=true
        fi

        # Extract scoped totals if in TOTAL COVERAGE section
        if [[ "$use_scoped_totals" == true ]]; then
            if [[ "$clean_line" =~ "Total Lines".*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
                scoped_total_lines="${BASH_REMATCH[1]}"
            fi
            if [[ "$clean_line" =~ "Total Covered Lines".*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
                scoped_covered_lines="${BASH_REMATCH[1]}"
            fi
            if [[ "$clean_line" =~ "Total Coverage %".*\|[[:space:]]*\'([0-9.]+)%\'[[:space:]]*\| ]]; then
                scoped_coverage_pct="${BASH_REMATCH[1]}"
            fi
        fi

        # Extract total and covered lines from clean line (table format with | separator)
        if [[ "$clean_line" =~ coveredLines.*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
            covered_lines=$((covered_lines + ${BASH_REMATCH[1]}))
        fi
        if [[ "$clean_line" =~ untouchedLines.*\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
            total_lines=$((total_lines + ${BASH_REMATCH[1]} + covered_lines))
        fi
    done <<< "$output"
    
    # Handle the last contract if no Warning line was found
    if [[ "$in_contract" == true ]] && [[ -n "$current_contract" ]]; then
        contract_details+=("$contract_data")
        contract_uncovered_functions+=("$uncovered_functions_data")
        contract_uncovered_lines+=("$uncovered_lines_data")
    fi

    # Use scoped totals if available, otherwise use accumulated totals
    if [[ "$use_scoped_totals" == true ]] && [[ $scoped_total_lines -gt 0 ]]; then
        total_lines=$scoped_total_lines
        covered_lines=$scoped_covered_lines
        overall_coverage=$scoped_coverage_pct
    else
        # Calculate overall coverage from accumulated values
        local overall_coverage=0
        if [[ $total_lines -gt 0 ]]; then
            overall_coverage=$(echo "scale=2; $covered_lines * 100 / $total_lines" | bc)
        fi
    fi

    # Get total contracts from arrays
    total_contracts=${#contract_names[@]}
    
    # Debug: Show array sizes (commented out for production)
    # echo "DEBUG: contract_names has ${#contract_names[@]} elements" >&2
    # echo "DEBUG: contract_coverages has ${#contract_coverages[@]} elements" >&2
    # echo "DEBUG: contract_functions has ${#contract_functions[@]} elements" >&2
    
    # Summary table
    md_content+="| Metric | Value |\n"
    md_content+="|--------|-------|\n"
    md_content+="| **Total Contracts** | ${total_contracts} |\n"
    md_content+="| **Contracts Below 70%** | ${below_threshold} |\n"
    md_content+="| **Overall Line Coverage** | ${overall_coverage}% |\n"
    md_content+="| **Total Lines** | ${total_lines} |\n"
    md_content+="| **Covered Lines** | ${covered_lines} |\n\n"
    
    # Status badge
    if [[ $below_threshold -eq 0 ]]; then
        md_content+="✅ **Status:** All contracts meet the 70% coverage threshold\n\n"
    else
        md_content+="⚠️ **Status:** ${below_threshold} contract(s) below 70% coverage threshold\n\n"
    fi

    # Sort packages for consistent output (needed for both sections)
    local sorted_packages=($(printf '%s\n' "${all_packages[@]}" | sort | uniq))
    sorted_packages+=("unknown")  # Add unknown at the end

    # Report uncovered contracts from scope (Bash 3.2 compatible)
    md_content+="## 🔍 Coverage Analysis Against Scope\n\n"

    # Count uncovered contracts
    local uncovered_count=0
    local uncovered_list=""

    # Build list of uncovered contracts grouped by package
    for package in "${sorted_packages[@]}"; do
        local package_uncovered=()

        for idx in "${!scope_contract_names[@]}"; do
            if [[ "${scope_contract_covered[$idx]}" == "0" ]]; then
                if [[ "${scope_contract_packages[$idx]}" == "$package" ]]; then
                    package_uncovered+=("${scope_contract_names[$idx]}")
                    uncovered_count=$((uncovered_count + 1))
                fi
            fi
        done

        if [[ ${#package_uncovered[@]} -gt 0 ]]; then
            if [[ -z "$uncovered_list" ]]; then
                uncovered_list="**Package: $package**\n\n"
            else
                uncovered_list+="\n**Package: $package**\n\n"
            fi
            # Add each contract on its own line
            for contract in "${package_uncovered[@]}"; do
                uncovered_list+="- $contract\n"
            done
            uncovered_list+="\n"
        fi
    done

    if [[ $uncovered_count -gt 0 ]]; then
        md_content+="### ❌ Contracts in Scope but Not Covered (${uncovered_count} contracts)\n\n"
        md_content+="$uncovered_list"
        md_content+="\n"
    else
        md_content+="✅ All contracts in scope have coverage data.\n\n"
    fi
    
    # Group contracts by package (Bash 3.2 compatible)
    # We'll iterate through packages and find matching contracts
    md_content+="## 📋 Contracts Coverage by Package\n\n"

    for package in "${sorted_packages[@]}"; do
        local has_contracts=false
        local package_content=""

        # Check if this package has any covered contracts
        for i in "${!contract_names[@]}"; do
            local name="${contract_names[$i]}"
            local found_package="unknown"

            # Find the package for this contract
            for idx in "${!scope_contract_names[@]}"; do
                if [[ "${scope_contract_names[$idx]}" == "$name" ]]; then
                    found_package="${scope_contract_packages[$idx]}"
                    break
                fi
            done

            if [[ "$found_package" == "$package" ]]; then
                has_contracts=true
                break
            fi
        done

        if [[ "$has_contracts" == false ]] && [[ "$package" == "unknown" ]]; then
            # Check if we have any unknown contracts
            local has_unknown=false
            for i in "${!contract_names[@]}"; do
                local name="${contract_names[$i]}"
                local found=false
                for idx in "${!scope_contract_names[@]}"; do
                    if [[ "${scope_contract_names[$idx]}" == "$name" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    has_unknown=true
                    break
                fi
            done
            if [[ "$has_unknown" == false ]]; then
                continue
            fi
        elif [[ "$has_contracts" == false ]]; then
            continue
        fi

        md_content+="### 📦 Package: $package\n\n"
        md_content+="| Contract | Coverage | Status | Functions | Details |\n"
        md_content+="|----------|----------|--------|-----------|---------|"
    
        # Add contracts for this package
        for i in "${!contract_names[@]}"; do
            local name="${contract_names[$i]}"

            # Find the package for this contract
            local found_package="unknown"
            for idx in "${!scope_contract_names[@]}"; do
                if [[ "${scope_contract_names[$idx]}" == "$name" ]]; then
                    found_package="${scope_contract_packages[$idx]}"
                    break
                fi
            done

            # Skip if not in the current package
            if [[ "$found_package" != "$package" ]]; then
                if [[ "$package" != "unknown" ]] || [[ "$found_package" != "unknown" ]]; then
                    continue
                fi
            fi
            # Check if we have coverage data for this index
            if [[ $i -lt ${#contract_coverages[@]} ]]; then
                local coverage="${contract_coverages[$i]}"
            else
                local coverage="0"
            fi
            if [[ $i -lt ${#contract_functions[@]} ]]; then
                local functions="${contract_functions[$i]}"
            else
                local functions="0"
            fi
            local status="✅ Pass"
            local badge="🟢"

            if (( $(echo "$coverage < 70" | bc -l) )); then
                status="❌ Fail"
                if (( $(echo "$coverage < 30" | bc -l) )); then
                    badge="🔴"
                elif (( $(echo "$coverage < 50" | bc -l) )); then
                    badge="🟠"
                else
                    badge="🟡"
                fi
            fi

            # Convert name to lowercase for anchor link (Bash 3.2 compatible)
            local anchor=$(printf "%s" "$name" | tr '[:upper:]' '[:lower:]')
            md_content+="\n| ${badge} **${name}** | ${coverage}% | ${status} | ${functions} | [View](#${anchor}) |"
        done
        md_content+="\n\n"
    done
    
    md_content+="\n\n"
    
    # Detailed Contract Analysis
    md_content+="## 🔍 Detailed Contract Analysis\n\n"
    
    # Add details for each contract
    for i in "${!contract_names[@]}"; do
        local name="${contract_names[$i]}"
        # Check if we have coverage data for this index
        if [[ $i -lt ${#contract_coverages[@]} ]]; then
            local coverage="${contract_coverages[$i]}"
        else
            local coverage="0"
        fi
        
        md_content+="### ${name}\n\n"
        
        # Coverage bar visualization
        local bar_length=50
        local filled=$(echo "scale=0; $coverage * $bar_length / 100" | bc)
        local empty=$((bar_length - filled))
        local bar=""
        
        for ((j=0; j<filled; j++)); do bar+="█"; done
        for ((j=0; j<empty; j++)); do bar+="░"; done
        
        md_content+="**Coverage:** ${coverage}%\n"
        md_content+="\`${bar}\`\n\n"
        
        # Add coverage stats table
        if [[ $i -lt ${#contract_coverages[@]} ]]; then
            md_content+="## 📈 Coverage Statistics\n\n"
            md_content+="| Metric | Value |\n"
            md_content+="|--------|-------|\n"
            if [[ $i -lt ${#contract_functions[@]} ]]; then
                md_content+="| Total Functions | ${contract_functions[$i]} |\n"
            fi
            md_content+="| Line Coverage | ${coverage}% |\n"
            md_content+="\n"
        fi
        
        # Add detailed analysis sections
        
        # Uncovered Functions Table
        if [[ $i -lt ${#contract_uncovered_functions[@]} ]] && [[ -n "${contract_uncovered_functions[$i]}" ]]; then
            md_content+="${contract_uncovered_functions[$i]}\n"
        fi
        
        # Uncovered Lines Details  
        if [[ $i -lt ${#contract_uncovered_lines[@]} ]] && [[ -n "${contract_uncovered_lines[$i]}" ]]; then
            md_content+="## 🔍 Uncovered Code Lines\n\n"
            md_content+="${contract_uncovered_lines[$i]}\n"
        fi
        
        # Original detailed output in collapsible section
        if [[ $i -lt ${#contract_details[@]} ]] && [[ -n "${contract_details[$i]}" ]]; then
            md_content+="<details>\n"
            md_content+="<summary>📊 Full Coverage Report</summary>\n\n"
            md_content+="\`\`\`\n"
            md_content+="${contract_details[$i]}"
            md_content+="\`\`\`\n\n"
            md_content+="</details>\n\n"
        fi
    done
    
    # Recommendations section
    md_content+="## 💡 Recommendations\n\n"
    
    if [[ $below_threshold -gt 0 ]]; then
        md_content+="The following contracts need attention to meet the 70% coverage threshold:\n\n"
        for i in "${!contract_names[@]}"; do
            # Check if we have coverage data for this index
            if [[ $i -lt ${#contract_coverages[@]} ]]; then
                local coverage="${contract_coverages[$i]}"
            else
                local coverage="0"
            fi
            if (( $(echo "$coverage < 70" | bc -l) )); then
                local improvement_needed=$(echo "scale=2; 70 - $coverage" | bc)
                md_content+="- **${contract_names[$i]}**: Needs ${improvement_needed}% improvement (current: ${coverage}%)\n"
            fi
        done
        md_content+="\n"
    fi
    
    md_content+="### Next Steps:\n"
    md_content+="1. Focus on contracts with coverage below 30% first\n"
    md_content+="2. Add test cases for uncovered functions\n"
    md_content+="3. Review and test edge cases\n"
    md_content+="4. Run echidna with longer campaign for better coverage\n\n"
    
    # Footer
    md_content+="---\n"
    md_content+="*Report generated by echidna-coverage-analyzer.sh*\n"
    
    # Save to file if specified
    if [[ -n "$markdown_file" ]]; then
        printf "%b" "$md_content" > "$markdown_file"
        print_color "$GREEN" "Markdown report saved to: $markdown_file"
    else
        # Output to stdout
        printf "%b" "$md_content"
    fi
}

# Function to summarize coverage output
summarize_coverage() {
    local output=$1
    local contracts=$2
    
    print_color "$MAGENTA" "\n${BOLD}=== OVERALL SUMMARY ===${NC}"
    
    # Count contracts below threshold
    local below_threshold=0
    local total_contracts=0
    
    # Extract coverage percentages for each contract
    while IFS= read -r line; do
        if [[ "$line" =~ lineCoveragePercentage.*([0-9]+\.?[0-9]*) ]]; then
            local coverage="${BASH_REMATCH[1]}"
            total_contracts=$((total_contracts + 1))
            if (( $(echo "$coverage < 70" | bc -l) )); then
                below_threshold=$((below_threshold + 1))
            fi
        fi
    done <<< "$output"
    
    # Summary stats
    if [[ $total_contracts -gt 0 ]]; then
        print_color "$BLUE" "Total contracts analyzed: $total_contracts"
        if [[ $below_threshold -gt 0 ]]; then
            print_color "$YELLOW" "Contracts below 70% threshold: $below_threshold"
        else
            print_color "$GREEN" "All contracts meet coverage threshold!"
        fi
    fi
    
    # Check for warnings
    if printf "%s" "$output" | grep -q "Warning: Coverage"; then
        print_color "$YELLOW" "\n⚠️  Some contracts have coverage below the 70% threshold"
    fi
    
    print_color "$CYAN" "\nTip: Use -v flag for verbose output or -o detailed for full details"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scope)
            SCOPE_FILE="$2"
            shift 2
            ;;
        -d|--corpus-dir)
            CORPUS_DIR="$2"
            shift 2
            ;;
        -c|--contracts)
            CONTRACTS="$2"
            shift 2
            ;;
        -f|--file)
            SPECIFIC_COVERAGE_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -m|--markdown)
            MARKDOWN_FILE="$2"
            shift 2
            ;;
        -a|--all)
            ALL_FLAG="yes"
            shift
            ;;
        -v|--verbose)
            VERBOSE="yes"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
print_color "$BOLD" "Echidna Coverage Analyzer"
print_color "$BOLD" "========================"
echo ""

# Determine coverage file to use
if [[ -n "$SPECIFIC_COVERAGE_FILE" ]]; then
    COVERAGE_FILE="$SPECIFIC_COVERAGE_FILE"
    print_color "$BLUE" "Using specified coverage file: $COVERAGE_FILE"
else
    COVERAGE_FILE=$(get_latest_coverage_file "$CORPUS_DIR")
    print_color "$BLUE" "Using latest coverage file: $COVERAGE_FILE"
fi

# Verify coverage file exists
if [[ ! -f "$COVERAGE_FILE" ]]; then
    print_color "$RED" "Error: Coverage file '$COVERAGE_FILE' not found"
    exit 1
fi

# Get timestamp from filename
TIMESTAMP=$(basename "$COVERAGE_FILE" | sed 's/covered\.\([0-9]*\)\.txt/\1/')
print_color "$BLUE" "Coverage timestamp: $TIMESTAMP"
echo ""

# Determine contracts to analyze
if [[ -z "$CONTRACTS" ]]; then
    # Get all contracts from scope.csv
    print_color "$YELLOW" "No contracts specified, using all from $SCOPE_FILE"
    CONTRACTS=$(get_contracts_from_scope "$SCOPE_FILE")
    if [[ -z "$CONTRACTS" ]]; then
        print_color "$RED" "Error: No contracts found in scope file"
        exit 1
    fi
else
    # Parse the provided contract list
    CONTRACTS=$(parse_contracts "$CONTRACTS")
fi

print_color "$GREEN" "Analyzing contracts: $CONTRACTS"
echo ""

# Generate source-only coverage report
print_color "$BOLD" "\n=== Generating Source-Only Coverage Report ==="

# Run source-only coverage for source contracts
SOURCE_OUTPUT=$(run_echidna_coverage "$COVERAGE_FILE" "$CONTRACTS" "$VERBOSE" "$ALL_FLAG" "$SCOPE_FILE" "yes" "")

# Check if output is empty or has no contracts
HAS_CONTRACTS=false
if [[ -n "$SOURCE_OUTPUT" ]]; then
    if printf "%s" "$SOURCE_OUTPUT" | grep -q "File:" 2>/dev/null; then
        HAS_CONTRACTS=true
    fi
fi

if [[ "$HAS_CONTRACTS" == false ]]; then
    print_color "$YELLOW" "⚠️  No coverage data found with current scope."
    print_color "$YELLOW" "Attempting fallback to src/ directory..."

    # Try to get contracts from src directory
    FALLBACK_CONTRACTS=$(get_contracts_from_src)
    if [[ -n "$FALLBACK_CONTRACTS" ]]; then
        print_color "$BLUE" "Found contracts in src/: $FALLBACK_CONTRACTS"
        SOURCE_OUTPUT=$(run_echidna_coverage "$COVERAGE_FILE" "$FALLBACK_CONTRACTS" "$VERBOSE" "$ALL_FLAG" "" "yes" "")
    else
        print_color "$RED" "Error: No contracts found in src/ directory either"
        exit 1
    fi
fi

# Check if scope.csv contains test files and analyze them separately
if has_test_files_in_scope "$SCOPE_FILE"; then
    TEST_FILES=$(get_test_files_from_scope "$SCOPE_FILE")
    if [[ -n "$TEST_FILES" ]]; then
        print_color "$BOLD" "\n=== Analyzing Test Files from Scope ==="
        print_color "$YELLOW" "Found test files in scope: $TEST_FILES"

        # Run without --source-only flag for test files
        TEST_OUTPUT=$(run_echidna_coverage "$COVERAGE_FILE" "$TEST_FILES" "$VERBOSE" "$ALL_FLAG" "$SCOPE_FILE" "" "")

        # Combine source and test outputs
        if [[ -n "$TEST_OUTPUT" ]]; then
            print_color "$GREEN" "✓ Combining source and test coverage data"
            COMBINED_OUTPUT="${SOURCE_OUTPUT}"$'\n\n'"${TEST_OUTPUT}"
            SOURCE_OUTPUT="$COMBINED_OUTPUT"
        fi
    fi
fi

SOURCE_MD_FILE="coverage-source-only-${TIMESTAMP}.md"
print_color "$BLUE" "Generating markdown report: $SOURCE_MD_FILE"
generate_markdown_report "$SOURCE_OUTPUT" "$CONTRACTS" "$COVERAGE_FILE" "$TIMESTAMP" "$SOURCE_MD_FILE"
print_color "$GREEN" "✓ Source-only report saved to: $SOURCE_MD_FILE"

# Check if logical coverage files exist and generate report if they do
if check_logical_coverage_exists "$COVERAGE_FILE"; then
    print_color "$BOLD" "\n=== Generating Logical Coverage Report ==="
    # Don't filter by contracts for logical coverage - logical files have different names
    LOGICAL_OUTPUT=$(run_echidna_coverage "$COVERAGE_FILE" "" "$VERBOSE" "$ALL_FLAG" "" "" "yes")
    LOGICAL_MD_FILE="coverage-logical-${TIMESTAMP}.md"
    print_color "$BLUE" "Generating markdown report: $LOGICAL_MD_FILE"
    generate_markdown_report "$LOGICAL_OUTPUT" "" "$COVERAGE_FILE" "$TIMESTAMP" "$LOGICAL_MD_FILE"
    print_color "$GREEN" "✓ Logical coverage report saved to: $LOGICAL_MD_FILE"
else
    print_color "$YELLOW" "\n⚠️  No logicalCoverage files found, skipping logical coverage report"
fi

print_color "$GREEN" "\n${BOLD}Analysis complete!${NC}"
print_color "$CYAN" "Reports generated:"
print_color "$CYAN" "  - $SOURCE_MD_FILE (source coverage)"
if check_logical_coverage_exists "$COVERAGE_FILE"; then
    print_color "$CYAN" "  - $LOGICAL_MD_FILE (logical coverage)"
fi