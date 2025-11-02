#!/usr/bin/env python3
import subprocess
import re
import sys
import argparse
import os

def strip_ansi_codes(text):
    """Remove ANSI color codes from text"""
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)

def run_slither_on_file(file_path):
    """Run slither on a single file and capture its output"""
    try:
        # Read remappings from remappings.txt
        remappings = []
        if os.path.exists('remappings.txt'):
            with open('remappings.txt', 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        remappings.append(line)

        # Build command with remappings
        cmd = ['slither', file_path, '--skip-assembly', '--print', 'entry-points', '--foundry-compile-all']

        # Add each remapping as a separate --solc-remaps argument
        for remap in remappings:
            cmd.extend(['--solc-remaps', remap])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False  # Don't raise on failure, we'll handle it
        )
        
        # Combine stdout and stderr, and strip color codes
        output = strip_ansi_codes(result.stdout + result.stderr)
        
        # Check if it actually failed
        if result.returncode != 0:
            # Check for compilation errors
            if 'Error' in output or 'error' in output:
                return None, output  # Return None and error message
        
        return output, None
    except Exception as e:
        return None, str(e)

def run_slither(path):
    """Run slither and capture its output - backward compatibility"""
    try:
        result = subprocess.run(
            ['slither', path, '--skip-assembly', '--print', 'entry-points'],
            capture_output=True,
            text=True,
            check=True  # This will raise CalledProcessError if slither fails
        )
        # Combine stdout and stderr, and strip color codes
        output = strip_ansi_codes(result.stdout + result.stderr)
        
        # Extract parsing errors for contracts
        parsing_errors = {}
        for line in output.splitlines():
            if line.startswith('ERROR:ContractSolcParsing:'):
                # Extract contract and error info
                match = re.search(r'for (\w+)\.(\w+) \(([^)]+)\):', line)
                if match:
                    contract = match.group(1)
                    function = match.group(2)
                    location = match.group(3)
                    if contract not in parsing_errors:
                        parsing_errors[contract] = []
                    parsing_errors[contract].append(f"{function} at {location}")
        
        # Clean the output by removing unwanted parts and INFO lines
        lines = output.splitlines()
        cleaned_lines = []
        
        for line in lines:
            # Skip INFO lines and forge config lines
            if line.startswith('INFO:') or 'forge config' in line or 'running' in line:
                continue
            cleaned_lines.append(line)
        
        # Get only the relevant lines
        cleaned_output = '\n'.join(cleaned_lines)
        
        # Save cleaned slither output
        os.makedirs('entry-points', exist_ok=True)
        with open(os.path.join('entry-points', 'slither_output.txt'), 'w') as f:
            f.write(cleaned_output)
            
        return output, parsing_errors
    except subprocess.CalledProcessError as e:
        # Get the error message from stderr
        error_msg = strip_ansi_codes(e.stderr)
        print("Slither Analysis Failed!")
        print("This usually means your contracts have compilation errors that need to be fixed first.")
        print("\nError details:")
        print(error_msg)
        sys.exit(1)

