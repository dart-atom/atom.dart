#!/bin/bash

# Fast fail the script on failures.
set -e

# Analyze, build and test.
pub run grinder bot
