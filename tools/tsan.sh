#!/usr/bin/env bash
# Runs the real-engine test suite under ThreadSanitizer, LOCALLY on macOS.
#
# This checks the SDK's own locking (environment state, the SzAsyncEngine
# worker pool, logging slots); libSz itself is not instrumented. It is not a CI
# job: on Linux the Senzing runtime loads its database plugins with
# dlopen(RTLD_DEEPBIND), which ThreadSanitizer cannot run with, and macOS CI
# runs only the build and tests.
#
# Usage: tools/tsan.sh [extra `swift test` arguments, e.g. --filter Concurrency]
set -euo pipefail
if [ "$(uname -s)" != "Darwin" ]; then
    echo "tools/tsan.sh runs on macOS only (Linux: RTLD_DEEPBIND plugins)." >&2
    exit 2
fi
exec swift test --sanitize=thread "$@"