def parse_contract_info(output):
    """Parse the slither output into structured data"""
    contracts = {}  # Changed to dict to handle duplicates
    current_contract = None
    inheritance_map = {}  # Track inheritance relationships
    in_table = False
    
    for line in output.split('\n'):
        # Strip any remaining color codes
        line = strip_ansi_codes(line)
        
        if line.startswith('Contract '):
            # Extract contract name and path
            match = re.match(r'Contract ([^\s]+) \(([^)]+)\)', line)
            if match:
                name = match.group(1)
                path_with_line = match.group(2)
                # Extract just the path without line numbers
                path = path_with_line.split('#')[0] if '#' in path_with_line else path_with_line
                # Use contract path as key to prevent duplicates
                if path not in contracts:
                    contracts[path] = {
                        'name': name,
                        'path': path,
                        'inherits': [],
                        'functions': []
                    }
                current_contract = contracts[path]
                in_table = False
        elif '+-------' in line or '| Function' in line:
            # We're in or entering a table
            in_table = True
        elif in_table and line.startswith('|') and current_contract:
            # Parse table row - keep empty columns
            parts = [p.strip() for p in line.split('|')]
            # Filter out just the empty string at beginning and end
            if len(parts) > 0 and parts[0] == '':
                parts = parts[1:]
            if len(parts) > 0 and parts[-1] == '':
                parts = parts[:-1]
            
            if len(parts) >= 3 and parts[0] != 'Function':
                func_name = parts[0].split('(')[0] if '(' in parts[0] else parts[0]
                modifiers = [m.strip() for m in parts[1].split(',') if m.strip()] if parts[1] else []
                # Check for duplicate functions
                if not any(f['name'] == func_name for f in current_contract['functions']):
                    current_contract['functions'].append({
                        'name': func_name,
                        'modifiers': modifiers
                    })
        elif line.strip().startswith('Inherits from:') and current_contract:
            # Extract inheritance information
            inherits = line.replace('Inherits from:', '').strip()
            current_contract['inherits'] = [x.strip() for x in inherits.split(',')]
            # Update inheritance map
            for parent in current_contract['inherits']:
                inheritance_map[parent] = current_contract['name']
        elif line.strip().startswith('- ') and current_contract:
            # Extract function and modifier information (old format support)
            func_info = line.strip()[2:].strip()
            func_name = func_info.split(' ')[0]
            modifiers = []
            if '[' in func_info:
                modifier_str = func_info[func_info.find('[')+1:func_info.find(']')]
                modifiers = [m.strip() for m in modifier_str.split(',')]
            
            # Check for duplicate functions
            if not any(f['name'] == func_name for f in current_contract['functions']):
                current_contract['functions'].append({
                    'name': func_name,
                    'modifiers': modifiers
                })
    
    # Remove parent contracts that have all their functions inherited
    contracts_to_remove = set()
    for path, contract in contracts.items():
        if contract['name'] in inheritance_map:  # If this is a parent contract
            # Get all function names from this contract
            parent_funcs = {f['name'] for f in contract['functions']}
            # Find the child contract
            child_name = inheritance_map[contract['name']]
            child_contract = next((c for c in contracts.values() if c['name'] == child_name), None)
            if child_contract:
                # Get all function names from child contract
                child_funcs = {f['name'] for f in child_contract['functions']}
                # If all parent functions are in child, mark parent for removal
                if parent_funcs.issubset(child_funcs):
                    contracts_to_remove.add(path)
    
    # Remove the marked contracts
    for path in contracts_to_remove:
        del contracts[path]
    
    return list(contracts.values())  # Convert back to list for compatibility

# Removed filter_functions - no longer filtering by modifiers

def write_detailed_output(contracts, output_file):
    """Write detailed output in original format"""
    os.makedirs('entry-points', exist_ok=True)
    output_path = os.path.join('entry-points', output_file)
    
    with open(output_path, 'w') as f:
        # Sort contracts by name for consistent output
        for contract in sorted(contracts, key=lambda x: x['name']):
            f.write(f"Contract {contract['name']} ({contract['path']})\n")
            
            # Check for parsing errors
            if 'parsing_errors' in contract and contract['parsing_errors']:
                f.write("⚠️  PARSING ERRORS:\n")
                for error in contract['parsing_errors']:
                    f.write(f"    - {error}\n")
                if not contract['functions']:
                    f.write("    (No functions could be extracted due to parsing errors)\n")
                f.write("\n")
                continue
            
            # Check for compilation errors
            if 'compilation_error' in contract:
                f.write(f"❌ COMPILATION ERROR: {contract['compilation_error']}\n\n")
                continue
            
            if contract['inherits']:
                f.write(f"Inherits from: {', '.join(contract['inherits'])}\n")
            # Sort functions by name for consistent output
            for func in sorted(contract['functions'], key=lambda x: x['name']):
                modifier_str = f" [{', '.join(func['modifiers'])}]" if func['modifiers'] else ""
                f.write(f"    - {func['name']}{modifier_str}\n")
            f.write("\n")

