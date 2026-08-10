// Cymbal Retail OAuth Client - Frontend Controller

let activeSessionId = null;
let activeAuthRequest = null;
let pollTimer = null;

const chatHistory = document.getElementById('chat-history');
const chatForm = document.getElementById('chat-form');
const chatInput = document.getElementById('chat-input');
const sendBtn = document.getElementById('send-btn');
const sessionIdDisplay = document.getElementById('session-id-display');
const copySessionBtn = document.getElementById('copy-session-btn');
const newSessionBtn = document.getElementById('new-session-btn');
const clearChatBtn = document.getElementById('clear-chat-btn');
const userIdInput = document.getElementById('user-id-input');

// Event Listeners
newSessionBtn.addEventListener('click', createNewSession);
clearChatBtn.addEventListener('click', clearChatLogs);
chatForm.addEventListener('submit', handleMessageSubmit);
copySessionBtn.addEventListener('click', copySessionIdToClipboard);

// Register standard window message event listener to capture OAuth callback parameters from popup
window.addEventListener('message', handleOauthCallbackMessage, false);

async function createNewSession() {
    newSessionBtn.disabled = true;
    newSessionBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Creating...';
    
    // Clear tools log
    const logContainer = document.getElementById("tools-log");
    if (logContainer) {
        logContainer.innerHTML = '';
    }
    
    try {
        const response = await fetch('/api/session', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: userIdInput.value.trim() })
        });
        const data = await response.json();
        
        if (response.ok) {
            activeSessionId = data.session_id;
            sessionIdDisplay.textContent = activeSessionId;
            sessionIdDisplay.title = activeSessionId;
            
            // Enable controls
            chatInput.disabled = false;
            sendBtn.disabled = false;
            copySessionBtn.disabled = false;
            chatInput.placeholder = "Ask about orders, returns, or shipping...";
            chatInput.focus();
            
            appendSystemMessage("New session created. You are connected to the deployed agent!");
        } else {
            appendSystemMessage(`Error creating session: ${data.detail}`);
        }
    } catch (e) {
        appendSystemMessage(`Network error creating session: ${e.message}`);
    } finally {
        newSessionBtn.disabled = false;
        newSessionBtn.innerHTML = '<i class="fa-solid fa-plus"></i> New Chat Session';
    }
}

async function handleMessageSubmit(e) {
    e.preventDefault();
    const text = chatInput.value.trim();
    if (!text || !activeSessionId) return;
    
    // Append User Message
    appendMessage('user', text);
    chatInput.value = '';
    
    // Show typing indicator
    const loader = appendTypingIndicator();
    
    try {
        const response = await fetch('/api/chat', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                session_id: activeSessionId,
                user_id: userIdInput.value.trim(),
                message: text
            })
        });
        const data = await response.json();
        
        // Remove typing indicator
        loader.remove();
        
        if (response.ok) {
            // Process tool calls list
            if (data.tool_calls) {
                data.tool_calls.forEach(tc => {
                    if (tc.type === "call") {
                        logToolCall(tc.name, tc.id);
                    } else if (tc.type === "response") {
                        completeToolCall(tc.id);
                    }
                });
            }
            if (data.pause) {
                // Agent needs end-user consent! Render the auth consent card
                activeAuthRequest = data;
                appendAuthCard(data.auth_uri);
            } else {
                appendMessage('bot', data.response);
            }
        } else {
            appendMessage('bot', `Error: ${data.detail}`);
        }
    } catch (err) {
        loader.remove();
        appendMessage('bot', `Network error: ${err.message}`);
    }
}

// Intercept OAuth Callback Message from Popup Window (Fallback)
async function handleOauthCallbackMessage(event) {
    if (event.origin !== window.location.origin) return;
    const data = event.data;
    if (data && data.type === "oauth_callback" && activeAuthRequest) {
        resumeSession(data.url);
    }
}

