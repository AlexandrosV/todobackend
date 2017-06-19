#!/bin/bash
# Activate virtual environment
. /appenv/bin/activate

# Download requirements for cache service
pip download -d /build -r requirements_test.txt --no-input

# Install application test requirements
pip install --no-index -f /build -r requirements_test.txt

# Run test.sh
exec $@