def write_function_list(contracts, output_file):
    """Write simple function list with modifiers as comments"""
    os.makedirs('entry-points', exist_ok=True)
    output_path = os.path.join('entry-points', output_file)
    
    with open(output_path, 'w') as f:
        # Sort everything for consistent output
        for contract in sorted(contracts, key=lambda x: x['name']):
            if 'compilation_error' in contract:
                f.write(f"# {contract['name']}: COMPILATION ERROR\n")
            elif 'parsing_errors' in contract and contract['parsing_errors'] and not contract['functions']:
                # Add comment for contracts with parsing errors and no functions
                f.write(f"# {contract['name']}: PARSING ERROR - no functions extracted\n")
            else:
                for func in sorted(contract['functions'], key=lambda x: x['name']):
                    modifier_comment = f"  # {', '.join(func['modifiers'])}" if func['modifiers'] else ""
                    f.write(f"{contract['name']}:{func['name']}{modifier_comment}\n")

def generate_entry_points_md(all_contracts, in_scope_contracts, 
                             in_scope_paths, missing_from_scope, parsing_errors):
    """Generate comprehensive ENTRY_POINTS.md file for fuzzing"""
    from datetime import datetime
    
    with open('ENTRY_POINTS.md', 'w') as f:
        # Header
        f.write("# Fuzzing Entry Points\n\n")
        f.write(f"*Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n")
        
        # Executive Summary
        f.write("## Executive Summary\n\n")
        
        total_contracts = len(all_contracts)
        total_functions = sum(len(c['functions']) for c in all_contracts)
        contracts_with_errors = len([c for c in all_contracts if 'parsing_errors' in c and c['parsing_errors']])
        contracts_with_compilation_errors = len([c for c in all_contracts if 'compilation_error' in c])
        
        f.write(f"- **Total Contracts Found**: {total_contracts}\n")
        f.write(f"- **Total Functions Extracted**: {total_functions}\n")
        f.write(f"- **Contracts with Parsing Errors**: {contracts_with_errors}\n")
        f.write(f"- **Contracts with Compilation Errors**: {contracts_with_compilation_errors}\n\n")
        
        # Scope Analysis
        if in_scope_contracts is not None:
            f.write("## Scope Analysis\n\n")
            f.write(f"- **Contracts in scope.csv**: {len(in_scope_paths) if in_scope_paths else 0}\n")
            f.write(f"- **Contracts Found & In Scope**: {len([c for c in in_scope_contracts if not ('parsing_errors' in c and c['parsing_errors'] and not c['functions']) and 'compilation_error' not in c])}\n")
            f.write(f"- **Missing from Analysis**: {len(missing_from_scope)}\n\n")
            
            if missing_from_scope:
                f.write("### Missing Contracts\n\n")
                f.write("These contracts are in scope.csv but were not found by slither:\n\n")
                for path in sorted(missing_from_scope):
                    f.write(f"- `{path}`\n")
                f.write("\n*Note: Libraries typically don't have entry points, and some contracts may not exist.*\n\n")
        
        # Contracts with Errors
        if contracts_with_errors > 0 or contracts_with_compilation_errors > 0:
            f.write("## ⚠️ Contracts with Errors\n\n")
            
            if contracts_with_compilation_errors > 0:
                f.write("### Compilation Errors\n\n")
                for contract in sorted(all_contracts, key=lambda x: x['name']):
                    if 'compilation_error' in contract:
                        f.write(f"- **{contract['name']}** (`{contract['path']}`): {contract['compilation_error']}\n")
                f.write("\n")
            
            if contracts_with_errors > 0:
                f.write("### Parsing Errors\n\n")
                f.write("These contracts had parsing issues but may still have valuable functions to fuzz:\n\n")
                
                for contract in sorted(all_contracts, key=lambda x: x['name']):
                    if 'parsing_errors' in contract and contract['parsing_errors']:
                        f.write(f"#### {contract['name']}\n")
                        f.write(f"- **Path**: `{contract['path']}`\n")
                        f.write(f"- **Functions Successfully Extracted**: {len(contract['functions'])}\n")
                        f.write("- **Failed to Parse**:\n")
                        for error in contract['parsing_errors']:
                            f.write(f"  - {error}\n")
                        f.write("\n")
        
        # All Entry Points for Fuzzing
        f.write("## 🎯 Entry Points for Fuzzing\n\n")
        f.write("All public/external functions (modifiers shown as comments):\n\n")
        
        # Group by contract type
        core_contracts = []
        component_contracts = []
        utility_contracts = []
        
        for contract in all_contracts:
            if 'parsing_errors' not in contract or not contract['parsing_errors'] or contract['functions']:
                if 'components' in contract['path']:
                    component_contracts.append(contract)
                elif 'utils' in contract['path'] or 'libraries' in contract['path']:
                    utility_contracts.append(contract)
                else:
                    core_contracts.append(contract)
        
        if core_contracts:
            f.write("### Core Contracts\n\n")
            for contract in sorted(core_contracts, key=lambda x: x['name']):
                if contract['functions']:
                    f.write(f"#### {contract['name']}\n")
                    f.write(f"*Path: `{contract['path']}`*\n\n")
                    f.write("```solidity\n")
                    for func in sorted(contract['functions'], key=lambda x: x['name']):
                        modifiers = f" // {', '.join(func['modifiers'])}" if func['modifiers'] else ""
                        f.write(f"{func['name']}(){modifiers}\n")
                    f.write("```\n\n")
        
        if component_contracts:
            f.write("### Component Contracts\n\n")
            for contract in sorted(component_contracts, key=lambda x: x['name']):
                if contract['functions']:
                    f.write(f"#### {contract['name']}\n")
                    f.write(f"*Path: `{contract['path']}`*\n\n")
                    f.write("```solidity\n")
                    for func in sorted(contract['functions'], key=lambda x: x['name']):
                        modifiers = f" // {', '.join(func['modifiers'])}" if func['modifiers'] else ""
                        f.write(f"{func['name']}(){modifiers}\n")
                    f.write("```\n\n")
        
        # All Functions List
        f.write("## Complete Function List\n\n")
        f.write("### Format for Fuzzing Tools\n\n")
        f.write("Copy this list directly into your fuzzing configuration:\n\n")
        f.write("```\n")
        for contract in sorted(all_contracts, key=lambda x: x['name']):
            if 'compilation_error' not in contract:
                for func in sorted(contract['functions'], key=lambda x: x['name']):
                    modifier_comment = f"  # {', '.join(func['modifiers'])}" if func['modifiers'] else ""
                    f.write(f"{contract['name']}:{func['name']}{modifier_comment}\n")
        f.write("```\n\n")
        
        # Functions by Access Level
        f.write("## Functions by Access Level\n\n")
        
        # Collect functions by modifier
        public_functions = []
        payable_functions = []
        restricted_functions = []
        
        for contract in all_contracts:
            for func in contract['functions']:
                entry = f"{contract['name']}.{func['name']}"
                if not func['modifiers']:
                    public_functions.append(entry)
                elif 'payable' in func['modifiers']:
                    payable_functions.append(entry)
                else:
                    restricted_functions.append((entry, func['modifiers']))
        
        f.write(f"### Public Functions (No Modifiers) - {len(public_functions)} total\n\n")
        if public_functions:
            f.write("These are the primary targets for fuzzing:\n\n")
            for func in sorted(public_functions):
                f.write(f"- `{func}`\n")
            f.write("\n")
        
        f.write(f"### Payable Functions - {len(payable_functions)} total\n\n")
        if payable_functions:
            f.write("These functions can receive ETH:\n\n")
            for func in sorted(payable_functions):
                f.write(f"- `{func}`\n")
            f.write("\n")
        
        f.write(f"### Restricted Functions - {len(restricted_functions)} total\n\n")
        if restricted_functions:
            f.write("These require special permissions:\n\n")
            for func, mods in sorted(restricted_functions):
                f.write(f"- `{func}` [{', '.join(mods)}]\n")
            f.write("\n")
        
        # Fuzzing Configuration Example
        f.write("## Fuzzing Configuration Example\n\n")
        f.write("### Echidna Configuration\n\n")
        f.write("```yaml\n")
        f.write("# echidna.yaml\n")
        f.write("testMode: assertion\n")
        f.write("multi-abi: true\n")
        f.write("corpusDir: \"echidna-corpus\"\n")
        f.write("coverage: true\n\n")
        f.write("# Contracts to test\n")
        f.write("contracts:\n")
        for contract in sorted(all_contracts, key=lambda x: x['name']):
            if contract['functions'] and 'compilation_error' not in contract:
                f.write(f"  - {contract['name']}\n")
        f.write("```\n\n")
        
        # Footer
        f.write("## Notes\n\n")
        f.write("- Functions with access control modifiers are included with modifiers shown as comments\n")
        f.write("- Contracts with parsing errors may still contain valid functions that can be fuzzed\n")
        f.write("- Contracts with compilation errors need to be fixed before fuzzing\n")
        f.write("- Libraries are typically not fuzzed directly as they contain internal functions\n")
        f.write("- Focus fuzzing efforts on functions that handle user funds, state changes, or critical logic\n\n")
        f.write("---\n")
        f.write("*Generated by entryPoints.py*\n")

