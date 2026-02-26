import re
import sys
from pathlib import Path

# Add the fuzz_scripts directory to the path so we can import bytesEncoding
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

from bytesEncoding import parse_echidna_byte_string


def process_bytes_parameters(call):
    """
    Detects and converts bytes parameters from Echidna format to Solidity hex format.
    Example: "\175\214\221..." -> hex"7d8c919e..."
    """
    # Pattern to match quoted strings that likely contain bytes (have escape sequences)
    bytes_pattern = re.compile(r'"([^"]*(?:\\[0-9]{1,3}|\\[a-zA-Z]{2,3})[^"]*)"')

    def replace_bytes(match):
        echidna_bytes = match.group(1)
        # Check if this looks like a bytes string (contains escape sequences)
        if '\\' in echidna_bytes:
            # Convert using the bytesEncoding parser
            hex_string = parse_echidna_byte_string(echidna_bytes, isBytes=True)
            return f'hex"{hex_string}"'
        else:
            # Regular string, keep as is
            return match.group(0)

    return bytes_pattern.sub(replace_bytes, call)


def extract_function_call(line):
    """
    Extracts function call from a line, properly handling nested parentheses and quotes.
    Returns (function_call, remainder) where remainder contains metadata like 'from:', 'Gas:', etc.
    """
    # Find the function name
    match = re.match(r'(?:Fuzz\.)?(\w+)\(', line)
    if not match:
        return None, line

    func_name = match.group(1)
    start_pos = match.end() - 1  # Position of opening '('

    # Count parentheses to find the matching close, respecting quotes
    paren_count = 0
    in_string = False
    escape_next = False
    i = start_pos

    while i < len(line):
        char = line[i]

        if escape_next:
            escape_next = False
            i += 1
            continue

        if char == '\\':
            escape_next = True
            i += 1
            continue

        if char == '"' and not escape_next:
            in_string = not in_string

        if not in_string:
            if char == '(':
                paren_count += 1
            elif char == ')':
                paren_count -= 1
                if paren_count == 0:
                    # Found the matching closing parenthesis
                    function_call = line[match.start():i+1]
                    remainder = line[i+1:].strip()
                    return function_call, remainder

        i += 1

    # If we get here, parentheses weren't balanced
    return line, ""


def convert_to_solidity(call_sequence):
    # Regex patterns to extract metadata
    from_pattern = re.compile(r'from: (0x[0-9a-fA-F]{40})')
    gas_pattern = re.compile(r'Gas: (\d+)')
    time_pattern = re.compile(r'Time delay: (\d+) seconds')
    block_pattern = re.compile(r'Block delay: (\d+)')
    wait_pattern = re.compile(
        r"\*wait\*(?: Time delay: (\d+) seconds)?(?: Block delay: (\d+))?"
    )

    solidity_code = "function test_replay() public {\n"

    lines = call_sequence.strip().split("\n")
    last_index = len(lines) - 1

    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue

        wait_match = wait_pattern.search(line)
        if wait_match:
            time_delay, block_delay = wait_match.groups()

            # Add warp line if time delay exists
            if time_delay:
                solidity_code += f"    vm.warp(block.timestamp + {time_delay});\n"

            # Add roll line if block delay exists
            if block_delay:
                solidity_code += f"    vm.roll(block.number + {block_delay});\n"
            solidity_code += "\n"
        else:
            # Try to extract function call
            call, remainder = extract_function_call(line)
            if call is None:
                continue

            # Extract metadata from remainder
            from_match = from_pattern.search(remainder)
            time_match = time_pattern.search(remainder)
            block_match = block_pattern.search(remainder)

            from_addr = from_match.group(1) if from_match else None
            time_delay = time_match.group(1) if time_match else None
            block_delay = block_match.group(1) if block_match else None

            # Add prank line if from address exists
            if from_addr:
                solidity_code += f'    vm.prank({from_addr});\n'

            # Add warp line if time delay exists
            if time_delay:
                solidity_code += f"    vm.warp(block.timestamp + {time_delay});\n"

            # Add roll line if block delay exists
            if block_delay:
                solidity_code += f"    vm.roll(block.number + {block_delay});\n"

            if "collateralToMarketId" in call:
                continue

            # Process bytes parameters in the call
            processed_call = process_bytes_parameters(call)

            # Remove "Fuzz." prefix if present since we're using "this."
            processed_call = processed_call.replace("Fuzz.", "", 1)

            # Add function call
            if i < last_index:
                solidity_code += f"    try this.{processed_call} {{}} catch {{}}\n"
            else:
                solidity_code += f"    this.{processed_call};\n"
            solidity_code += "\n"

    solidity_code += "}\n"

    return solidity_code


# Example usage
if __name__ == "__main__":
    # Example with bytes parameter - use raw string to preserve escape sequences
    call_sequence = r"""
     Fuzz.fuzz_admin_router7540_requestAsyncWithdrawal(14,5730368980593473517993357088859897993824186957866074460861780541009729) Time delay: 38812 seconds Block delay: 1311
    Fuzz.fuzz_nodeFactory_deploy(10265290076423423503028079841577509) Time delay: 155762 seconds Block delay: 3831
    Fuzz.fuzz_admin_router4626_fulfillRedeem(0,2638702189470576954110488490047429034450789146904735057077346052267251) Time delay: 84407 seconds Block delay: 82
    *wait* Time delay: 704048 seconds Block delay: 6787
    Fuzz.fuzz_admin_router4626_invest(47935887152536069481082275843447797632028023738438158036371357448487,0) Time delay: 281447 seconds Block delay: 51
    *wait* Time delay: 879056 seconds Block delay: 256
    Fuzz.fuzz_nodeFactory_deploy(1479769577680151612458) Time delay: 181044 seconds Block delay: 620
    Fuzz.fuzz_guided_router7540_partialFulfill(620631629,88413234331484132997008647418833313295268236935015778846153584762159627300818,35570013827703777209363147555006974419692338111375169905865258821392650407739) Time delay: 278 seconds Block delay: 6
    Fuzz.fuzz_guided_router7540_partialFulfill(1524785993,88413234331484132997008647418833313295268236935015778846153584762159627300818,35570013827703777209363147555006974419692338111375169905865258821392650407739) Time delay: 278 seconds Block delay: 3502
    Fuzz.fuzz_guided_router7540_partialFulfill(1200838692,2839450081872440204713834383407183015385388242122324031517635292566017560,64707384642309961966858897588864101318662319758480929035637226780946555) Time delay: 278 seconds Block delay: 304
    Fuzz.fuzz_guided_router7540_partialFulfill(1524785993,64418085078740830810434874078236041191867608210503500787466507120233234985286,35570013827703777209363147555006974419692338111375169905865258821392650407739) Time delay: 278 seconds Block delay: 4886

"""

    solidity_code = convert_to_solidity(call_sequence)
    print(solidity_code)