async function resumeSession(callbackUrl) {
    if (pollTimer) {
        clearInterval(pollTimer);
        pollTimer = null;
    }
    if (!activeAuthRequest) return;
    const authReq = activeAuthRequest;
    activeAuthRequest = null; // Clear immediately to prevent concurrent calls

    appendSystemMessage("OAuth login success! Exchanging code and resuming conversation...");
    
    // Show typing indicator
    const loader = appendTypingIndicator();
    
    try {
        const response = await fetch('/api/resume', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                session_id: activeSessionId,
                user_id: userIdInput.value.trim(),
                auth_response_uri: callbackUrl,
                call_id: authReq.call_id,
                invocation_id: authReq.invocation_id,
                auth_uri: authReq.auth_uri
            })
        });
        const resData = await response.json();
        
        loader.remove();
        
        if (response.ok) {
            // Process tool calls list
            if (resData.tool_calls) {
                resData.tool_calls.forEach(tc => {
                    if (tc.type === "call") {
                        logToolCall(tc.name, tc.id);
                    } else if (tc.type === "response") {
                        completeToolCall(tc.id);
                    }
                });
            }
            appendMessage('bot', resData.response);
        } else {
            appendMessage('bot', `Failed to resume: ${resData.detail}`);
        }
    } catch (err) {
        loader.remove();
        appendMessage('bot', `Network error resuming session: ${err.message}`);
    }
}

function appendMessage(sender, text) {
    const messageDiv = document.createElement('div');
    messageDiv.classList.add('message', sender);
    
    const avatarDiv = document.createElement('div');
    avatarDiv.classList.add('avatar');
    avatarDiv.innerHTML = sender === 'user' ? '<i class="fa-regular fa-user"></i>' : '<i class="fa-solid fa-robot"></i>';
    
    const contentDiv = document.createElement('div');
    contentDiv.classList.add('message-content');
    
    // Parse markdown for bot messages, but escape html for user messages
    if (sender === 'user') {
        contentDiv.innerHTML = `<p>${escapeHtml(text)}</p>`;
    } else {
        contentDiv.innerHTML = typeof marked !== 'undefined' ? marked.parse(text) : `<p>${escapeHtml(text)}</p>`;
    }
    
    messageDiv.appendChild(avatarDiv);
    messageDiv.appendChild(contentDiv);
    
    chatHistory.appendChild(messageDiv);
    scrollToBottom();
}

function appendAuthCard(authUri) {
    const messageDiv = document.createElement('div');
    messageDiv.classList.add('message', 'bot');
    
    const avatarDiv = document.createElement('div');
    avatarDiv.classList.add('avatar');
    avatarDiv.innerHTML = '<i class="fa-solid fa-shield-halved"></i>';
    
    const contentDiv = document.createElement('div');
    contentDiv.classList.add('message-content', 'auth-card');
    
    const body = document.createElement('div');
    body.classList.add('auth-card-body');
    
    const title = document.createElement('div');
    title.classList.add('auth-title');
    title.innerHTML = '<i class="fa-solid fa-lock-open"></i> Authorization Required';
    
    const desc = document.createElement('p');
    desc.textContent = "To complete this action securely, you must log in through your identity provider.";
    
    const authBtn = document.createElement('button');
    authBtn.classList.add('btn', 'btn-auth');
    authBtn.innerHTML = '<i class="fa-solid fa-arrow-up-right-from-square"></i> Login';
    authBtn.addEventListener('click', () => {
        const popup = window.open(authUri, 'oauth-popup', 'width=500,height=650,status=yes,toolbar=no,menubar=no,location=yes');
        
        if (pollTimer) clearInterval(pollTimer);
        // Parent-side secure backend status polling loop
        pollTimer = setInterval(async () => {
            try {
                const response = await fetch(`/api/check_auth?session_id=${activeSessionId}`);
                const data = await response.json();
                
                if (response.ok && data.completed) {
                    clearInterval(pollTimer);
                    pollTimer = null;
                    if (popup) popup.close();
                    resumeSession(data.callback_url); // Trigger resume immediately!
                    return;
                }
            } catch (e) {
                // Silently ignore network glitches during polling
            }
            
            if (popup && popup.closed) {
                clearInterval(pollTimer);
                pollTimer = null;
                return;
            }
        }, 800);
    });
    
    body.appendChild(title);
    body.appendChild(desc);
    body.appendChild(authBtn);
    contentDiv.appendChild(body);
    
    messageDiv.appendChild(avatarDiv);
    messageDiv.appendChild(contentDiv);
    
    chatHistory.appendChild(messageDiv);
    scrollToBottom();
}

