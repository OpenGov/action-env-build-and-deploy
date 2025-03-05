#!/bin/bash

# Get the git diff output of staged changes

DIFF_OUTPUT=$(git diff  "origin/${DIFF_BRANCH}" --unified=0 | grep '^[+-]' | grep -Ev '^(---|\+\+\+|index)')

echo "Diff lines:"
echo $DIFF_OUTPUT

# Check if there are any changes
if [[ -z "$DIFF_OUTPUT" ]]; then
    echo "No changes found in git diff."
    exit 1
fi

# Define the allowed pattern
ALLOWED_PATTERN='^[+-][[:space:]]*image:.*'

# Check each line of the diff output
while IFS= read -r line; do
    if [[ ! "$line" =~ $ALLOWED_PATTERN ]]; then
        echo "Invalid change detected: $line"
        exit 1
    fi
done <<< "$DIFF_OUTPUT"

echo "All changes match the allowed pattern, Forcing Deploy method to PUSH."
echo "DEPLOY_METHOD=PUSH" >> "${GITHUB_ENV}"

exit 0
