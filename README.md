# AI Battleground

AI Battleground is a macOS application that lets you test and compare different AI language models side by side. It provides a unified interface for interacting with multiple AI services and comparing their responses to the same prompts. Head-to-Head Model Combat - Send your AI LLM prompt to 40+ large language models to see how they all respond.  Supports OpenAI, Anthropic's Claude, Google Gemini, and Deepseek out of the box, plus you can add any others that support either the OpenAI or Anthropic (Claude) API.


## Features

### Service Management
- Configure multiple AI services (OpenAI, Claude, DeepSeek, etc.)
- Securely store API credentials in the macOS keychain
- Automatic validation of service configurations
- Visual indicators for service status and issues

### Model Management
- View available models from each configured service
- Enable/disable specific models
- Filter models by name, provider, or other attributes
- Automatic model compatibility filtering

### Challenge Mode
- Send the same prompt to multiple AI models simultaneously
- Compare responses side by side
- Copy individual responses
- Retry failed requests
- Persistent prompt history

## Getting Started

1. Launch the app and navigate to the "Services" tab
2. Add your AI service configurations:
   - Click "Add Service"
   - Choose a service provider (e.g., OpenAI)
   - Enter your API key and other required information
   - The app will validate your configuration

3. Go to the "Models" tab to:
   - View available models from your configured services
   - Enable the models you want to test
   - Filter models to find specific ones

4. Use the "Challenge" tab to:
   - Select which enabled models to test
   - Enter your prompt
   - Send the prompt to all selected models
   - Compare their responses

## Security

- API keys are stored securely in the macOS keychain
- Keys are never exposed in the UI after entry
- Keychain items are shared across app instances using a keychain access group
- No data is sent to external services except the AI providers you configure

## Requirements

- macOS 14.0 or later
- Valid API keys for the services you want to test

## Support

For issues, feature requests, or contributions, please visit the project's GitHub repository.

## License

MIT License

## Copyright

Copyright (C) 2025 Nuclear Cyborg Corp
