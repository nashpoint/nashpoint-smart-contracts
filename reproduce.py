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
    call_sequence = r"""  Fuzz.fuzz_admin_node_fulfillRedeem(1526830170) from: 0x0000000000000000000000000000000000010000 Gas: 1000000000 Time delay: 600 seconds Block delay: 3443
    Fuzz.fuzz_guided_router7540_partialFulfill(16291307587688378201203550058243142548441332259459641589145790223581105212446,1524785992,88547664097770406600145745129933251194640394409877110105192465151007363328472) from: 0x0000000000000000000000000000000000020000 Gas: 1000000000 Time delay: 327 seconds Block delay: 6344
    *wait* Time delay: 471024 seconds Block delay: 2648
    Fuzz.fuzz_guided_router7540_fulfillRedeem(41370147849573675512070856522738441685347019102720815941645984476719001761023,946,706056179871158743800599) from: 0x0000000000000000000000000000000000030000 Gas: 1000000000 Time delay: 640 seconds Block delay: 14589
    *wait* Time delay: 291198 seconds Block delay: 48399
    Fuzz.fuzz_node_multicall(67785160700922852634094) from: 0x0000000000000000000000000000000000010000 Gas: 1000000000 Time delay: 82670 seconds Block delay: 16923
    Fuzz.fuzz_component_loseBacking(114916587389629795224913414826804211219420736061723329320821680044317126230770,141972508614623265525) from: 0x0000000000000000000000000000000000010000 Gas: 1000000000 Time delay: 345927 seconds Block delay: 55373
    *wait* Time delay: 255795 seconds Block delay: 53229
    Fuzz.fuzz_admin_router7540_fulfillRedeemRequest(4949165054795372511601318721434963626949001616614414128497513514893970621283,130878365475335428770072) from: 0x0000000000000000000000000000000000030000 Gas: 1000000000 Time delay: 80123 seconds Block delay: 56911
    Fuzz.fuzz_fluid_claimRewards(2497972194246591634529951508234501,108932718952309497644658,18235185267968406577485360957595155360445584202970442671824733857237851547229) from: 0x0000000000000000000000000000000000030000 Gas: 1000000000 Time delay: 478923 seconds Block delay: 11056
    Fuzz.fuzz_admin_router4626_invest(100754063201821661874,1527411862) from: 0x0000000000000000000000000000000000030000 Gas: 1000000000 Time delay: 244428 seconds Block delay: 35529
    *wait* Time delay: 195123 seconds Block delay: 2820
    Fuzz.fuzz_mint(115792089237316195423570985008687907853269984665640564039457584007913129639932) from: 0x0000000000000000000000000000000000020000 Time delay: 33605 seconds Block delay: 32409
    Fuzz.fuzz_admin_router7540_requestAsyncWithdrawal(11522943855907076227,1726473206793072886159) from: 0x0000000000000000000000000000000000030000 Time delay: 211230 seconds Block delay: 43436
    Fuzz.fuzz_digift_transfer(66146269806625728852338662478512012720621940921687826357067986896852949434068,115792089237316195423570985008687907853269984665640564039457584007913129639933) from: 0x0000000000000000000000000000000000030000 Time delay: 476642 seconds Block delay: 35520
    *wait* Time delay: 399105 seconds Block delay: 4919
    Fuzz.fuzz_fluid_claimRewards(97819168031214501634960653214678104806461584724980310976426994550154868368719,1526346305,28779111860170626404802165904129910542662261651411685705360478879764721209028) from: 0x0000000000000000000000000000000000010000 Time delay: 141378 seconds Block delay: 1362
    *wait* Time delay: 271957 seconds Block delay: 14447
    Fuzz.fuzz_admin_router4626_fulfillRedeem(33099298396579037838359841905872859527822997875199706559685446095298510898972,32) from: 0x0000000000000000000000000000000000020000 Time delay: 22809 seconds Block delay: 5032
    Fuzz.fuzz_node_multicall(9863618461268189806024) from: 0x0000000000000000000000000000000000020000 Time delay: 174585 seconds Block delay: 30623

"""

    solidity_code = convert_to_solidity(call_sequence)
    print(solidity_code)
