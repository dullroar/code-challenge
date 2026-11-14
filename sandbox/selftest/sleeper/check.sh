#!/usr/bin/env bash
# Never finishes on its own. sandbox/selftest.sh runs it with a short SANDBOX_TIMEOUT and
# expects run.sh to report TIMEOUT (exit 124) and leave no container behind.
echo "sleeper: sleeping for ten minutes"
sleep 600
