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
 Fuzz.fuzz_node_transferFrom(0,88092068953297091638953425641545759750841381511719748764554590009033148525978) from: 0x0000000000000000000000000000000000010000 Time delay: 5 seconds Block delay: 12840
    Fuzz.fuzz_guided_router7540_claimable(20440751239861551263210017305103462957874751600320472381904998067932913866585,43891899801600343382273571841703981365596636162518000) from: 0x0000000000000000000000000000000000010000 Time delay: 390 seconds Block delay: 22557
    Fuzz.fuzz_admin_router4626_liquidate(115792089237316195423570985008687907853269984665640564039457584007913129639934,115792089237316195423570985008687907853269984665640564039457584007913129639931) from: 0x0000000000000000000000000000000000020000 Time delay: 340735 seconds Block delay: 33385
    Fuzz.fuzz_digift_requestRedeem(1527357639) from: 0x0000000000000000000000000000000000030000 Time delay: 530594 seconds Block delay: 26035
    Fuzz.fuzz_admin_router4626_fulfillRedeem(985143685111709867,89076549647925505740055619718238502260145721190829754660419651255947872743133) from: 0x0000000000000000000000000000000000030000 Time delay: 221150 seconds Block delay: 42834
    *wait* Time delay: 279146 seconds Block delay: 36354
    Fuzz.fuzz_digift_approve(37494930910896924765316671604735719132266202933507130170724922135019949915469,9310357403094468540474) from: 0x0000000000000000000000000000000000010000 Time delay: 287302 seconds Block delay: 4838
    Fuzz.fuzz_admin_router4626_invest(55888435172287275203,100746975534394966283016158018995781655231304357456368396790789869419796921799) from: 0x0000000000000000000000000000000000010000 Time delay: 255548 seconds Block delay: 19198
    Fuzz.fuzz_digift_transferFrom(79576295800658417341527608435839068069739225034202213131171667683690844248515,9429956963926014652775844646820622213275733023218873927381846256045684750859) from: 0x0000000000000000000000000000000000030000 Time delay: 591618 seconds Block delay: 45852
    Fuzz.fuzz_admin_digift_settleDeposit(297000000000000000000) from: 0x0000000000000000000000000000000000030000 Time delay: 519341 seconds Block delay: 50452
    Fuzz.fuzz_node_submitPolicyData(24002585187530828847693644735668513807114843613600795682084838599806208101867) from: 0x0000000000000000000000000000000000030000 Time delay: 116188 seconds Block delay: 46114
    Fuzz.fuzz_donate(61193472018033805809767069866602486103243649578797486242925606133452857153810,95751910080089076710743499640656448798564619572496741303087459593916626855322,87742886473440428091337) from: 0x0000000000000000000000000000000000020000 Time delay: 316455 seconds Block delay: 34681
    Fuzz.fuzz_guided_router7540_claimable(93760482603533800923495713486196336988043085584989614091768819496424020636891,32558883070433647782229229172) from: 0x0000000000000000000000000000000000010000 Time delay: 557136 seconds Block delay: 45840
    Fuzz.fuzz_guided_router7540_partialFulfill(4112537384079471179326918507781666804985841775515106615284192681649338945665,1526785589,110148767127586510928569) from: 0x0000000000000000000000000000000000030000 Time delay: 425793 seconds Block delay: 39813
    Fuzz.fuzz_admin_digift_settleRedeem(115792089237316195423570985008687907853269984665640564039457584007913129639935) from: 0x0000000000000000000000000000000000010000 Time delay: 321869 seconds Block delay: 48205
    Fuzz.fuzz_nodeFactory_deploy(101042478295375761736544454339215308654303834031869642443507628858626733400613) from: 0x0000000000000000000000000000000000010000 Time delay: 138409 seconds Block delay: 35738
    *wait* Time delay: 676151 seconds Block delay: 106212
    Fuzz.fuzz_node_approve(18895997281448111255308646335021487049476955306839940564494670109009947508302,113489132766715649790291599439186632063404643530400956416481394854962791012534) from: 0x0000000000000000000000000000000000010000 Time delay: 484608 seconds Block delay: 642
    Fuzz.fuzz_admin_digift_settleRedeem(46203610150722289169351326170484920) from: 0x0000000000000000000000000000000000030000 Time delay: 214078 seconds Block delay: 38753

"""

    solidity_code = convert_to_solidity(call_sequence)
    print(solidity_code)
