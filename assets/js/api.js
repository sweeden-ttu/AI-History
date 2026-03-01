// API Module for Ollama + OpenRouter Integration

// Read config from window.API_CONFIG (set in config.js)
const userConfig = window.API_CONFIG || {};

const API_CONFIG = {
  // OpenRouter - Free API with many models
  // Get free API key at https://openrouter.ai/
  openRouterApiKey: userConfig.openRouterApiKey || '',
  openRouterBaseUrl: 'https://openrouter.ai/api/v1',
  
  // Default to using OpenRouter if API key is set
  useOpenRouter: userConfig.useOpenRouter !== undefined ? userConfig.useOpenRouter : !!userConfig.openRouterApiKey,
  
  // Fallback to local Ollama
  ollamaBaseUrl: 'http://localhost:11434',
  ollamaModel: 'mistral',
  
  timeout: 60000
};

class AIChatAPI {
  constructor(config = {}) {
    this.openRouterApiKey = config.openRouterApiKey || API_CONFIG.openRouterApiKey;
    this.useOpenRouter = config.useOpenRouter !== undefined ? config.useOpenRouter : API_CONFIG.useOpenRouter;
    this.ollamaBaseUrl = config.ollamaBaseUrl || API_CONFIG.ollamaBaseUrl;
    this.ollamaModel = config.ollamaModel || API_CONFIG.ollamaModel;
    this.timeout = config.timeout || API_CONFIG.timeout;
    this.conversationHistory = [];
  }

  async checkConnection() {
    if (this.useOpenRouter && this.openRouterApiKey) {
      try {
        const response = await fetch(`${API_CONFIG.openRouterBaseUrl}/models`, {
          headers: {
            'Authorization': `Bearer ${this.openRouterApiKey}`
          }
        });
        return response.ok;
      } catch (error) {
        console.error('OpenRouter connection failed:', error);
        return false;
      }
    }
    
    try {
      const response = await fetch(`${this.ollamaBaseUrl}/api/tags`, {
        method: 'GET',
        headers: { 'Content-Type': 'application/json' }
      });
      return response.ok;
    } catch (error) {
      console.error('Connection check failed:', error);
      return false;
    }
  }

  async sendMessage(message, context = '') {
    const systemPrompt = `You are an AI History Expert assistant for the "AI History & Money Making" website. 
Your role is to help users learn about the history of artificial intelligence and how they can potentially monetize AI knowledge.
Only answer questions related to AI history, AI pioneers, AI technologies, or AI money-making opportunities.
If asked about unrelated topics, politely redirect to AI history topics.
Be informative, accurate, and helpful. Keep responses concise but informative.`;

    const userPrompt = context 
      ? `Context: ${context}\n\nUser question: ${message}`
      : message;

    this.conversationHistory.push({
      role: 'user',
      content: userPrompt
    });

    if (this.useOpenRouter && this.openRouterApiKey) {
      return await this.sendToOpenRouter(systemPrompt, userPrompt);
    }
    
    return await this.sendToOllama(systemPrompt, userPrompt);
  }

  async sendToOpenRouter(systemPrompt, userMessage) {
    try {
      const messages = [
        { role: 'system', content: systemPrompt },
        ...this.conversationHistory.slice(-6)
      ];

      const response = await fetch(`${API_CONFIG.openRouterBaseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.openRouterApiKey}`,
          'HTTP-Referer': window.location.href,
          'X-Title': 'AI History & Money Making'
        },
        body: JSON.stringify({
          model: 'openrouter/free',
          messages: messages,
          max_tokens: 500,
          temperature: 0.7
        }),
        signal: AbortSignal.timeout(this.timeout)
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error?.message || `API error: ${response.status}`);
      }

      const data = await response.json();
      
      const assistantMessage = data.choices[0].message.content;
      
      this.conversationHistory.push({
        role: 'assistant',
        content: assistantMessage
      });

      return {
        success: true,
        message: assistantMessage,
        done: true
      };
    } catch (error) {
      console.error('OpenRouter API Error:', error);
      return {
        success: false,
        error: error.message,
        isConnectionError: error.name === 'AbortError'
      };
    }
  }

  async sendToOllama(systemPrompt, userMessage) {
    try {
      const response = await fetch(`${this.ollamaBaseUrl}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: this.ollamaModel,
          messages: [
            { role: 'system', content: systemPrompt },
            ...this.conversationHistory.slice(-6)
          ],
          stream: false,
          options: {
            temperature: 0.7,
            top_p: 0.9,
            num_predict: 500
          }
        }),
        signal: AbortSignal.timeout(this.timeout)
      });

      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }

      const data = await response.json();
      
      this.conversationHistory.push({
        role: 'assistant',
        content: data.message.content
      });

      return {
        success: true,
        message: data.message.content,
        done: data.done
      };
    } catch (error) {
      console.error('Ollama API Error:', error);
      return {
        success: false,
        error: error.message,
        isConnectionError: error.name === 'AbortError' || error.message.includes('Failed to fetch')
      };
    }
  }

  clearHistory() {
    this.conversationHistory = [];
  }
}

window.AIChatAPI = AIChatAPI;
