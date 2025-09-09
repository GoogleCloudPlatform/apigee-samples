# Copyright 2025 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = [
    pkgs.python3
    pkgs.python311Packages.pip
    pkgs.curl
  ];
  env = {};
  idx = {
    extensions = [ "ms-python.python"  "ms-python.debugpy"];
    workspace = {
      onCreate = {
        install =''
          echo "✅ Creating Python virtual env ..." &&
          python -m venv .venv &&
          \
          echo "✅ Activating Python virtual env ..." &&
          source .venv/bin/activate &&
          \
          echo "✅ Installing Python requirements ..." &&
          pip install -r requirements.txt &&
          \
          echo "✅ Installing apigee-go-gen tool ..." &&
          curl -s https://apigee.github.io/apigee-go-gen/install | sh -s latest ~/.apigee-go-gen/bin &&
          \
          echo "✅ Adding apigee-go-gen to ~/.bashrc \$PATH ..." &&
          echo "export PATH=\"\$HOME/.apigee-go-gen/bin:\$PATH\"" >> ~/.bashrc &&
          \
          echo "✅ Installing apigeecli tool ..." &&
          curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh - &&
          \
          echo "✅ Adding apigeecli to ~/.bashrc \$PATH ..." &&
          echo "export PATH=\"\$HOME/.apigeecli/bin:\$PATH\"" >> ~/.bashrc
          '';
      };
    };
  };

}