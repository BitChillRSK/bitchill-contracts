#!/bin/bash
# setup.sh - Initializes the project and applies necessary modifications for Rootstock compatibility

echo "🔄 Initializing Git submodules..."
git submodule init
git submodule update

echo "🔧 Applying Solidity version compatibility fixes..."
# For macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    find lib/ -type f -name "*.sol" -exec sed -i '' 's/pragma solidity =0.7.6;/pragma solidity >=0.7.6 <0.9.0;/g' {} \;
# For Linux
else
    find lib/ -type f -name "*.sol" -exec sed -i 's/pragma solidity =0.7.6;/pragma solidity >=0.7.6 <0.9.0;/g' {} \;
fi

echo "🏗️ Building the project..."
forge build

echo "✅ Setup complete! The project is ready for development." 