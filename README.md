# AI History & Money Making

A comprehensive website exploring the evolution of artificial intelligence and opportunities to monetize AI knowledge.

## Website Features

- **AI History Timeline** - From 1950s foundations to present day generative AI
- **AI Pioneers** - Biographies of key figures in AI development
- **Case Studies** - How major companies leveraged AI
- **Resources** - Tools, courses, books, and software recommendations
- **AI Chat Widget** - Powered by OpenRouter (Mixtral) or local Ollama

## Quick Start

### Prerequisites
- [Git](https://git-scm.com) installed
- [GitHub account](https://github.com)

### Local Development

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/AI-History.git
cd AI-History
```

2. Open `index.html` in your browser, or use a local server:
```bash
# Using Python
python -m http.server 8000
```

3. Visit `http://localhost:8000`

## AI Chat Setup

### Option 1: OpenRouter (Recommended for GitHub Pages)

1. Get a free API key from https://openrouter.ai
   - Sign up for free account
   - Go to API Keys section
   - Create a new API key
   - Free credits included for new users

2. Edit `assets/js/config.js` and add your API key:
```javascript
window.API_CONFIG = {
  openRouterApiKey: 'YOUR-API-KEY-HERE',
  useOpenRouter: true
};
```

### Option 2: Local Ollama

1. Install [Ollama](https://ollama.com)
2. Start Ollama:
```bash
ollama serve
```
3. The chat widget will connect to your local Ollama server

## Deployment to GitHub Pages

1. Create a new repository on GitHub named `AI-History`
2. Push this code to the repository:
```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/AI-History.git
git push -u origin main
```

3. Go to repository Settings → Pages
4. Under "Build and deployment", select:
   - Source: **Deploy from a branch**
   - Branch: **main** 
   - Folder: **/(root)**

5. Your site will be available at: `https://YOUR_USERNAME.github.io/AI-History/`

## Custom Domain

To use a custom domain:

1. Add your custom domain in repository Settings → Pages
2. Create a `CNAME` file with your domain:
```
yourdomain.com
```
3. Configure your DNS records at your domain provider

## Project Structure

```
AI-History/
├── index.html                    # Homepage
├── assets/
│   ├── css/
│   │   ├── main.css              # Main styles
│   │   ├── responsive.css        # Mobile styles
│   │   └── theme.css            # Theme variables
│   └── js/
│       ├── config.js             # API configuration
│       ├── main.js               # Core functionality
│       ├── api.js                # Ollama/OpenRouter API
│       └── chat.js               # Chat widget
├── pages/
│   ├── timeline/                 # Timeline pages
│   ├── pioneers/                # Pioneer biographies
│   ├── case-studies/            # Company case studies
│   └── resources/               # Tools, courses, books
├── .github/workflows/           # GitHub Actions
└── _config.yml                 # Jekyll config
```

## Technologies Used

- Pure HTML/CSS/JavaScript (no frameworks)
- GitHub Pages for hosting
- OpenRouter API (Mixtral) for AI chat
- Fallback to local Ollama

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - Feel free to use and modify for your own projects.

---

Built with 🤖 and Mixtral via OpenRouter
