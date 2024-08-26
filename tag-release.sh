#!/bin/bash

function exists_in_list() {
    LIST=$1
    DELIMITER=$2
    VALUE=$3
    [[ "$LIST" =~ ($DELIMITER|^)$VALUE($DELIMITER|$) ]]
}

function increment_version() {
    local version=$1
    local part=$2

    IFS='.' read -r -a parts <<< "$version"
    major=${parts[0]:-0}
    minor=${parts[1]:-0}
    patch=${parts[2]:-0}

    case "$part" in
        major)
            ((major++))
            minor=0
            patch=0
            ;;
        minor)
            ((minor++))
            patch=0
            ;;
        patch)
            ((patch++))
            ;;
        *)
            echo "ERROR: Invalid part to increment. Use 'major', 'minor' or 'patch'."
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

FORCE_RELEASE=false
AVAILABLE_STACKS="um kdg mobile dsl"

while getopts ":f" OPTION; do
    case $OPTION in
        f) FORCE_RELEASE=true ;;
        ?) echo "Usage: $(basename $0) [-f] <stack> <version>" >&2
           exit 1 ;;
    esac
done
shift "$((OPTIND - 1))"

# Check if stack and version arguments are provided
if [ $# -lt 2 ]; then
  echo "Usage: $0 [-f] <stack> <version>"
  exit 1
fi

STACK=$1
VERSION=$2
NEW_TAG="${STACK}_v${VERSION}"

if ! exists_in_list "$AVAILABLE_STACKS" " " $STACK; then
    echo "ERROR: $STACK is not an acceptable stack. Only um, kdg, dsl and mobile are allowed"
    exit 1
fi

# Get the latest version tag for the stack
latest_tag=$(git ls-remote --tags origin | grep "${STACK}_v" | grep -o "${STACK}_v[0-9]*\.[0-9]*\.[0-9]*" | sort -V | tail -n 1)
latest_version="${latest_tag#${STACK}_v}"

echo $STACK
echo $VERSION
echo $latest_version
# Variable to check

if [[ "$VERSION" =~ ^(major|minor|patch)$ ]]; then
    VERSION=$(increment_version "$latest_version" "$VERSION")
    NEW_TAG="${STACK}_v${VERSION}"
    echo "New version after increment: $VERSION"
else
    # Regular expression for semantic versioning with optional minor and patch versions
    semver_regex="^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?$"

    if [[ ! $VERSION =~ $semver_regex ]]; then
        echo "The variable '$VERSION' is not a valid semantic version."
        exit 1
    fi
fi

# Checks whether tag exists on remote
# If yes, asks if re-release is ok
# If not, continues
if (git ls-remote --tags origin | grep -q "$NEW_TAG"); then
    if $FORCE_RELEASE; then
    	echo "Forcing..."
    	echo "Deleting remote tag" && git tag -d $NEW_TAG && git push origin tag --delete $NEW_TAG;
    else
    	echo "The tag $NEW_TAG already exists on remote. If you want to overwrite it, run it with the -f [FORCE_RELEASE] option"
    	exit 1;
    fi
fi


exit 1
# Here the payload files are altered to have the newest tag.
echo "Finding payload files..."
payloads=$(find pipelines/stacks/um -type f \( -path "*/payloads/nonlive.json" -o -path "*/payloads/live.json" \))

echo "Found:"
echo "$payloads"

# For each payload file, checks the old tag and replaces it with the new tag
for payload in $payloads; do
    PIPELINE_FILES_GCS_PATH=$(jq -r '.data.pipeline_files_gcs_path' $payload)
    OLD_TAG=$(basename $PIPELINE_FILES_GCS_PATH)
    echo "File: $payload -- Changing tag $OLD_TAG to $NEW_TAG"

    tmp=$(mktemp)
    jq --arg old_tag $OLD_TAG --arg new_tag $NEW_TAG 'walk(if type == "string" then sub($old_tag; $new_tag) else . end)' $payload > "$tmp" && mv "$tmp" $payload
done

# Pushing payloads to remote
if [ $OLD_TAG != $NEW_TAG ]; then
	echo "Pushing to remote"
	git add */payloads/**
	git commit -m "${NEW_TAG}: updating payloads"
	git push
else
	echo "Not pushing payloads to remote since tag is the same --- ${OLD_TAG} = ${NEW_TAG}"
fi


echo "Releasing $NEW_TAG..."

# Here goes git code for tag release
git tag ${NEW_TAG}
git push origin tag ${NEW_TAG}

echo "Pipeline should have been triggered"

