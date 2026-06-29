# Setup pi

curl -fsSL https://pi.dev/install.sh | sh

# Create agents directory and models.json configuration (only if not already present)
mkdir -p "$HOME/.pi/agent"

if [ ! -f "$HOME/.pi/agent/models.json" ]; then
  cat > "$HOME/.pi/agent/models.json" << 'EOF'
{
  "providers": {
    "name-of-your-server": {
      "baseUrl": "http://localhost:port/v1",
      "api": "openai-completions",
      "apiKey": "nonerequired",
      "models": [
        {
          "id": "model-name-in-inference-engine",
          "name": "Pretty Model Name",
          "reasoning": true,
          "input": [
            "text"
          ],
          "contextWindow": 128000,
          "maxTokens": 32000,
          "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0
          }
        }
      ]
    }
  }
}
EOF
fi

