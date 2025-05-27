#!/bin/bash

# Copyright 2025 Google LLC
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

set -e

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

export OS
export ARCH

if [[ "${OS}" == "darwin" ]] ; then
  export OS="osx"
fi

export TOOL="grpcurl"
export TOOL_VERSION=1.8.6
export TOOL_TARGZ="https://github.com/fullstorydev/grpcurl/releases/download/v${TOOL_VERSION}/grpcurl_${TOOL_VERSION}_${OS}_${ARCH}.tar.gz"
export INSTALL_PATH="${HOME}/.grpcurl/bin"

TEMP_DIR=$(mktemp -d)
pushd "${TEMP_DIR}" &> /dev/null || exit

echo "*** Downloading ${TOOL} (${TOOL_VERSION}) tar ball ... "
curl -o tool.tar.gz -sfL "${TOOL_TARGZ}"
tar -xvf "tool.tar.gz" &> /dev/null
rm -f tool.tar.gz

echo "*** Installing ${TOOL} to ${INSTALL_PATH} ..."
mkdir -p "${INSTALL_PATH}"
cp "./${TOOL}" "${INSTALL_PATH}/"
chmod a+x "${INSTALL_PATH}/${TOOL}"

popd &> /dev/null || exit


echo "*** Tool ${TOOL_VERSION} installed to ${INSTALL_PATH}, add it to your path:"
echo ""
echo "   export PATH=\"${INSTALL_PATH}:\${PATH}\""
echo ""