function appendTypingIndicator() {
    const messageDiv = document.createElement('div');
    messageDiv.classList.add('message', 'bot');
    
    const avatarDiv = document.createElement('div');
    avatarDiv.classList.add('avatar');
    avatarDiv.innerHTML = '<i class="fa-solid fa-robot"></i>';
    
    const contentDiv = document.createElement('div');
    contentDiv.classList.add('message-content');
    
    const indicator = document.createElement('div');
    indicator.classList.add('typing-indicator');
    indicator.innerHTML = '<span></span><span></span><span></span>';
    
    contentDiv.appendChild(indicator);
    messageDiv.appendChild(avatarDiv);
    messageDiv.appendChild(contentDiv);
    
    chatHistory.appendChild(messageDiv);
    scrollToBottom();
    
    return messageDiv;
}

function appendSystemMessage(text) {
    const systemDiv = document.createElement('div');
    systemDiv.style.textAlign = 'center';
    systemDiv.style.color = 'var(--text-secondary)';
    systemDiv.style.fontSize = '0.8rem';
    systemDiv.style.margin = '1rem 0';
    systemDiv.style.fontStyle = 'italic';
    systemDiv.textContent = text;
    chatHistory.appendChild(systemDiv);
    scrollToBottom();
}

function clearChatLogs() {
    chatHistory.innerHTML = '';
    appendSystemMessage("Chat screen cleared.");
}

function copySessionIdToClipboard() {
    if (!activeSessionId) return;
    navigator.clipboard.writeText(activeSessionId).then(() => {
        appendSystemMessage("Session ID copied to clipboard!");
    });
}

function scrollToBottom() {
    chatHistory.scrollTop = chatHistory.scrollHeight;
}

function escapeHtml(string) {
    return String(string).replace(/[&<>"']/g, function (s) {
        return {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }[s];
    });
}

// Global helper for predefined prompt chips
window.usePrompt = function(text) {
    if (!activeSessionId) return;
    chatInput.value = text;
    // Dispatch submit event on chatForm to trigger handleMessageSubmit cleanly
    chatForm.dispatchEvent(new Event('submit'));
};

function logToolCall(toolName, callId) {
    const logContainer = document.getElementById("tools-log");
    if (!logContainer) return;
    
    const logItem = document.createElement("div");
    logItem.id = `tool-log-${callId}`;
    logItem.className = "tool-log-item active";
    
    // Determine the appropriate icon (MCP logo for proxies, gear icon for general)
    let iconHtml = '<i class="fa-solid fa-gear"></i>';
    if (toolName.startsWith("mcp_proxy_")) {
        iconHtml = '<img src="/static/mcp.svg" alt="MCP" style="width: 14px; height: 14px; object-fit: contain;" />';
    }
    
    // Clean all agent/mcp prefixes
    const cleanName = toolName
        .replace("mcp_proxy_prod_", "")
        .replace("mcp_proxy_dev_", "")
        .replace("mcp_proxy_alpha_", "")
        .replace("mcp_proxy_", "");
        
    logItem.innerHTML = `
        ${iconHtml}
        <span style="color: #e2e8f0; font-weight: 500;">${cleanName}</span>
    `;
    
    logContainer.appendChild(logItem);
    logContainer.scrollTop = logContainer.scrollHeight;
}

function completeToolCall(callId) {
    const logItem = document.getElementById(`tool-log-${callId}`);
    if (logItem) {
        logItem.classList.remove("active");
    }
}
