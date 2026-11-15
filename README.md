# Universal Backup System

![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)
![macOS](https://img.shields.io/badge/macOS-10.15%2B-green.svg)
![Linux](https://img.shields.io/badge/Linux-Ubuntu%2018%2B-orange.svg)
![License](https://img.shields.io/badge/License-GPLv3-blue.svg)

A modular, cross-platform backup system for developers. Automatically backs up your projects to Git, GitHub, TGZ archives, and session documentation.

## Features

- **Git Backup**: Automatic commits and GitHub uploads
- **TGZ Archives**: Compressed project backups with checksum verification
- **Session Documentation**: Automatic capture of project state and development notes
- **Project Detection**: Smart discovery of projects across different environments
- **Highly Configurable**: Enable/disable components as needed
- **Cross-Platform**: Works on Windows (WSL), macOS, and Linux
- **Claude Code Integration**: Optional integration with Claude Code/Atlas

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/universal-backup-system.git
cd universal-backup-system

# Run setup wizard
./backup-system.sh --setup
```

### Configuration

The setup wizard will create `~/.backup-system/config/backup-settings.conf` with your preferences:

```bash
# GitHub Settings
GITHUB_USERNAME="your-github-username"
SSH_KEY_NAME="id_rsa"
REPO_VISIBILITY="private"

# Backup Components (true/false)
ENABLE_GITHUB_UPLOAD="true"
ENABLE_TGZ_CREATION="true"
ENABLE_SESSION_BACKUP="true"

# Claude Code / Atlas Integration (true/false)
ENABLE_ATLAS_INTEGRATION="true"  # Auto-detected
```

### Usage

```bash
# Full backup (git + tgz + session)
./backup-system.sh my-project full

# Quick git backup only
./backup-system.sh my-project quick

# Session documentation only
./backup-system.sh my-project session

# Backup all projects
./backup-system.sh all full

# List available projects
./backup-system.sh list
```

## Project Types

Configure your project locations in `~/.backup-system/config/project-paths.conf`:

```bash
# Common Project Types
GIT_PROJECT="$HOME/projects/$PROJECT_NAME"
NODEJS_PROJECT="$HOME/nodejs/$PROJECT_NAME"
WORDPRESS_THEME="$HOME/wordpress/themes/$PROJECT_NAME"
```

Map specific projects in `~/.backup-system/config/project-types.conf`:

```bash
# Map project names to types
my-website=WORDPRESS_THEME
my-api=NODEJS_PROJECT
my-tool=GIT_PROJECT
```

## Backup Components

### Git Backup
- Automatic commits with timestamps
- GitHub repository creation (if doesn't exist)
- SSH authentication handling
- Branch management (main branch)

### TGZ Archives
- Compressed backups with exclusions (node_modules, .git)
- Checksum verification (skips if no changes)
- Configurable retention periods
- Project-relative storage

### Session Documentation
- Automatic capture of git status and recent commits
- Integration with CLAUDE.md files
- Session history tracking
- Current state snapshots

## Configuration Options

### Backup Components
```bash
ENABLE_GITHUB_UPLOAD="true"    # Upload to GitHub
ENABLE_TGZ_CREATION="true"     # Create compressed archives
ENABLE_SESSION_BACKUP="true"   # Capture session docs
```

### Storage Locations
```bash
TGZ_BACKUP_LOCATION="auto"     # auto or custom path
SESSION_BACKUP_LOCATION="auto" # auto or custom path
```

### Integration
```bash
ENABLE_ATLAS_INTEGRATION="true"  # Claude Code integration
ATLAS_ROOT_DIR="$HOME/.claude/atlas"
```

## Claude Code Integration

When Claude Code/Atlas is detected, the system automatically:
- Updates Atlas session files
- Integrates with existing project tracking
- Uses Atlas directory structure
- Maintains compatibility with Claude workflows

## Standalone Mode

Without Claude Code, the system:
- Creates `.sessions` directories in project folders
- Uses standard git workflows
- Maintains all backup functionality
- Works with any development environment

## Platform Support

### Windows (WSL)
- Automatic GitHub CLI detection
- SSH key management
- Path translation

### macOS
- Homebrew GitHub CLI support
- Native SSH integration
- Unix path handling

### Linux
- Package manager GitHub CLI detection
- Standard SSH workflows
- Universal compatibility

## Troubleshooting

### SSH Authentication
```bash
# Test SSH connection
ssh -T git@github.com

# Add SSH key manually
ssh-add ~/.ssh/id_rsa
```

### GitHub CLI
```bash
# Install GitHub CLI
# Windows: winget install GitHub.cli
# macOS: brew install gh
# Linux: apt install gh / yum install gh

# Authenticate
gh auth login
```

### Project Detection
```bash
# Check project configuration
./backup-system.sh list

# Add project mapping
echo "my-project=GIT_PROJECT" >> ~/.backup-system/config/project-types.conf
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on your system
5. Submit a pull request

## License

GPLv3 License

---

**⭐ If this utility saved you time, please star the repository!**

## 💖 Support This Project

If this tool has made your development workflow smoother, consider supporting its continued development!

## Buy me a coffee

Every coffee ☕ helps fuel more features and improvements!

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://plexpixel.com/donate)

**Funding priorities**

- Continued development
- New signals and views
- Faster fixes and updates
- Better documentation

**Even small contributions make a big difference!** Every coffee helps keep this project actively maintained and growing.

---

*Made with ❤️ for the developer community*