def write_all_outputs(all_contracts, in_scope_contracts=None):
    """Write all output files"""
    # Write outputs (all contracts, all functions)
    write_detailed_output(all_contracts, 'all_contracts.txt')
    write_function_list(all_contracts, 'all_functions.txt')
    
    # If scope filtering was applied, write in-scope versions
    if in_scope_contracts is not None:
        write_detailed_output(in_scope_contracts, 'in_scope_contracts.txt')
        write_function_list(in_scope_contracts, 'in_scope_functions.txt')

def collect_all_modifiers(contracts):
    """Collect all unique modifiers from all contracts"""
    all_modifiers = set()
    for contract in contracts:
        for func in contract['functions']:
            all_modifiers.update(func['modifiers'])
    return sorted(list(all_modifiers))

def normalize_path(path):
    """Normalize a path by finding the common Solidity file structure"""
    # Split path into components
    parts = path.replace('\\', '/').split('/')
    
    # Find where the Solidity path structure starts (src/, contracts/, lib/, etc.)
    common_roots = ['src', 'contracts', 'lib', 'libraries', 'components', 'utils', 'test']
    
    for i, part in enumerate(parts):
        if part in common_roots:
            # Return path starting from this common root
            return '/'.join(parts[i:])
    
    # If no common root found, try to find .sol file and work backwards
    for i in range(len(parts) - 1, -1, -1):
        if parts[i].endswith('.sol'):
            # Find the nearest src-like directory before this
            for j in range(i - 1, -1, -1):
                if parts[j] in common_roots:
                    return '/'.join(parts[j:i+1])
            # If no common root, just return the filename with immediate parent
            if i > 0:
                return '/'.join(parts[i-1:i+1])
            return parts[i]
    
    # Fallback: return as-is
    return path

