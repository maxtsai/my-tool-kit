#!/bin/sh
if ! git diff --cached | ./scripts/checkpatch.pl --no-signoff -; then
    echo "checkpatch.pl found coding style issues. Please fix them before committing."
    exit 1
fi
