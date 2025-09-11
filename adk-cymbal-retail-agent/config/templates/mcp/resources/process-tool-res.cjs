/*
 *  Copyright 2025 Google LLC
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

/*
 *  Copyright 2025 Google LLC
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

var log = isApigee?print:console.log;

function processToolRes(ctx) {
  var statusCode = parseInt(ctx.getVariable("response.status.code"));
  var content = ctx.getVariable("response.content");

  var statusCodePrefix = parseInt(statusCode/100);

  var isError = false;
  if (statusCodePrefix === 4 || statusCodePrefix === 5) {
    isError = true;
  }

  var headers = [["Content-Type", "application/json"]];
  var mcpId = ctx.getVariable("mcp.id");

  var rpcResponse = {
    jsonrpc: "2.0",
    id: mcpId,
    result: {
      content: [
        {
          type: "text",
          text: content
        }
      ],
      isError: isError
    }
  }
  setResponse(ctx, 200, headers,  getPrettyJSON(rpcResponse));
}

function main(ctx) {
  try {
    processToolRes(ctx);
  } catch(e) {
    log("error.message: " + e.message);
    log("error.stack:\n" + e.stack);
    setErrorResponse(ctx,500, e);
  }
}

main(context);

