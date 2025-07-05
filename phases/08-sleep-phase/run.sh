#!/usr/bin/env bash
# This phase will sleep to allow SIGINT (Ctrl+C) testing
log_bootstrap "[SLEEP] Sleeping for 30 seconds. Press Ctrl+C to test SIGINT trap."
sleep 30
log_bootstrap "[SLEEP] Woke up after sleep."
