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

var responseObj = response.content.asJSON;
var modelProvider = context.getVariable("reqPrefix.modelProvider");
var tokenCountObj = {
  "promptTokenCount":0,
   "generatedTokenCount": 0,
  "totalTokenCount": 0
};
//For VertextAI Response
if(modelProvider !== null && modelProvider == "google")
{
    if(responseObj !== null && responseObj.usageMetadata !== null){
        var usageMetadata = responseObj.usageMetadata;
        tokenCountObj = {
            "promptTokenCount": usageMetadata.promptTokenCount,
            "generatedTokenCount": usageMetadata.candidatesTokenCount,
            "totalTokenCount": usageMetadata.totalTokenCount
        };
    }
}
//For Hugging Face
if(modelProvider !== null && modelProvider == "hugging_face")
{
    var promptTokenCount = context.getVariable("response.header.x-prompt-tokens");
    print("promptTokenCount header: "+ promptTokenCount);
    var generatedTokenCount = context.getVariable("response.header.x-generated-tokens");
    print("generatedTokenCount header: "+ generatedTokenCount);
    if(promptTokenCount !== null && generatedTokenCount !== null){
        tokenCountObj = {
            "promptTokenCount": parseInt(promptTokenCount),
            "generatedTokenCount": parseInt(generatedTokenCount),
            "totalTokenCount": parseInt(promptTokenCount) + parseInt(generatedTokenCount)
        };
    } else{
        promptTokenCount = wordCount(context.getVariable("request_prompt_value"));
        generatedTokenCount = wordCount(context.getVariable("response_prompt_value"));
       tokenCountObj = {
            "promptTokenCount": promptTokenCount,
            "generatedTokenCount": generatedTokenCount,
            "totalTokenCount": promptTokenCount + generatedTokenCount
        };
    }
}
print("tokenCountObj: "+ tokenCountObj);
context.setVariable("tokenCountObj", JSON.stringify(tokenCountObj));
context.setVariable("promptTokenCount", parseInt(tokenCountObj.promptTokenCount).toFixed(0));

function wordCount(str){
    if(str === null)
        return 0;
    var strArray = str.trim().split(/\s+/);
    return strArray.length;
}
