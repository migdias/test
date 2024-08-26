#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 {major|minor|patch}"
    exit 1
}

# Ensure an argument is passed
if [ -z "$1" ]; then
    usage
fi

# Ensure the argument is one of "major", "minor", or "patch"
if [ "$1" != "major" ] && [ "$1" != "minor" ] && [ "$1" != "patch" ]; then
    usage
fi

# Fetch tags from the remote
git fetch --tags

# Get the latest tag
LATEST_TAG=$(git describe --tags --abbrev=0)

# If no tags are found, start with 0.0.0
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="0.0.0"
fi

# Split the latest tag into major, minor, and patch
IFS='.' read -r -a VERSION_PARTS <<< "$LATEST_TAG"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment the version based on the input argument
case "$1" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

# Create the new tag
NEW_TAG="${MAJOR}.${MINOR}.${PATCH}"
echo "Creating new tag: $NEW_TAG"

# Create the tag and push it to the remote repository
git tag "$NEW_TAG"
git push origin "$NEW_TAG"
