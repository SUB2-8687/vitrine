#!/bin/sh
# SRC remains available for the explicit manual AutoMix mutation runner.
set -eu
sh "$(dirname "$0")/queue-check.sh"
exec python3 "$(dirname "$0")/ui-check.py" automix
