#!/bin/bash
# Copyright 2024-2025 Google LLC
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

check_shell_variables() {
  local MISSING_ENV_VARS
  MISSING_ENV_VARS=()
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      MISSING_ENV_VARS+=("$var_name")
    fi
  done

  [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "You must set these environment variables: %s\n" "${joined%,}"
    exit 1
  }

  printf "Settings in use:\n"
  for var_name in "$@"; do
    if [[ "$var_name" == *_APIKEY || "$var_name" == *_API_KEY || "$var_name" == *_SECRET || "$var_name" == *_CLIENT_ID ]]; then
      local value="${!var_name}"
      printf "  %s=%s\n" "$var_name" "${value:0:4}..."
    else
      printf "  %s=%s\n" "$var_name" "${!var_name}"
    fi
  done
  printf "\n"
}

check_required_commands() {
  local missing
  missing=()
  for cmd in "$@"; do
    #printf "checking %s\n" "$cmd"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  # shellcheck disable=SC2128
  if [[ -n "$missing" ]]; then
    printf -v joined '%s,' "${missing[@]}"
    printf "\n\nThese commands are missing; they must be available on path: %s\nExiting.\n" "${joined%,}"
    exit 1
  fi
}

is_role_present() {
  local search_role="$1"
  local -n role_array="$2" # -n creates a nameref to the array passed by name
  for element in "${role_array[@]}"; do
    if [[ "${element}" == "${search_role}" ]]; then
      return 0
    fi
  done
  return 1
}
