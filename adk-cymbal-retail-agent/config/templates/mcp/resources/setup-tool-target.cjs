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


function setToolCallTarget(ctx) {
  var rpc = parseJsonRpc(ctx, ctx.getVariable("request.content"), false)

  if (rpc.method !== "tools/call") {
    throw new Error("Cannot set target on non MCP tools/call method.")
  }

  var targetUrl = ctx.getVariable("propertyset.mcp-tools." + rpc["params"]["name"] + ".target_url");
  var targetPathSuffix = ctx.getVariable("propertyset.mcp-tools." + rpc["params"]["name"] + ".target_path_suffix");
  var targetVerb = ctx.getVariable("propertyset.mcp-tools." + rpc["params"]["name"] + ".target_verb");
  var targetContentType = ctx.getVariable("propertyset.mcp-tools." + rpc["params"]["name"] + ".target_content_type");



  ctx.setVariable("message.verb", targetVerb);
  ctx.setVariable("target.url", createFullUrl(targetUrl, targetPathSuffix, rpc["params"]));


  if (targetVerb === "GET") {
    ctx.setVariable("message.content", "");
  } else {
    //post, put, delete, options
    if (targetContentType) {
      ctx.setVariable("request.header.Content-Type", targetContentType);
    }

    var requestBody = _get(rpc, "params.arguments.request_body", null);
    if (requestBody) {
      if (isString(requestBody)) {
        ctx.setVariable("message.content", requestBody)
      } else {
        ctx.setVariable("message.content", getPrettyJSON(requestBody))
      }
    }
  }


}

function main(ctx) {
  try {
    setToolCallTarget(ctx);
  } catch(e) {
    log("error.message: " + e.message);
    log("error.stack:\n" + e.stack);
    setErrorResponse(ctx,500, e);
  }
}


main(context);
