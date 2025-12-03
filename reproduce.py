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
Fuzz.fuzz_digiftVerifier_verifySettlement(66789952563948851355765265112455361326113396018918499384071048604564371756589,true) from: 0x0000000000000000000000000000000000020000 Time delay: 122561 seconds Block delay: 597
Fuzz.fuzz_admin_router4626_fulfillRedeem(93333165660724026140854228958950909481437266217616969945574837740031701939268,21517554274178530701529943736507416601626662916718595343127117094703543494777) from: 0x0000000000000000000000000000000000010000 Time delay: 221284 seconds Block delay: 32737
Fuzz.fuzz_fluid_claimRewards(3593387767952180378708,113805589326127936323483208052975627636647530549319527992829552479637292204948,62756768008518638017956441344567215022398907580289259684325878153186069926307) from: 0x0000000000000000000000000000000000030000 Time delay: 303345 seconds Block delay: 38100
Fuzz.fuzz_node_transfer(1079202855827023111070669,24904450688562578922737175560295478802120744299785566249898863264346645926871) from: 0x0000000000000000000000000000000000020000 Time delay: 478926 seconds Block delay: 12053
Fuzz._decodeErrorMessage("Y\147\147\147\147\147\147\147\147\STX#d\GSmj") from: 0x0000000000000000000000000000000000020000 Time delay: 344203 seconds Block delay: 23086
Fuzz.fuzz_admin_pool_processPendingDeposits(17399535706538088937451214908079286048055627020161171101560748984087627954027) from: 0x0000000000000000000000000000000000010000 Time delay: 417866 seconds Block delay: 15369
Fuzz.managedNodeCountForTest() from: 0x0000000000000000000000000000000000010000 Time delay: 168589 seconds Block delay: 1123
Fuzz.fuzz_component_gainBacking(75110384599907480584415325048506288726930977753524214986838688444431266310159,16969347000000000000000000) from: 0x0000000000000000000000000000000000030000 Time delay: 384960 seconds Block delay: 42101
Fuzz.fuzz_admin_router7540_executeAsyncWithdrawal(113856994541932127288816646379672942438010156797627610908509240953279089791393,26270462142940313606487047060592747924231601075003369620379167708134329739304) from: 0x0000000000000000000000000000000000020000 Time delay: 82670 seconds Block delay: 2727
"""

    solidity_code = convert_to_solidity(call_sequence)
    print(solidity_code)
