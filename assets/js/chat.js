// Chat Widget Module

class ChatWidget {
  constructor(api) {
    this.api = api;
    this.isOpen = false;
    this.isConnected = false;
    this.init();
  }

  init() {
    this.createWidget();
    this.bindEvents();
    this.checkConnection();
  }

  createWidget() {
    const widgetHTML = `
      <button class="chat-toggle" id="chatToggle" aria-label="Open AI Chat">
        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
          <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/>
        </svg>
      </button>
      <div class="chat-widget" id="chatWidget">
        <div class="chat-header">
          <div>
            <h4>AI History Expert</h4>
            <span class="chat-status" id="chatStatus">Connecting...</span>
          </div>
          <button class="chat-close" id="chatClose" aria-label="Close chat">&times;</button>
        </div>
        <div class="chat-messages" id="chatMessages">
          <div class="chat-message assistant">
            Hello! I'm your AI History expert. Ask me anything about artificial intelligence history, pioneers, or how to monetize AI knowledge!
          </div>
        </div>
        <div class="chat-input-container">
          <input type="text" class="chat-input" id="chatInput" placeholder="Ask about AI history...">
          <button class="chat-send" id="chatSend">Send</button>
        </div>
      </div>
    `;
    
    document.body.insertAdjacentHTML('beforeend', widgetHTML);
    
    this.widget = document.getElementById('chatWidget');
    this.toggle = document.getElementById('chatToggle');
    this.close = document.getElementById('chatClose');
    this.messages = document.getElementById('chatMessages');
    this.input = document.getElementById('chatInput');
    this.send = document.getElementById('chatSend');
    this.status = document.getElementById('chatStatus');
  }

  bindEvents() {
    this.toggle.addEventListener('click', () => this.toggleWidget());
    this.close.addEventListener('click', () => this.closeWidget());
    this.send.addEventListener('click', () => this.sendMessage());
    this.input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') this.sendMessage();
    });
  }

  async checkConnection() {
    const connected = await this.api.checkConnection();
    this.isConnected = connected;
    
    if (connected) {
      this.status.textContent = 'Online';
      this.status.classList.add('online');
      this.status.classList.remove('offline');
    } else {
      this.status.textContent = 'Offline';
      this.status.classList.add('offline');
      this.status.classList.remove('online');
    }
  }

  toggleWidget() {
    this.isOpen = !this.isOpen;
    this.widget.classList.toggle('active', this.isOpen);
    this.toggle.style.display = this.isOpen ? 'none' : 'flex';
    
    if (this.isOpen) {
      this.input.focus();
      this.checkConnection();
    }
  }

  closeWidget() {
    this.isOpen = false;
    this.widget.classList.remove('active');
    this.toggle.style.display = 'flex';
  }

  addMessage(content, isUser = false) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `chat-message ${isUser ? 'user' : 'assistant'}`;
    messageDiv.textContent = content;
    this.messages.appendChild(messageDiv);
    this.messages.scrollTop = this.messages.scrollHeight;
  }

  showTyping() {
    const typingDiv = document.createElement('div');
    typingDiv.className = 'chat-message assistant typing';
    typingDiv.id = 'typingIndicator';
    typingDiv.textContent = 'Thinking';
    this.messages.appendChild(typingDiv);
    this.messages.scrollTop = this.messages.scrollHeight;
  }

  hideTyping() {
    const typing = document.getElementById('typingIndicator');
    if (typing) typing.remove();
  }

  async sendMessage() {
    const message = this.input.value.trim();
    if (!message) return;

    this.input.value = '';
    this.addMessage(message, true);

    if (!this.isConnected) {
      this.addMessage('AI is offline. To enable chat:\n\n1. Get free API key at https://openrouter.ai\n2. Edit assets/js/config.js\n3. Add your API key\n\nOr run Ollama locally with Mixtral.', false);
      return;
    }

    this.showTyping();

    const result = await this.api.sendMessage(message);

    this.hideTyping();

    if (result.success) {
      this.addMessage(result.message, false);
    } else {
      if (result.isConnectionError) {
        this.addMessage('Connection failed. Check your API key in config.js or ensure Ollama is running.', false);
        this.isConnected = false;
        this.status.textContent = 'Offline';
        this.status.classList.add('offline');
        this.status.classList.remove('online');
      } else {
        this.addMessage(`Error: ${result.error}`, false);
      }
    }
  }
}

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  // Read config
  const config = window.API_CONFIG || {};
  
  window.chatAPI = new AIChatAPI({
    openRouterApiKey: config.openRouterApiKey,
    useOpenRouter: config.useOpenRouter !== false
  });
  window.chatWidget = new ChatWidget(window.chatAPI);
});
