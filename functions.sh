### COLORS

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'  # No Color


# returns a bool if a string is within a list
# Usage: exists_in_list() list delimiter value
function exists_in_list() {
    LIST=$1
    DELIMITER=$2
    VALUE=$3
    [[ "$LIST" =~ ($DELIMITER|^)$VALUE($DELIMITER|$) ]]
}

# Receives a version string and the part (major, minor, patch) and returns the new version
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

function validate_tag() {
    # Checks whether tag exists on remote
    # If yes, asks if re-release is ok
    # If not, continues
    NEW_TAG=$1
    if (git ls-remote --tags origin | grep -q "$NEW_TAG"); then
        if $FORCE_RELEASE; then
            echo -e ">> ${GREEN}[INFO]${RESET} ${YELLOW}Forcing...${RESET}"
            echo -e ">> ${GREEN}[INFO]${RESET} ${YELLOW}Deleting remote tag${RESET}" && git tag -d $NEW_TAG && git push origin tag --delete $NEW_TAG;
        else
            echo -e ">> ${YELLOW}[WARN]: ${RESET}The tag ${MAGENTA}$NEW_TAG${RESET} already exists on remote. If you want to overwrite it, run it with the -f [FORCE_RELEASE] option"
            exit 1;
        fi
    fi
}

function release_tag() {
    # Here goes git code for tag release
    TAG=$1
    AUTO_APPROVE=$2
    if $AUTO_APPROVE; then
        push_tag $TAG
    else
        echo -e ">> ${GREEN}[INFO]${RESET} ${YELLOW} The tag ${MAGENTA}$TAG${YELLOW} is about to be pushed to remote. Do you want to continue? [y/n]:${RESET} "
        read -p "" answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            push_tag $TAG
            echo -e ">> ${GREEN}[INFO]${RESET} Tag ${MAGENTA}$TAG${RESET} has been pushed"
        else
            echo -e ">> ${GREEN}[INFO]${RESET} The release was cancelled."
            exit 1
        fi
    fi
}

function push_tag() {
    TAG=$1
    git tag $TAG
    git push origin tag $TAG
}

# Function to alter the tag on payloads
# Usage: alter_payloads $$TAG
function alter_payloads() {
    NEW_TAG=$1
    echo -e ">> ${GREEN}[INFO]${RESET} Finding payload files..."
    payloads=$(find pipelines/stacks/um -type f \( -path "*/payloads/nonlive.json" -o -path "*/payloads/live.json" \))

    # Check if payloads array is not empty
    if [ ${#payloads[@]} -eq 0 ]; then
        # For each payload file, checks the old tag and replaces it with the new tag
        for payload in $payloads; do
            PIPELINE_FILES_GCS_PATH=$(jq -r '.data.pipeline_files_gcs_path' $payload)
            OLD_TAG=$(basename $PIPELINE_FILES_GCS_PATH)
            echo -e ">> ${GREEN}[INFO]${RESET} File: ${GREEN}$payload${RESET} -- Changing tag ${MAGENTA}$OLD_TAG${RESET} to ${MAGENTA}$NEW_TAG${RESET}"

            tmp=$(mktemp)
            jq --arg old_tag $OLD_TAG --arg new_tag $NEW_TAG 'walk(if type == "string" then sub($old_tag; $new_tag) else . end)' $payload > "$tmp" && mv "$tmp" $payload
        done

        # Pushing payloads to remote
        if [ $OLD_TAG != $NEW_TAG ]; then
            echo -e ">> ${GREEN}[INFO]${RESET} Pushing to remote"
            git add */payloads/**
            git commit -m "${1}: updating payloads"
            git push
        else
            echo -e ">> ${GREEN}[INFO]${RESET} Not pushing payloads to remote since tag is the same --- ${OLD_TAG} = ${1}"
        fi
    fi
}