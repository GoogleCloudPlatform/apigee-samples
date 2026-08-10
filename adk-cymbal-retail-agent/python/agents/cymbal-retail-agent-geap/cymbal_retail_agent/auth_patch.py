# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import logging
from google.adk.auth import auth_preprocessor
from google.adk.auth.auth_handler import AuthHandler
from google.adk.auth.credential_service.session_state_credential_service import SessionStateCredentialService
from google.adk.auth.auth_credential import AuthCredential
from google.genai import types

def apply_patches():
    # 1. Patch preprocessor
    original_store_auth = auth_preprocessor._store_auth_and_collect_resume_targets
    async def patched_store_auth(events, auth_fc_ids, auth_responses, state):
        logging.info(f"[PATCH PREPROCESSOR] Initial state keys: {list(state.keys()) if hasattr(state, 'keys') else 'no keys'}")
        logging.info(f"[PATCH PREPROCESSOR] auth_fc_ids: {auth_fc_ids}, auth_responses: {auth_responses}")
        result = await original_store_auth(events, auth_fc_ids, auth_responses, state)
        logging.info(f"[PATCH PREPROCESSOR] Final state keys: {list(state.keys()) if hasattr(state, 'keys') else 'no keys'}")
        return result
    auth_preprocessor._store_auth_and_collect_resume_targets = patched_store_auth

    # 2. Patch auth handler
    original_parse_and_store = AuthHandler.parse_and_store_auth_response
    async def patched_parse_and_store(self, state):
        logging.info(f"[PATCH AUTH_HANDLER] Writing credential for key: {self.auth_config.credential_key}")
        await original_parse_and_store(self, state)
        credential_key = "temp:" + self.auth_config.credential_key
        val = state.get(credential_key) if hasattr(state, "get") else state[credential_key]
        logging.info(f"[PATCH AUTH_HANDLER] Done writing. Key: {credential_key}, Value: {val}")
    AuthHandler.parse_and_store_auth_response = patched_parse_and_store

    # 3. Patch credential service
    original_load_credential = SessionStateCredentialService.load_credential
    async def patched_load_credential(self, auth_config, callback_context):
        cred = await original_load_credential(self, auth_config, callback_context)
        if cred:
            logging.info(f"[PATCH CREDENTIAL_SERVICE] Key {auth_config.credential_key} loaded. Type: {type(cred)}, Val: {cred}")
            if isinstance(cred, str):
                import json
                try:
                    cred = json.loads(cred)
                    logging.info(f"[PATCH CREDENTIAL_SERVICE] Parsed JSON string to dict")
                except Exception as e:
                    logging.error(f"[PATCH CREDENTIAL_SERVICE] Failed to parse JSON string: {e}")
            if isinstance(cred, dict):
                logging.info(f"[PATCH CREDENTIAL_SERVICE] Deserializing dict to AuthCredential for key {auth_config.credential_key}")
                cred = AuthCredential.model_validate(cred)
        return cred
    SessionStateCredentialService.load_credential = patched_load_credential


async def restore_credentials(callback_context):
    import json
    state = callback_context.state
    logging.info(f"[DEBUG RESTORE] Initial state keys: {list(state.to_dict().keys())}")
    for key, value in list(state.to_dict().items()):
        if key.startswith("persistent_auth:"):
            temp_key = key.replace("persistent_auth:", "temp:")
            logging.info(f"[DEBUG RESTORE] Key: {key}, Type: {type(value)}, Val: {value}")
            if isinstance(value, str):
                try:
                    value = json.loads(value)
                    logging.info(f"[DEBUG RESTORE] Parsed JSON string to dict")
                except Exception as e:
                    logging.error(f"[DEBUG RESTORE] Failed to parse JSON string: {e}")
            if isinstance(value, dict):
                logging.info(f"[DEBUG RESTORE] Deserializing dict value for {key}")
                value = AuthCredential.model_validate(value)
            state[temp_key] = value
            logging.info(f"[DEBUG RESTORE] Restored key {key} to {temp_key}")
    logging.info(f"[DEBUG RESTORE] Final state keys: {list(state.to_dict().keys())}")

async def persist_credentials(callback_context):
    state = callback_context.state
    has_changes = False
    logging.info(f"[DEBUG PERSIST] Initial state keys: {list(state.to_dict().keys())}")
    for key, value in list(state.to_dict().items()):
        if key.startswith("temp:adk_"):
            persist_key = key.replace("temp:", "persistent_auth:")
            state[persist_key] = value
            has_changes = True
            logging.info(f"[DEBUG PERSIST] Persisted key {key} to {persist_key}")
    logging.info(f"[DEBUG PERSIST] Final state keys: {list(state.to_dict().keys())}")
    if has_changes:
        return types.Content(role="model", parts=[types.Part(text="")])
    return None
