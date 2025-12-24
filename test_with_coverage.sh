#!/bin/bash

# Fast fail
set -e

# Run tests with coverage
echo "Running tests..."
dart test --coverage=coverage

# Format coverage to LCOV
echo "Generating LCOV report..."
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

echo "Coverage report generated at coverage/lcov.info"

# Check if genhtml is installed (part of lcov package)
if command -v genhtml &> /dev/null; then
    echo "Generating HTML report..."
    genhtml coverage/lcov.info -o coverage/html
    echo "HTML report generated at coverage/html/index.html"
else
    echo "Tip: Install lcov (brew install lcov) to generate HTML reports."
fi