def read_scope_csv(scope_file):
    """Read scope.csv and return set of normalized in-scope contract file paths"""
    in_scope = set()
    try:
        with open(scope_file, 'r') as f:
            # Skip header
            next(f)
            for line in f:
                if line.strip() and not line.startswith('source count:'):
                    # Get the full contract path from the first column
                    parts = line.split(',')
                    if len(parts) >= 1:
                        contract_path = parts[0].strip()
                        # Skip lines that don't look like file paths
                        if not contract_path.endswith('.sol'):
                            continue
                        # Normalize the path
                        normalized = normalize_path(contract_path)
                        in_scope.add(normalized)
    except FileNotFoundError:
        print("Warning: scope.csv not found. All contracts will be considered in scope.")
        return None
    return in_scope

def filter_contracts_by_scope(contracts, in_scope):
    """Filter contracts based on scope.csv"""
    if in_scope is None:
        return contracts, []

    in_scope_contracts = []
    filtered_out = []
    
    for contract in contracts:
        # Normalize the contract path from slither output
        contract_path = normalize_path(contract['path'])
        if contract_path in in_scope:
            in_scope_contracts.append(contract)
        else:
            filtered_out.append(contract)
    
    return in_scope_contracts, filtered_out

def process_contracts_individually(scope_file='scope.csv'):
    """Process each contract from scope.csv individually"""
    all_contracts = []
    all_parsing_errors = {}
    failed_contracts = []
    
    # Read scope.csv to get contract paths
    try:
        with open(scope_file, 'r') as f:
            # Skip header
            next(f)
            contract_paths = []
            for line in f:
                if line.strip() and not line.startswith('source count:'):
                    parts = line.split(',')
                    if len(parts) >= 1:
                        contract_path = parts[0].strip()
                        if contract_path.endswith('.sol'):
                            contract_paths.append(contract_path)
    except FileNotFoundError:
        return None, None, None  # No scope file
    
    print(f"📋 Found {len(contract_paths)} contracts in scope.csv")
    print("🔍 Analyzing contracts individually...")
    
    # Process each contract individually
    for i, contract_path in enumerate(contract_paths, 1):
        # Remove any prefix like 'mercury/' to get actual file path
        actual_path = contract_path
        if contract_path.startswith('mercury/'):
            actual_path = contract_path[8:]
        
        print(f"  [{i}/{len(contract_paths)}] Processing {actual_path}...", end=' ')
        
        # Check if file exists
        if not os.path.exists(actual_path):
            print("❌ File not found")
            failed_contracts.append((actual_path, "File not found"))
            continue
        
        # Run slither on this single file
        output, error = run_slither_on_file(actual_path)
        
        if output is None:
            print("⚠️  Failed")
            failed_contracts.append((actual_path, error or "Unknown error"))
            continue
        
        # Parse the output for this contract
        contracts_from_file = parse_contract_info(output)
        
        # Extract parsing errors for this file
        for line in output.splitlines():
            if line.startswith('ERROR:ContractSolcParsing:'):
                match = re.search(r'for (\w+)\.(\w+) \(([^)]+)\):', line)
                if match:
                    contract_name = match.group(1)
                    function = match.group(2)
                    location = match.group(3)
                    if contract_name not in all_parsing_errors:
                        all_parsing_errors[contract_name] = []
                    all_parsing_errors[contract_name].append(f"{function} at {location}")
        
        # Add to our collection
        for contract in contracts_from_file:
            # Avoid duplicates
            if not any(c['name'] == contract['name'] and c['path'] == contract['path'] for c in all_contracts):
                all_contracts.append(contract)
        
        print(f"✅ Found {len(contracts_from_file)} contract(s)")
    
    # Add parsing errors to contracts
    for contract in all_contracts:
        if contract['name'] in all_parsing_errors:
            contract['parsing_errors'] = all_parsing_errors[contract['name']]
    
    # Add completely failed contracts as entries with errors
    for path, error in failed_contracts:
        contract_name = path.split('/')[-1].replace('.sol', '')
        if not any(c['name'] == contract_name for c in all_contracts):
            all_contracts.append({
                'name': contract_name,
                'path': path,
                'inherits': [],
                'functions': [],
                'compilation_error': error
            })
    
    return all_contracts, all_parsing_errors, failed_contracts

