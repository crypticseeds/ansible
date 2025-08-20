#!/bin/bash

# Ansible Control Node Setup Script
set -e

echo "🚀 Setting up Ansible Control Node..."

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ uv is not installed. Please install uv first."
    exit 1
fi

# Check if Doppler is installed
if ! command -v doppler &> /dev/null; then
    echo "❌ Doppler CLI is not installed. Please install Doppler first."
    exit 1
fi

echo ""

# Install Python dependencies
echo "📦 Installing Python dependencies..."
uv add ansible-lint molecule "molecule-plugins[docker]" pytest pytest-testinfra yamllint pre-commit ruff

echo ""

# Install Ansible collections
echo "🔧 Installing Ansible collections..."
ansible-galaxy install -r requirements.yml

echo ""

# Set up pre-commit hooks
echo "🔗 Setting up pre-commit hooks..."
uv run pre-commit install

echo ""

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/ansible_key ]; then
    echo "🔑 Generating SSH key for Ansible..."
    ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -N "" -C "rhel-control"
    echo "✅ SSH key generated: ~/.ssh/ansible_key"
else
    echo "✅ SSH key already exists: ~/.ssh/ansible_key"
fi

# Create SSH config if it doesn't exist
if [ ! -f ~/.ssh/config ]; then
    echo "📝 Creating SSH config..."
    cat > ~/.ssh/config << EOF
Host dev-*
    User ansible
    IdentityFile ~/.ssh/ansible_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    chmod 600 ~/.ssh/config
    echo "✅ SSH config created: ~/.ssh/config"
else
    echo "✅ SSH config already exists: ~/.ssh/config"
fi

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Add your target server to inventory.txt"
echo "2. Update inventories/dev/hosts.yml with correct IP/hostname"
echo "3. Run: ansible-playbook playbooks/startup.yml --limit local-dev"
echo "4. After startup, run: ansible-playbook playbooks/site.yml"
echo ""
echo "The startup playbook will automatically detect the initial user (femi/ubuntu/root)"
echo "and set up the ansible user with sudo access."
echo ""
echo "For Doppler secrets:"
echo "1. Visit: https://docs.doppler.com/docs/install-cli"
echo "2. Run: doppler login"
echo "3. Run: doppler setup"
echo "4. Add secrets: doppler secrets set SECRET_NAME=value"
echo "5. Run playbooks with: doppler run -- ansible-playbook playbook.yml"
