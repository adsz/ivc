#!/bin/bash
# Setup GitHub Actions Runner for adsz/ivc repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RUNNER_NAME="devops-lab-runner"
RUNNER_WORKDIR="/opt/actions-runner-ivc"
RUNNER_USER="github-runner"
REPO_OWNER="adsz"
REPO_NAME="ivc"

echo -e "${BLUE}GitHub Actions Self-Hosted Runner Setup${NC}"
echo "========================================"
echo ""

echo -e "${YELLOW}To set up the runner, you need to:${NC}"
echo ""
echo "1. Go to: https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/actions/runners"
echo "2. Click 'New self-hosted runner'"
echo "3. Choose 'Linux' and architecture"
echo "4. Copy the token from the configuration command"
echo ""
echo -e "${BLUE}Then run these commands:${NC}"
echo ""

cat << 'EOF'
# Create runner directory
sudo mkdir -p /opt/actions-runner-ivc
sudo chown -R $(whoami) /opt/actions-runner-ivc
cd /opt/actions-runner-ivc

# Download the latest runner package
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz

# Create the runner and configure it
./config.sh --url https://github.com/adsz/ivc \
  --token YOUR_TOKEN_HERE \
  --name devops-lab-runner \
  --labels self-hosted,linux,x64,local \
  --work _work

# Install as a service (optional but recommended)
sudo ./svc.sh install
sudo ./svc.sh start

# Check service status
sudo ./svc.sh status
EOF

echo ""
echo -e "${GREEN}After configuration, the runner will appear in:${NC}"
echo "https://github.com/${REPO_OWNER}/${REPO_NAME}/settings/actions/runners"
echo ""

# Check if UV is installed
echo -e "${BLUE}Checking UV installation...${NC}"
if command -v uv &> /dev/null; then
    echo -e "${GREEN}✓ UV is installed: $(uv --version)${NC}"
else
    echo -e "${YELLOW}UV not found. Installing...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo -e "${GREEN}✓ UV installed successfully${NC}"
fi

# Check Docker access
echo -e "${BLUE}Checking Docker access...${NC}"
if docker info &> /dev/null; then
    echo -e "${GREEN}✓ Docker is accessible${NC}"
else
    echo -e "${YELLOW}! Docker needs sudo or user needs to be in docker group${NC}"
    echo "  Run: sudo usermod -aG docker $(whoami)"
fi

echo ""
echo -e "${GREEN}Setup instructions complete!${NC}"