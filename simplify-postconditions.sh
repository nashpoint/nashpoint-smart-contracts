#!/bin/bash

# Script to simplify postcondition branching logic
# Removes all params.shouldSucceed checks and converts to simple if(success) pattern

FILES=(
  "test/fuzzing/helpers/Postconditions/PostconditionsDigiftAdapter.sol"
  "test/fuzzing/helpers/Postconditions/PostconditionsDigiftEventVerifier.sol"
  "test/fuzzing/helpers/Postconditions/PostconditionsNodeFactory.sol"
  "test/fuzzing/helpers/Postconditions/PostconditionsRewardRouters.sol"
  "test/fuzzing/helpers/Postconditions/PostconditionsNodeRegistry.sol"
  "test/fuzzing/helpers/Postconditions/PostconditionsOneInch.sol"
)

for file in "${FILES[@]}"; do
  echo "Processing $file..."

  # Use perl for multi-line pattern replacement
  # Pattern 1: if (success && params.shouldSucceed) ... else if (!success && !params.shouldSucceed) ... else if (success && !params.shouldSucceed) ... else ...
  # becomes: if (success) ... else ...

  perl -0777 -pi -e 's/if \(success && params\.shouldSucceed\) \{(.*?)\s+onSuccessInvariantsGeneral\(returnData\);\s+\} else if \(!success && !params\.shouldSucceed\) \{\s+onFailInvariantsGeneral\(returnData\);\s+\} else if \(success && !params\.shouldSucceed\) \{\s+onSuccessInvariantsGeneral\(returnData\);\s+\} else \{\s+onFailInvariantsGeneral\(returnData\);\s+\}/if (success) {$1\n            onSuccessInvariantsGeneral(returnData);\n        } else {\n            onFailInvariantsGeneral(returnData);\n        }/gs' "$file"

  # Pattern 2: if (params.shouldSucceed) { fl.t(success, ...); ... } else { fl.t(!success, ...); ... }
  # becomes: if (success) { ... } else { ... }
  # Remove fl.t lines that check success/shouldSucceed

  perl -0777 -pi -e 's/if \(params\.shouldSucceed\) \{\s+\/\/ fl\.t\(success,[^\n]+\n(.*?)\s+onSuccessInvariantsGeneral\(returnData\);\s+\} else \{\s+\/\/ fl\.t\(!success,[^\n]+\n\s+onFailInvariantsGeneral\(returnData\);\s+\}/if (success) {$1\n            onSuccessInvariantsGeneral(returnData);\n        } else {\n            onFailInvariantsGeneral(returnData);\n        }/gs' "$file"

  echo "Done with $file"
done

echo "All files processed!"
