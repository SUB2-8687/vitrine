#!/bin/sh
# SRC remains available for the explicit manual AutoMix mutation runner.
set -eu
exec python3 "$(dirname "$0")/ui-check.py" automix
