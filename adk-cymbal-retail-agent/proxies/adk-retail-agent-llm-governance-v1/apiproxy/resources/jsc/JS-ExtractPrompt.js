/**
 * Copyright 2025 Google LLC
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

var requestObj = request.content.asJSON;
print("json: "+ JSON.stringify(requestObj))
context.setVariable("prompt_contents_0", getLatestUserText(requestObj));


// const userContents = requestObj.contents.filter(item => item.role === 'user');
// const userPromptTexts = userContents.map(item => item.parts[0].text);
// print(userPromptTexts); 
// const lastuserPromptText = userPromptTexts[userPromptTexts.length - 1];
// context.setVariable("prompt_contents_0", lastuserPromptText)


function getLatestUserText(json){
  // Find all objects in the contents array where the role is "user"
  const userConversations = json.contents.filter(item => item.role === 'user');

  // Get the last item from the filtered array
  const lastUserConversation = userConversations[userConversations.length - 1];

  // Return the text from the parts array of the last item
  return lastUserConversation.parts[lastUserConversation.parts.length -1].text;
};