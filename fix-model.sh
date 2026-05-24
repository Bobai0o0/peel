#!/bin/bash
# Run from the folder ABOVE peel/
# This replaces gemini-1.5-flash with gemini-2.0-flash in every file

cd peel

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  find src -name "*.ts" -exec sed -i '' 's/gemini-1.5-flash/gemini-2.0-flash/g' {} +
  find src -name "*.tsx" -exec sed -i '' 's/gemini-1.5-flash/gemini-2.0-flash/g' {} +
else
  # Linux
  find src -name "*.ts" -exec sed -i 's/gemini-1.5-flash/gemini-2.0-flash/g' {} +
  find src -name "*.tsx" -exec sed -i 's/gemini-1.5-flash/gemini-2.0-flash/g' {} +
fi

echo "✅ Replaced all gemini-1.5-flash → gemini-2.0-flash"
echo ""
echo "Now run:"
echo "  cd peel && git add . && git commit -m 'fix: gemini-2.0-flash' && git push"