def main():
    parser = argparse.ArgumentParser(
        description='Extract and analyze Solidity contract entry points for fuzzing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 entryPoints.py                    # Analyze contracts from scope.csv individually
  python3 entryPoints.py --all              # Analyze entire directory at once
  python3 entryPoints.py --no-scope         # Process all contracts, not just scope.csv
  python3 entryPoints.py --debug-paths      # Show path debugging
        """
    )
    parser.add_argument('--all', action='store_true',
                       help='Analyze entire directory at once (old behavior)')
    parser.add_argument('--path', default='.', 
                       help='Path to analyze when using --all (default: current directory)')
    # Removed blacklist and filtering options since we no longer filter
    parser.add_argument('--no-scope', action='store_true',
                       help='Disable filtering based on scope.csv')
    parser.add_argument('--scope-file', default='scope.csv',
                       help='Path to scope.csv file (default: scope.csv)')
    parser.add_argument('--debug-paths', action='store_true',
                       help='Show path normalization details for debugging')
    args = parser.parse_args()
    
    # Set defaults
    args.filter_scope = not args.no_scope

    # Decide whether to use individual processing or batch processing
    if args.all or args.no_scope:
        # Old behavior - process entire directory
        print(f"🔍 Analyzing all contracts in: {args.path}")
        slither_output, parsing_errors = run_slither(args.path)
        
        # Parse the output
        contracts = parse_contract_info(slither_output)
        
        # Add contracts with parsing errors to the list
        for contract_name, errors in parsing_errors.items():
            # Check if this contract already exists (partial parse)
            contract_exists = False
            for c in contracts:
                if c['name'] == contract_name:
                    # Add error note to existing contract
                    c['parsing_errors'] = errors
                    contract_exists = True
                    break
            
            if not contract_exists:
                # Create a new entry for contracts that completely failed to parse
                contract_path = f"src/components/{contract_name}.sol"  # Default guess
                
                contracts.append({
                    'name': contract_name,
                    'path': contract_path,
                    'inherits': [],
                    'functions': [],
                    'parsing_errors': errors
                })
    else:
        # New behavior - process contracts individually from scope.csv
        contracts, parsing_errors, failed_contracts = process_contracts_individually(args.scope_file)
        
        if contracts is None:
            print(f"❌ Could not find {args.scope_file}")
            print("Use --all flag to analyze entire directory instead")
            sys.exit(1)
    
    # Now continue with the rest of the processing...
    in_scope = None
    contracts_to_process = contracts
    filtered_out_contracts = []
    
    # Filter by scope only if --filter-scope is enabled and we're using --all mode
    if args.filter_scope and args.all:
        in_scope = read_scope_csv(args.scope_file)
        
        if args.debug_paths and in_scope:
            print("\nNormalized paths from scope.csv:")
            for path in sorted(in_scope):
                print(f"  - {path}")
            
            print("\nNormalized paths from slither output:")
            for contract in contracts:
                normalized = normalize_path(contract['path'])
                print(f"  - {contract['path']:40} -> {normalized}")
        
        contracts_to_process, filtered_out_contracts = filter_contracts_by_scope(contracts, in_scope)
        
        # Check which scope contracts were not found
        if in_scope:
            found_paths = {normalize_path(c['path']) for c in contracts}
            missing = in_scope - found_paths
            if missing:
                print(f"\n⚠️  WARNING: {len(missing)} contracts from scope.csv were not found by slither:")
                for path in sorted(missing):
                    print(f"  - {path}")
                print("\nThis might be because:")
                print("  1. They are libraries (slither may not show entry points for libraries)")
                print("  2. They have no public/external functions")
                print("  3. The path to slither needs to include these files")
    
    # Collect all modifiers for display purposes
    all_modifiers = collect_all_modifiers(contracts_to_process)
    
    # Write all output files
    write_all_outputs(
        all_contracts=contracts,  # All contracts found by slither
        in_scope_contracts=contracts_to_process if args.filter_scope else None  # In-scope contracts only
    )
    
    # Generate comprehensive ENTRY_POINTS.md
    missing = set()
    if args.filter_scope and in_scope:
        found_paths = {normalize_path(c['path']) for c in contracts}
        missing = in_scope - found_paths
    elif not args.all:
        # When using individual processing, check what wasn't found
        in_scope = read_scope_csv(args.scope_file)
        if in_scope:
            found_paths = {normalize_path(c['path']) for c in contracts if 'compilation_error' not in c}
            missing = in_scope - found_paths
    
    generate_entry_points_md(
        all_contracts=contracts,
        in_scope_contracts=contracts_to_process if args.filter_scope or not args.all else None,
        in_scope_paths=in_scope if args.filter_scope or not args.all else None,
        missing_from_scope=missing,
        parsing_errors=parsing_errors if args.all else {}
    )
    
    # Only show detailed output if debug mode is enabled
    if args.debug_paths:
        if args.filter_scope and filtered_out_contracts:
            print("\nOut of scope contracts:")
            for contract in filtered_out_contracts:
                print(f"  - {contract['name']} ({contract['path']})")
        
        print("\nAll modifiers found in contracts:")
        for modifier in all_modifiers:
            print(f"  - {modifier}")
    
    # Summary statistics
    total_contracts = len(contracts)
    total_functions = sum(len(c['functions']) for c in contracts)
    contracts_with_errors = len([c for c in contracts if ('parsing_errors' in c and c['parsing_errors']) or 'compilation_error' in c])
    
    print(f"\n✅ Analysis complete!")
    print(f"   Found {total_contracts} contracts with {total_functions} functions")
    if contracts_with_errors > 0:
        print(f"   ⚠️  {contracts_with_errors} contracts had errors but were included")
    
    print(f"\n📄 Generated ENTRY_POINTS.md - Open this file for complete fuzzing guide!")
    print(f"📁 Additional outputs in entry-points/ directory")

if __name__ == "__main__":
    main()