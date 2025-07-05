#!/usr/bin/env bash
# This phase will sleep to allow SIGINT (Ctrl+C) testing
echo "[SLEEP] Sleeping for 30 seconds. Press Ctrl+C to test SIGINT trap."
sleep 30
echo "[SLEEP] Woke up after sleep."
