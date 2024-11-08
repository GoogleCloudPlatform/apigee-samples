# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

is_directory_changed() {
    # Compute a checksum of the files inside the directory, compare it to any
    # previous checksum, to determine if any change has been made. This can help
    # avoid an unnecessary re-import and re-deploy, when modifying the proxy and
    # deploying iteratively.
    local dir_of_interest=$1
    local parent_name=$(dirname "${dir_of_interest}")
    local short_name=$(basename "${dir_of_interest}")
    local NEW_SHASUM_FILE=$(mktemp /tmp/${scriptid}.out.XXXXXX)
    # https://stackoverflow.com/a/5431932
    tar -cf - --exclude='*.*~' --exclude='*~' $dir_of_interest | shasum >"$NEW_SHASUM_FILE"
    local PERM_SHASUM_FILE="${parent_name}/.${short_name}.shasum"
    if [[ -f "${PERM_SHASUM_FILE}" ]]; then
        local current_value=$(<"$NEW_SHASUM_FILE")
        current_value="${current_value//[$'\t\r\n ']/}"
        local previous_value=$(<"$PERM_SHASUM_FILE")
        previous_value="${previous_value//[$'\t\r\n ']/}"
        if [[ "$current_value" == "$previous_value" ]]; then
            false
        else
            cp "$NEW_SHASUM_FILE" "${PERM_SHASUM_FILE}"
            true
        fi
    else
        cp "$NEW_SHASUM_FILE" "${PERM_SHASUM_FILE}"
        true
    fi
}

maybe_import_and_deploy() {
    local dirpath=$1
    local sa_email=$2
    local force="$3"
    local ORG="$PROJECT"

    [[ -z "$APIGEE_ENV" ]] && printf "missing APIGEE_ENV\n" && exit 1
    [[ -z "$PROJECT" ]] && printf "missing PROJECT\n" && exit 1

    local asset_type=$(basename $dirpath)
    local object
    if [[ ${asset_type} = "sharedflowbundle" ]]; then
        object="sharedflows"
    else
        object="apis"
    fi

    local files=(${dirpath}/*.xml)
    if [[ ${#files[@]} -eq 1 ]]; then
        local name="${files[0]}"
        name=$(basename "${name%.*}")
        if [[ "$force" = "force" ]] || is_directory_changed $dirpath; then
            # import only if the dir has changed
            printf "will import a new revision of %s [%s]\n" "$asset_type" "$name"
            apigeecli $object create bundle -f $dirpath --name "${name}" -o $ORG --token $TOKEN
            local SA_PARAMS=""
            if [[ ! -z "$sa_email" ]]; then
                SA_PARAMS="--sa ${SA_EMAIL}"
            fi
            apigeecli $object deploy --wait --name "$name" --ovr --org $ORG --env "$APIGEE_ENV" --token $TOKEN $SA_PARAMS &
            need_wait=1
        else
            printf "no update needed for %s [%s]\n" "$asset_type" "$name"
        fi
    else
        printf "could not determine name of proxy to import\n"
    fi
}

create_service_account_and_grant_logWriter_role() {
    local sa_name="$1"
    local role
    printf "Creating API Proxy Service Account %s...\n" "$sa_name"
    gcloud iam service-accounts create "$sa_name"
    printf "%s\n" "$sa_name" >./.sa_name

    local ROLES_OF_INTEREST=( "roles/logging.logWriter" )
    for role in "${ROLES_OF_INTEREST[@]}"; do
        printf "Granting role %s to that SA...\n" "$role"
        SA_EMAIL="${sa_name}@${PROJECT}.iam.gserviceaccount.com"
        gcloud projects add-iam-policy-binding "$PROJECT" \
               --member="serviceAccount:$SA_EMAIL" \
               --role="$role"
    done
}

maybe_install_apigeecli() {
    if [[ ! -d $HOME/.apigeecli/bin ]]; then
        echo "Installing apigeecli\n"
        curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
    fi
    export PATH=$PATH:$HOME/.apigeecli/bin
}


check_shell_variables() {
    local MISSING_ENV_VARS=()
    [[ -z "$PROJECT" ]] && MISSING_ENV_VARS+=('PROJECT')
    [[ -z "$APIGEE_ENV" ]] && MISSING_ENV_VARS+=('APIGEE_ENV')
    [[ -z "$APIGEE_HOST" ]] && MISSING_ENV_VARS+=('APIGEE_HOST')

    [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
        printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
        printf "You must set these environment variables: %s\n" "${joined%,}"
        exit 1
    }
}
