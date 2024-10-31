/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var config = JSON.parse(context.getVariable("model.config"));
setVariable("targetUrl", config);
setVariable("auth_type", config);
setVariable("auth_token_type", config);
setVariable("auth_token", config);
setVariable("request_jsonpath", config);
setVariable("response_jsonpath", config);


function setVariable(varName, config){
  context.setVariable("config."+varName, config[varName]);
}

function replaceFunction (str, key, value){
  return str.replace(key, value);
}

var targetUrlTempl = context.getVariable("config.targetUrl");

//if org does not exist in the target url, replace it from the url template
if(context.getVariable("reqPrefix.org"))
  targetUrlTempl = replaceFunction(targetUrlTempl, "{org}", context.getVariable("reqPrefix.org"));
else
  targetUrlTempl = replaceFunction(targetUrlTempl, "{org}/", "");

if(context.getVariable("reqPrefix.model"))
  targetUrlTempl = replaceFunction(targetUrlTempl, "{model}", context.getVariable("reqPrefix.model"));

context.setVariable("targetUrlTempl", targetUrlTempl);
