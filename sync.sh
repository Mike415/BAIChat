#!/bin/bash
# Sync script to update GitHub Pages with latest chat export
# Run this after exporting from the space

set -e

cd "$(dirname "$0")"

echo "Syncing BAI Chat to GitHub..."

# Check if we have changes
if git diff --quiet && git diff --cached --quiet; then
    echo "No changes to sync"
    exit 0
fi

# Add and commit
git add index.html
git commit -m "Update chat export - $(date '+%Y-%m-%d %H:%M')"

# Push to GitHub (will prompt for credentials if needed)
git push origin main

echo "✓ Synced to https://mike415.github.io/BAIChat/"
echo "  (may take 1-2 minutes to deploy)"
