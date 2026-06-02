#!/bin/bash

set -e

FILE="Jenkinsfile"

echo "Validating Jenkinsfile..."

if [ ! -f "$FILE" ]; then
  echo "ERROR: Jenkinsfile not found"
  exit 1
fi

echo "Checking brace balance..."

BALANCE=$(python3 - <<'PY'
from pathlib import Path

text = Path("Jenkinsfile").read_text()
balance = 0

for ch in text:
    if ch == "{":
        balance += 1
    elif ch == "}":
        balance -= 1

print(balance)
PY
)

echo "Brace balance: $BALANCE"

if [ "$BALANCE" != "0" ]; then
  echo "ERROR: Jenkinsfile brace balance is not zero"
  exit 1
fi

echo "Checking stage order..."

grep -n "stage('" Jenkinsfile || true

echo ""
echo "Checking compliance stages are inside pipeline before final closing braces..."

COLLECT_LINE=$(grep -n "stage('Collect Compliance Evidence')" Jenkinsfile | cut -d: -f1 | head -1 || true)
LAST_STAGE_LINE=$(grep -n "stage('Archive Compliance Artifacts')" Jenkinsfile | cut -d: -f1 | head -1 || true)

if [ -z "$COLLECT_LINE" ]; then
  echo "WARNING: Collect Compliance Evidence stage not found"
else
  echo "Collect Compliance Evidence found at line: $COLLECT_LINE"
fi

if [ -z "$LAST_STAGE_LINE" ]; then
  echo "WARNING: Archive Compliance Artifacts stage not found"
else
  echo "Archive Compliance Artifacts found at line: $LAST_STAGE_LINE"
fi

echo ""
echo "Jenkinsfile validation completed successfully."
