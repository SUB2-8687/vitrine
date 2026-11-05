#!/bin/sh
# Use ui-check.py settings automix to share the build and owned simulator.
set -eu
exec python3 "$(dirname "$0")/ui-check.py" settings
