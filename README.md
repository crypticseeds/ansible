# Ansible Control Node Setup

A clean, testable Ansible control setup for managing remote development servers (Ubuntu and RHEL).

## Quick Start

### Prerequisites
- Python 3.13+
- uv package manager
- Doppler CLI (for secrets)
- Docker (for Molecule testing)

### Initial Setup
```bash
# Install Python dependencies
uv add ansible-lint molecule "molecule-plugins[docker]" pytest pytest-testinfra yamllint pre-commit ruff

# Install Ansible collections
ansible-galaxy install -r requirements.yml

# Set up pre-commit hooks
uv run pre-commit install

# Generate dedicated Ansible SSH key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_key -C "ansible@control-node"
```

### SSH Configuration
Add to `~/.ssh/config`:
```
Host dev-*
    User ansible
    IdentityFile ~/.ssh/ansible_key
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Doppler Setup
```bash
# Create Doppler project
doppler setup

# Add secrets
doppler secrets set DB_PASSWORD=your_password
doppler secrets set API_KEY=your_api_key
doppler secrets set SSH_PRIVATE_KEY=your_private_key
```

## Usage

### One-time bootstrap (new hosts)
Run this once to create the `ansible` user and configure SSH on new machines using the temporary inventory `inventories/dev/host_startup.yml`:

```bash
doppler run -- ansible-playbook -i inventories/dev/host_startup.yml playbooks/startup.yml
```

After this initial setup, run other playbooks normally; they will use the default inventory defined in `ansible.cfg` (`inventories/dev/hosts.yml`).

### Basic Commands
```bash
# Run playbook on all hosts
doppler run -- ansible-playbook playbooks/site.yml

# Run on specific host
doppler run -- ansible-playbook playbooks/site.yml --limit dev-web-01

# Run on specific OS group
doppler run -- ansible-playbook playbooks/site.yml --limit ubuntu
doppler run -- ansible-playbook playbooks/site.yml --limit rhel

# Run with specific tags
doppler run -- ansible-playbook playbooks/site.yml --tags packages

# Install development utilities
doppler run -- ansible-playbook playbooks/utilities.yml

# Dry run with diff
doppler run -- ansible-playbook playbooks/site.yml --check --diff

# Test roles with Molecule
uv run molecule test

# Lint and format
ansible-lint
uv run ruff check .
uv run ruff format .
```

### Environment Variables (Doppler)
Currently, no secrets are required for the basic setup. Secrets will be needed when you add:

**Database Connections:**
- `DB_PASSWORD`: Database password
- `DB_HOST`: Database host
- `DB_USER`: Database user

**API Integrations:**
- `GITHUB_TOKEN`: GitHub API token
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key

**Application Secrets:**
- `APP_SECRET_KEY`: Application secret key
- `REDIS_PASSWORD`: Redis authentication
- `JWT_SECRET`: JWT signing secret

**SSH Keys (if using external keys):**
- `SSH_PRIVATE_KEY`: SSH private key content

## Utilities Playbook

The `utilities.yml` playbook installs and configures essential development utilities:

### Installed Utilities
- **tmux**: Terminal multiplexer
- **fzf**: Fuzzy finder with bash integration
- **zoxide**: Smart directory navigation
- **bat**: Enhanced cat with syntax highlighting
- **btop**: System monitoring (via snap)
- **duf**: Disk usage utility
- **ripgrep**: Fast grep alternative
- **tldr**: Simplified man pages (via snap)
- **eza**: Modern ls replacement

### Configuration
- Creates `~/.local/bin` directory for user binaries
- Sets up bat symlink (`batcat` → `bat`)
- Configures bash completions
- Adds utility aliases and environment variables
- Sets up fzf with custom styling and preview

### Usage
```bash
# Install all utilities
doppler run -- ansible-playbook playbooks/utilities.yml

# Install on specific host
doppler run -- ansible-playbook playbooks/utilities.yml --limit dev-web-01

# Dry run to see what would be installed
doppler run -- ansible-playbook playbooks/utilities.yml --check --diff
```

## Project Structure
```
/root/remote-dev/
├── ansible.cfg              # Ansible configuration
├── pyproject.toml           # Python dependencies
├── requirements.yml         # Ansible collections
├── inventories/
│   └── dev/                # Development environment
│       ├── hosts.yml       # Host definitions (default after bootstrap)
│       ├── host_startup.yml # Temporary inventory for one-time bootstrap
│       └── group_vars/     # Group variables
├── playbooks/
│   ├── site.yml           # Main playbook
│   ├── startup.yml        # Startup configuration
│   └── utilities.yml      # Development utilities installation
├── roles/
│   └── common/            # Common role (cross-distro)
└── molecule/              # Role testing
```

## Development

### Adding New Roles
```bash
# Create new role
ansible-galaxy init roles/new_role

# Test role
cd roles/new_role
uv run molecule init scenario new_scenario -d docker
uv run molecule test
```

### Adding New Hosts
1. Add host to `inventories/dev/hosts.yml`
2. Add host-specific vars to `inventories/dev/host_vars/` if needed
3. Test with: `ansible-playbook playbooks/site.yml --limit new-host --check`

### CI/CD Workflow
The project uses GitHub Actions for automated quality checks:

1. **Create a branch** for your changes
2. **Make changes** to playbooks, roles, or inventory
3. **Test locally**:
   ```bash
   ansible-lint
   uv run molecule test
   ```
4. **Commit and push** - CI will automatically run linting
5. **Create pull request** - CI will run on PR
6. **Merge** when CI passes and review is complete

## Troubleshooting

### Common Issues
- **SSH Connection**: Ensure SSH key is added to target servers
- **Python Missing**: RHEL minimal images may need Python installed first
- **Permission Denied**: Check `ansible_user` and `ansible_become` settings

### Debug Commands
```bash
# Test SSH connection
ssh -i ~/.ssh/ansible_key ansible@target-server

# Check Ansible facts
ansible-inventory --list

# Verbose output
doppler run -- ansible-playbook playbooks/site.yml -vvv
```

## CI/CD Integration

### GitHub Actions
The project includes automated CI/CD workflows:

- **Ansible Lint**: Automatically lints playbooks and roles on pull requests and pushes
- **Triggered on**: `main`, `stable`, and `release/v*` branches
- **Runs on**: Ubuntu 24.04 with Python setup

### Local Development
```bash
# Run linting locally (same as CI)
ansible-lint

# Run with verbose output
ansible-lint --verbose

# Run on specific files
ansible-lint playbooks/site.yml
ansible-lint roles/common/
```

## Best Practices
- Always use `--check` before running on production
- Use tags for selective role execution
- Keep roles idempotent and cross-distro compatible
- Test roles with Molecule before deployment
- Use Doppler for all secrets, never hardcode
- Run `ansible-lint` before committing changes
```

**Updated ansible.cfg** (with performance optimizations):
```ini
[defaults]
inventory = inventories/dev/hosts.yml
stdout_callback = yaml
bin_ansible_callbacks = True
forks = 20
gathering = smart
fact_caching = jsonfile
fact_caching_connection = .ansible_cache
fact_caching_timeout = 86400
retry_files_enabled = False
host_key_checking = True
interpreter_python = auto_silent
roles_path = roles:collections/ansible_collections
collections_paths = collections
timeout = 30
display_skipped_hosts = false
display_ok_hosts = false

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

**Updated playbooks/site.yml** (with tags and error handling):
```yaml
-
