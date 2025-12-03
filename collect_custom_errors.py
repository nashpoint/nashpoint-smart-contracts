#!/usr/bin/env python3
import os
import re
import argparse
from pathlib import Path
import logging
from eth_utils import keccak

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def extract_custom_errors(file_path):
    errors = []
    contract_name = None
    
    logging.info(f"Processing file: {file_path}")
    
    with open(file_path, 'r') as f:
        content = f.read()
        
        # Extract contract name - look for the first contract declaration
        contract_match = re.search(r'contract\s+(\w+)', content)
        if contract_match:
            contract_name = contract_match.group(1)
            logging.info(f"Found contract: {contract_name}")

        # Extract interface name - look for the first interface declaration
        interface_match = re.search(r'interface\s+(\w+)', content)
        if interface_match:
            contract_name = interface_match.group(1)
            logging.info(f"Found interface: {contract_name}")

        # Extract library name - look for the first library declaration
        library_match = re.search(r'library\s+(\w+)', content)
        if library_match:
            contract_name = library_match.group(1)
            logging.info(f"Found library: {contract_name}")
            
        # Find all error declarations
        error_matches = re.finditer(r'error\s+(\w+)[\s]*\(([^)]*)\)', content)
        
        for match in error_matches:
            error_name = match.group(1)
            error_params = match.group(2).strip()
            if contract_name:
                errors.append((contract_name, error_name, error_params))
                logging.info(f"Found error: {contract_name}.{error_name}({error_params})")
    return errors

def generate_error_selectors(source_dir):
    all_errors = []
    logging.info(f"Scanning directory: {source_dir}")
    source_path = Path(source_dir)
    if not source_path.exists():
        logging.error(f"Source directory does not exist: {source_dir}")
        return all_errors
    for file_path in source_path.rglob('*.sol'):
        try:
            errors = extract_custom_errors(file_path)
            if errors:
                logging.info(f"Found {len(errors)} errors in {file_path}")
            all_errors.extend(errors)
        except Exception as e:
            logging.error(f"Error processing {file_path}: {str(e)}")
    logging.info(f"Total errors found: {len(all_errors)}")
    return all_errors

def calculate_error_selector(error_name, error_params=""):
    # Only parameter types, not names
    if error_params.strip():
        param_types = []
        for param in error_params.split(','):
            param = param.strip()
            if not param:
                continue
            # Extract just the type part (before the parameter name)
            if ' ' in param:
                param_type = param.split(' ')[0].strip()
            else:
                param_type = param.strip()
            param_types.append(param_type)
        error_signature = f"{error_name}({','.join(param_types)})"
    else:
        error_signature = f"{error_name}()"
    selector = keccak(text=error_signature)[:4].hex()
    return f"0x{selector}"

def generate_properties_code(errors):
    logging.info("Generating properties code")
    if not errors:
        code = []
        code.append("    function _getAllowedCustomErrors() internal pure virtual override returns (bytes4[] memory) {")
        code.append("        bytes4[] memory allowedErrors = new bytes4[](0);")
        code.append("        return allowedErrors;")
        code.append("    }")
        return "\n".join(code)
    code = []
    code.append(f"    function _getAllowedCustomErrors() internal pure virtual override returns (bytes4[] memory) {{")
    code.append(f"        bytes4[] memory allowedErrors = new bytes4[]({len(errors)});")
    for i, (contract, error, params) in enumerate(errors):
        selector = calculate_error_selector(error, params)
        # Create single-line comment with error signature
        error_signature = f"{error}({params})" if params.strip() else f"{error}()"
        # Ensure the comment is single-line by replacing newlines with spaces
        error_signature = error_signature.replace('\n', ' ').replace('        ', ' ')
        code.append(f"        allowedErrors[{i}] = {selector}; // {contract}.{error_signature}")
    code.append("        return allowedErrors;")
    code.append("    }")
    return "\n".join(code)

def update_properties_file(properties_path, new_code):
    try:
        # Read existing file content
        with open(properties_path, 'r') as f:
            content = f.read()
        
        # Replace the function content
        new_content = re.sub(
            r'function _getAllowedCustomErrors\(\)[^}]*}',
            new_code,
            content,
            flags=re.DOTALL
        )
        
        # Write back to file
        with open(properties_path, 'w') as f:
            f.write(new_content)
        
        logging.info(f"Successfully updated {properties_path}")
        return True
    except Exception as e:
        logging.error(f"Error updating Properties_ERR.sol: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Extract custom errors from Solidity files and update Properties_ERR.sol')
    parser.add_argument('source_dir', help='Source directory containing .sol files')
    parser.add_argument('--properties-file', default='test/fuzzing/properties/Properties_ERR.sol', 
                       help='Path to Properties_ERR.sol file (default: test/fuzzing/properties/Properties_ERR.sol)')
    
    args = parser.parse_args()
    
    logging.info("Starting error collection process")
    logging.info(f"Source directory: {args.source_dir}")
    logging.info(f"Properties file: {args.properties_file}")
    
    # Validate source directory
    if not os.path.exists(args.source_dir):
        logging.error(f"Source directory does not exist: {args.source_dir}")
        return
    
    # Collect all errors
    errors = generate_error_selectors(args.source_dir)
    
    if not errors:
        logging.warning("No errors found in any source files")
        # Still update the file with empty array
        properties_code = generate_properties_code(errors)
        update_properties_file(args.properties_file, properties_code)
        return
    
    # Generate the code
    properties_code = generate_properties_code(errors)
    
    # Update Properties_ERR.sol
    success = update_properties_file(args.properties_file, properties_code)
    
    if success:
        logging.info("Process completed successfully")
    else:
        logging.error("Process failed")

if __name__ == "__main__":
    main()