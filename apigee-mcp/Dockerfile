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
FROM node:18-slim AS builder

WORKDIR /usr/src/app

COPY package.json ./
COPY package-lock.json ./

RUN npm install

COPY tsconfig.json ./

# Copy the source code
COPY src ./src/

# Compile TypeScript to JavaScript
RUN npm run build

FROM node:18-slim AS production

# Set the working directory
WORKDIR /usr/src/app

COPY package.json ./
COPY package-lock.json ./

ENV NODE_ENV=production
RUN npm install --production

COPY --from=builder /usr/src/app/build ./build

EXPOSE 3000

CMD ["node", "build/index.js"]