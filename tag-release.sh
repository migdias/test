#!/bin/bash

source ./functions.sh

FORCE_RELEASE=false
AUTO_APPROVE=false
AVAILABLE_STACKS="um kdg mobile dsl"

while getopts ":f:a" OPTION; do
    case $OPTION in
        f) FORCE_RELEASE=true ;;
        a) AUTO_APPROVE=true ;;
        ?) echo "Usage: $(basename $0) [-f] [-a] <stack> <version|major|minor|patch>" >&2
           exit 1 ;;
    esac
done
shift "$((OPTIND - 1))"

# Check if stack and version arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 [-f] [-a] <stack> <version|major|minor|patch>"
  exit 1
fi

STACK=$1
VERSION=$2
NEW_TAG="${STACK}_v${VERSION}"

# Checks if the stack provided is valid
if ! exists_in_list "$AVAILABLE_STACKS" " " $STACK; then
    echo -e ">> ${RED}[ERROR]${CYAN} $STACK ${RESET}is not an acceptable stack. Only um, kdg, dsl and mobile are allowed"
    exit 1
fi

# Get the latest version tag for the stack
LATEST_TAG=$(git ls-remote --tags origin | grep "${STACK}_v" | grep -o "${STACK}_v[0-9]*\.[0-9]*\.[0-9]*" | sort -V | tail -n 1)
LATEST_VERSION="${LATEST_TAG#${STACK}_v}"

# If the version variable is (major, minor or patch then it does automatic semantic versioning)
# Otherwise checks if its a valid semantic version and uses that
if [[ "$VERSION" =~ ^(major|minor|patch)$ ]]; then
    VERSION=$(increment_version "$LATEST_VERSION" "$VERSION")
    NEW_TAG="${STACK}_v${VERSION}"
    echo -e ">> ${GREEN}[INFO]${RESET} New version after increment: ${MAGENTA}$LATEST_VERSION -> $VERSION${RESET}"
else
    # Regular expression for semantic versioning with optional minor and patch versions
    semver_regex="^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?$"

    if [[ ! $VERSION =~ $semver_regex ]]; then
        echo -e ">> ${RED}[ERROR] ${RESET}The variable ${MAGENTA}'$VERSION'${RESET} is not a valid semantic version."
        exit 1
    fi
fi

# Validate the new tag. Checking if exists on remote
validate_tag $NEW_TAG

# Here the payload files are altered to have the newest tag.
alter_payloads $NEW_TAG

# Pushes the tag. May ask for confirmation if -a is not added
release_tag $NEW_TAG $AUTO_APPROVE


