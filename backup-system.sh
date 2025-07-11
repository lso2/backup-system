#!/bin/bash
# Centralized Backup System for All Projects
# Usage: 
#   ./backup-system.sh [project-name] [backup-type]
#   ./backup-system.sh polish full
#   ./backup-system.sh tickpulse quick
#   ./backup-system.sh all daily

PROJECT=$1
BACKUP_TYPE=${2:-full}  # Default to full backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ROOT_DIR="$HOME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== BACKUP SYSTEM ===${NC}"
echo "Timestamp: $(date)"
echo ""

# Function to get project working directory using config-based detection
get_working_dir() {
    local project=$1
    local current_state_file="$ROOT_DIR/.claude/atlas/atlas-$project/CURRENT_STATE.md"
    local config_dir="$ROOT_DIR/.backup-system/config"
    
    # First try to extract from CURRENT_STATE.md
    if [ -f "$current_state_file" ]; then
        local extracted_dir=$(grep -A 3 "Working Directory" "$current_state_file" | grep -v "Working Directory" | grep -v "\`\`\`" | head -1 | xargs)
        if [ -n "$extracted_dir" ] && [ "$extracted_dir" != "[Add your project working directory path here]" ]; then
            echo "$extracted_dir"
            return
        fi
    fi
    
    # Load configuration files
    if [ ! -f "$config_dir/project-paths.conf" ] || [ ! -f "$config_dir/project-types.conf" ]; then
        echo "⚠️  Config files missing: $config_dir/project-*.conf"
        echo ""
        return
    fi
    
    # Source path patterns
    source "$config_dir/project-paths.conf"
    
    # Check if project has explicit type mapping
    local project_type=""
    if grep -q "^$project=" "$config_dir/project-types.conf"; then
        project_type=$(grep "^$project=" "$config_dir/project-types.conf" | cut -d'=' -f2)
        echo "🎯 Project type: $project_type (from config)"
        
        # Get path pattern for this type
        local path_pattern_var="${project_type}"
        local path_pattern="${!path_pattern_var}"
        
        if [ -n "$path_pattern" ]; then
            # Replace $PROJECT_NAME with actual project name
            local resolved_path="${path_pattern//\$PROJECT_NAME/$project}"
            
            # Handle wildcard paths (like flywheel)
            if [[ "$resolved_path" == *"*"* ]]; then
                for expanded_path in $resolved_path; do
                    if [ -d "$expanded_path" ]; then
                        echo "$expanded_path"
                        return
                    fi
                done
            else
                if [ -d "$resolved_path" ]; then
                    echo "$resolved_path"
                    return
                fi
            fi
        fi
    fi
    
    # Fallback: search in default order
    echo "🔍 Searching in default order..."
    for search_type in $DEFAULT_SEARCH_ORDER; do
        local path_pattern_var="$search_type"
        local path_pattern="${!path_pattern_var}"
        
        if [ -n "$path_pattern" ]; then
            local resolved_path="${path_pattern//\$PROJECT_NAME/$project}"
            
            # Handle wildcard paths
            if [[ "$resolved_path" == *"*"* ]]; then
                for expanded_path in $resolved_path; do
                    if [ -d "$expanded_path" ]; then
                        echo "📁 Found: $expanded_path ($search_type)"
                        echo "$expanded_path"
                        return
                    fi
                done
            else
                if [ -d "$resolved_path" ]; then
                    echo "📁 Found: $resolved_path ($search_type)"
                    echo "$resolved_path"
                    return
                fi
            fi
        fi
    done
    
    echo "❌ Project directory not found for: $project"
    echo "💡 Add to $config_dir/project-types.conf: $project=PROJECT_TYPE"
    echo ""
}

# Function to setup GitHub remote repository
setup_github_remote() {
    local project=$1
    
    echo -e "${BLUE}🔗 Setting up GitHub remote for $project${NC}"
    
    # Load GitHub configuration
    local config_file="$ROOT_DIR/.backup-system/config/backup-settings.conf"
    local github_user=""
    local ssh_key_name=""
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        github_user="$GITHUB_USERNAME"
        ssh_key_name="$SSH_KEY_NAME"
        repo_visibility="${REPO_VISIBILITY:-private}"
    else
        echo -e "${RED}❌ GitHub config file not found: $config_file${NC}"
        echo "Please create the config file with your GitHub settings"
        return 1
    fi
    
    if [ -z "$github_user" ] || [ -z "$ssh_key_name" ]; then
        echo -e "${RED}❌ GitHub configuration incomplete${NC}"
        echo "Please check $config_file for GITHUB_USERNAME and SSH_KEY_NAME"
        return 1
    fi
    
    echo -e "${BLUE}🔑 Using GitHub user: $github_user${NC}"
    echo -e "${BLUE}🔑 Using SSH key: $ssh_key_name${NC}"
    
    # Setup SSH exactly as done manually
    echo -e "${YELLOW}⚡ Setting up SSH authentication${NC}"
    
    # Use the exact same commands as manual WSL session
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/$ssh_key_name
    
    # Verify the key is loaded and SSH works
    if ssh-add -l | grep -q "$ssh_key_name"; then
        echo -e "${GREEN}✅ SSH key loaded in agent${NC}"
    else
        echo -e "${RED}❌ SSH key not found in agent${NC}"
        return 1
    fi
    
    # Test GitHub SSH connection
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✅ GitHub SSH authentication verified${NC}"
    else
        echo -e "${RED}❌ GitHub SSH test failed${NC}"
        echo "Debug info:"
        echo "SSH_AUTH_SOCK: $SSH_AUTH_SOCK"
        echo "SSH_AGENT_PID: $SSH_AGENT_PID"
        ssh-add -l
        return 1
    fi
    
    # Check if repo exists and create if needed
    echo -e "${YELLOW}📦 Checking if repository exists: $github_user/$project${NC}"
    
    # Test if we can clone the repo (means it exists)
    if git ls-remote "git@github.com:$github_user/$project.git" &>/dev/null; then
        echo -e "${GREEN}✅ Repository exists on GitHub${NC}"
    else
        echo -e "${YELLOW}📦 Creating new $repo_visibility repository on GitHub${NC}"
        
        # Use gh CLI to create repository
        local gh_cli="/mnt/c/Program Files/GitHub CLI/gh.exe"
        if [ -f "$gh_cli" ]; then
            if [ "$repo_visibility" = "public" ]; then
                "$gh_cli" repo create "$github_user/$project" --public --confirm
            else
                "$gh_cli" repo create "$github_user/$project" --private --confirm
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Repository created successfully${NC}"
            else
                echo -e "${RED}❌ Failed to create repository${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ GitHub CLI not found at: $gh_cli${NC}"
            return 1
        fi
    fi
    
    # Add or update remote
    if git remote | grep -q origin; then
        git remote set-url origin "git@github.com:$github_user/$project.git"
        echo -e "${GREEN}✅ Remote URL updated for $github_user/$project${NC}"
    else
        git remote add origin "git@github.com:$github_user/$project.git"
        echo -e "${GREEN}✅ Remote added for $github_user/$project${NC}"
    fi
    
    return 0
}

# Simplified function to just add git remote (SSH already set up)
setup_github_remote_simple() {
    local project=$1
    local github_user=$2
    
    echo -e "${BLUE}🔗 Adding GitHub remote for $project${NC}"
    
    # Add or update remote
    if git remote | grep -q origin; then
        git remote set-url origin "git@github.com:$github_user/$project.git"
        echo -e "${GREEN}✅ Remote URL updated for $github_user/$project${NC}"
    else
        git remote add origin "git@github.com:$github_user/$project.git"
        echo -e "${GREEN}✅ Remote added for $github_user/$project${NC}"
    fi
}

# Function to perform git backup
git_backup() {
    local project=$1
    local working_dir=$2
    local message="$3"
    
    echo -e "${YELLOW}📁 Git Backup: $project${NC}"
    
    if [ ! -d "$working_dir" ]; then
        echo -e "${RED}❌ Working directory not found: $working_dir${NC}"
        return 1
    fi
    
    cd "$working_dir" || return 1
    
    # Check if git repository exists
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}⚠️  No git repository found, initializing...${NC}"
        
        # Initialize git repository
        git init
        
        # Add initial commit
        git add -A
        git commit -m "Initial commit - $project setup"
        
        echo -e "${GREEN}✅ Git repository initialized${NC}"
    fi
    
    # Add all changes
    git add -A
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        echo -e "${GREEN}✅ No changes to commit${NC}"
    else
        # Commit changes
        git commit -m "$message"
        echo -e "${GREEN}✅ Changes committed${NC}"
    fi
    
    # Load backup configuration 
    local config_file="$ROOT_DIR/.backup-system/config/backup-settings.conf"
    local github_user=""
    local ssh_key_name=""
    local repo_visibility=""
    local enable_github=""
    local gh_cli_path=""
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        github_user="$GITHUB_USERNAME"
        ssh_key_name="$SSH_KEY_NAME"
        repo_visibility="${REPO_VISIBILITY:-private}"
        enable_github="${ENABLE_GITHUB_UPLOAD:-true}"
        gh_cli_path="${GITHUB_CLI_PATH:-auto}"
    else
        echo -e "${RED}❌ Backup config file not found: $config_file${NC}"
        echo -e "${BLUE}💡 Run: ./backup-system.sh --setup to create configuration${NC}"
        return 1
    fi
    
    # Skip GitHub operations if disabled
    if [ "$enable_github" != "true" ]; then
        echo -e "${YELLOW}⚠️  GitHub upload disabled in config - skipping push${NC}"
        return 0
    fi
    
    # Setup SSH exactly as done manually (needed for all git operations)
    echo -e "${YELLOW}⚡ Setting up SSH authentication${NC}"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/$ssh_key_name
    
    echo -e "${BLUE}🔑 Using GitHub user: $github_user${NC}"
    echo -e "${GREEN}✅ SSH key loaded${NC}"
    
    # Check if repository exists on GitHub and create if needed
    echo -e "${YELLOW}📦 Checking if repository exists: $github_user/$project${NC}"
    
    if git ls-remote "git@github.com:$github_user/$project.git" &>/dev/null; then
        echo -e "${GREEN}✅ Repository exists on GitHub${NC}"
    else
        echo -e "${YELLOW}📦 Creating new $repo_visibility repository on GitHub${NC}"
        
        # Auto-detect or use configured GitHub CLI path
        local gh_cli=""
        if [ "$gh_cli_path" = "auto" ]; then
            # Try common locations
            local gh_locations=(
                "/mnt/c/Program Files/GitHub CLI/gh.exe"
                "/usr/bin/gh"
                "/usr/local/bin/gh"
                "/opt/homebrew/bin/gh"
                "$(which gh 2>/dev/null)"
            )
            
            for location in "${gh_locations[@]}"; do
                if [ -f "$location" ] && [ -x "$location" ]; then
                    gh_cli="$location"
                    echo -e "${GREEN}✅ Found GitHub CLI: $gh_cli${NC}"
                    break
                fi
            done
        else
            gh_cli="$gh_cli_path"
        fi
        
        if [ -f "$gh_cli" ]; then
            if [ "$repo_visibility" = "public" ]; then
                "$gh_cli" repo create "$github_user/$project" --public --confirm
            else
                "$gh_cli" repo create "$github_user/$project" --private --confirm
            fi
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Repository created successfully${NC}"
            else
                echo -e "${RED}❌ Failed to create repository${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ GitHub CLI not found at: $gh_cli${NC}"
            return 1
        fi
    fi
    
    # Setup GitHub remote if not exists
    if ! git remote | grep -q origin; then
        setup_github_remote_simple "$project" "$github_user"
    fi
    
    # Push to remote if it exists
    if git remote | grep -q origin; then
        # Ensure we're on main branch and set upstream
        local current_branch=$(git branch --show-current)
        if [ "$current_branch" != "main" ]; then
            git checkout -b main 2>/dev/null || git checkout main 2>/dev/null
        fi
        
        # Force push on first push (repository was just created)
        if git push -u origin main --force 2>/dev/null; then
            echo -e "${GREEN}✅ Pushed to GitHub (main branch set as upstream)${NC}"
        else
            echo -e "${YELLOW}⚠️  Push failed. Checking SSH authentication...${NC}"
            # Test SSH connection
            if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                echo -e "${GREEN}✅ SSH authentication works${NC}"
                echo -e "${RED}❌ Push failed for unknown reason${NC}"
            else
                echo -e "${RED}❌ SSH authentication failed${NC}"
                echo "Run: ssh -T git@github.com to debug"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  No remote repository configured${NC}"
    fi
}

# Function to create TGZ backup with checksum verification
tgz_backup() {
    local project=$1
    local working_dir=$2
    
    # Load config to check if TGZ creation is enabled
    local config_file="$ROOT_DIR/.backup-system/config/backup-settings.conf"
    local enable_tgz="true"
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        enable_tgz="${ENABLE_TGZ_CREATION:-true}"
    fi
    
    # Skip TGZ creation if disabled
    if [ "$enable_tgz" != "true" ]; then
        echo -e "${YELLOW}⚠️  TGZ creation disabled in config - skipping archive${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}📦 TGZ Backup: $project${NC}"
    
    if [ ! -d "$working_dir" ]; then
        echo -e "${RED}❌ Working directory not found: $working_dir${NC}"
        return 1
    fi
    
    # Create backups directory
    # For projects using the _www structure (polish_www, tickpulse_www, etc)
    if [[ "$working_dir" == *"_www/"* ]]; then
        # Extract the parent _www directory
        local www_parent=$(echo "$working_dir" | sed 's|\(/[^/]*_www\)/.*|\1|')
        local backup_dir="$www_parent/backups"
    else
        local backup_dir="$ROOT_DIR/.claude/atlas/atlas-$project/backups"
    fi
    mkdir -p "$backup_dir"
    
    # Calculate current checksum of the working directory
    cd "$working_dir" || return 1
    local current_checksum=$(find . -type f ! -path "./.git/*" ! -path "./node_modules/*" -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
    
    # Check if previous checksum exists
    local checksum_file="$backup_dir/.last_backup_checksum"
    local last_checksum=""
    
    if [ -f "$checksum_file" ]; then
        last_checksum=$(cat "$checksum_file")
    fi
    
    # Compare checksums
    if [ "$current_checksum" = "$last_checksum" ]; then
        echo -e "${GREEN}✅ No changes detected (checksum: ${current_checksum:0:8}...) - skipping TGZ backup${NC}"
        return 0
    fi
    
    # Create TGZ backup (files have changed)
    local backup_file="$backup_dir/${project}_backup_${TIMESTAMP}.tgz"
    cd "$(dirname "$working_dir")" || return 1
    tar --exclude="node_modules" --exclude=".git" -czf "$backup_file" "$(basename "$working_dir")"
    
    # Save new checksum
    echo "$current_checksum" > "$checksum_file"
    
    echo -e "${GREEN}✅ TGZ backup created: $backup_file${NC}"
    echo -e "${GREEN}✅ Checksum updated: ${current_checksum:0:8}...${NC}"
}

# Function to backup session documentation
session_backup() {
    local project=$1
    
    # Load config to check session backup settings
    local config_file="$ROOT_DIR/.backup-system/config/backup-settings.conf"
    local enable_session="true"
    local enable_atlas="true"
    local atlas_root=""
    local session_location=""
    
    if [ -f "$config_file" ]; then
        source "$config_file"
        enable_session="${ENABLE_SESSION_BACKUP:-true}"
        enable_atlas="${ENABLE_ATLAS_INTEGRATION:-true}"
        atlas_root="${ATLAS_ROOT_DIR:-$ROOT_DIR/.claude/atlas}"
        session_location="${SESSION_BACKUP_LOCATION:-auto}"
    fi
    
    # Skip session backup if disabled
    if [ "$enable_session" != "true" ]; then
        echo -e "${YELLOW}⚠️  Session backup disabled in config - skipping${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}📄 Session Context Auto-Capture: $project${NC}"
    
    # Determine backup location
    local backup_dir=""
    if [ "$session_location" = "auto" ]; then
        if [ "$enable_atlas" = "true" ] && [ -d "$atlas_root" ]; then
            backup_dir="$atlas_root/atlas-$project"
            echo -e "${BLUE}💡 Using Atlas integration: $backup_dir${NC}"
        else
            # Fallback to project directory
            local working_dir=$(get_working_dir "$project")
            backup_dir="$working_dir/.sessions"
            mkdir -p "$backup_dir"
            echo -e "${BLUE}💡 Using standalone mode: $backup_dir${NC}"
        fi
    else
        backup_dir="$session_location/$project"
        mkdir -p "$backup_dir"
        echo -e "${BLUE}💡 Using custom location: $backup_dir${NC}"
    fi
    
    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}❌ Session backup directory not found: $backup_dir${NC}"
        return 1
    fi
    
    # Update SESSION_CURRENT.md with timestamp
    local session_current="$backup_dir/SESSION_CURRENT.md"
    
    # Add session marker
    echo -e "\n\n---\n## Session Checkpoint - $TIMESTAMP" >> "$session_current"
    echo "**Date**: $(date)" >> "$session_current"
    
    # Get working directory info
    local working_dir=$(get_working_dir "$project")
    echo "**Working Directory**: $working_dir" >> "$session_current"
    
    # Capture git status
    if [ -d "$working_dir/.git" ] || [ -d "$working_dir/../.git" ]; then
        echo -e "\n### Git Status" >> "$session_current"
        cd "$working_dir" || cd "$working_dir/.."
        echo '```' >> "$session_current"
        git status --short >> "$session_current"
        echo '```' >> "$session_current"
        
        # Recent commits
        echo -e "\n### Recent Commits" >> "$session_current"
        echo '```' >> "$session_current"
        git log --oneline -10 >> "$session_current"
        echo '```' >> "$session_current"
    fi
    
    # Capture current issues from CLAUDE.md
    if [ -f "$working_dir/CLAUDE.md" ]; then
        echo -e "\n### Active Issues from CLAUDE.md" >> "$session_current"
        # Extract current issues section
        awk '/### Current Issues/,/^###[^#]/ {if (!/^###[^#]/) print}' "$working_dir/CLAUDE.md" >> "$session_current"
    fi
    
    # Update CURRENT_STATE.md with latest info
    cat > "$backup_dir/CURRENT_STATE.md" << EOF
# $project Project - Current State

## Working Directory
\`\`\`
$working_dir
\`\`\`

## Last Session Update
- **Date**: $(date)
- **Timestamp**: $TIMESTAMP

## Git Information
$(cd "$working_dir" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "Not a git repository")

## Recent Activity
$(cd "$working_dir" 2>/dev/null && git log --oneline -5 2>/dev/null || echo "No git history")

## Modified Files
$(cd "$working_dir" 2>/dev/null && git status --porcelain 2>/dev/null || echo "No git status available")

## Session Notes
[Auto-captured at $(date)]
EOF
    
    # Archive old session if it's getting too large
    if [ -f "$session_current" ] && [ $(wc -l < "$session_current") -gt 1000 ]; then
        mv "$session_current" "$atlas_dir/SESSION_ARCHIVE_${TIMESTAMP}.md"
        echo "# Session Log - $project" > "$session_current"
        echo "Previous session archived to SESSION_ARCHIVE_${TIMESTAMP}.md" >> "$session_current"
    fi
    
    echo -e "${GREEN}✅ Session context automatically captured${NC}"
    echo -e "${GREEN}✅ Updated: SESSION_CURRENT.md and CURRENT_STATE.md${NC}"
}

# Function to backup single project
backup_project() {
    local project=$1
    local backup_type=$2
    
    echo -e "${BLUE}🚀 Backing up project: $project${NC}"
    echo ""
    
    # Get working directory
    local working_dir=$(get_working_dir "$project")
    
    if [ -z "$working_dir" ]; then
        echo -e "${RED}❌ Could not determine working directory for $project${NC}"
        echo "Check \$ROOT_DIR/.claude/atlas/atlas-$project/CURRENT_STATE.md or configure project paths"
        return 1
    fi
    
    echo "Working Directory: $working_dir"
    echo ""
    
    case $backup_type in
        "quick")
            git_backup "$project" "$working_dir" "Quick backup - $TIMESTAMP"
            ;;
        "session")
            session_backup "$project"
            ;;
        "full")
            git_backup "$project" "$working_dir" "Full backup - $TIMESTAMP"
            tgz_backup "$project" "$working_dir"
            session_backup "$project"
            ;;
        *)
            echo -e "${RED}❌ Unknown backup type: $backup_type${NC}"
            echo "Available types: quick, session, full"
            return 1
            ;;
    esac
    
    echo ""
}

# Function to list available projects
list_projects() {
    echo -e "${BLUE}📋 Available Projects:${NC}"
    ls -1 "$ROOT_DIR/.claude/atlas/" | grep "atlas-" | sed 's/atlas-/  - /'
    echo ""
}

# Setup function for interactive configuration
setup_config() {
    echo -e "${BLUE}=== Universal Backup System Setup ===${NC}"
    echo "This will create your backup-settings.conf file."
    echo ""
    
    local config_file="$ROOT_DIR/.backup-system/config/backup-settings.conf"
    
    # Create config directory if needed
    mkdir -p "$(dirname "$config_file")"
    
    # Interactive prompts
    read -p "GitHub username: " github_user
    read -p "SSH key name (without path): " ssh_key
    read -p "Default repository visibility (private/public) [private]: " repo_vis
    repo_vis=${repo_vis:-private}
    
    echo ""
    echo "Backup Components:"
    read -p "Enable GitHub upload? (y/n) [y]: " github_upload
    github_upload=${github_upload:-y}
    read -p "Enable TGZ archives? (y/n) [y]: " tgz_creation
    tgz_creation=${tgz_creation:-y}
    read -p "Enable session backup? (y/n) [y]: " session_backup
    session_backup=${session_backup:-y}
    
    echo ""
    echo "Atlas Integration:"
    if [ -d "$ROOT_DIR/.claude/atlas" ]; then
        echo "Claude Code/Atlas detected!"
        read -p "Enable Atlas integration? (y/n) [y]: " atlas_integration
        atlas_integration=${atlas_integration:-y}
    else
        echo "Claude Code/Atlas not detected - using standalone mode"
        atlas_integration="n"
    fi
    
    # Convert y/n to true/false
    [ "$github_upload" = "y" ] && github_upload="true" || github_upload="false"
    [ "$tgz_creation" = "y" ] && tgz_creation="true" || tgz_creation="false"
    [ "$session_backup" = "y" ] && session_backup="true" || session_backup="false"
    [ "$atlas_integration" = "y" ] && atlas_integration="true" || atlas_integration="false"
    
    # Create configuration file
    cat > "$config_file" << EOF
# Backup System Configuration
# =================================

# GitHub Settings
GITHUB_USERNAME="$github_user"
SSH_KEY_NAME="$ssh_key"
REPO_VISIBILITY="$repo_vis"

# Backup Components (true/false)
ENABLE_GITHUB_UPLOAD="$github_upload"
ENABLE_TGZ_CREATION="$tgz_creation"
ENABLE_SESSION_BACKUP="$session_backup"

# Claude Code / Atlas Integration (true/false)
ENABLE_ATLAS_INTEGRATION="$atlas_integration"
ATLAS_ROOT_DIR="\$ROOT_DIR/.claude/atlas"

# Backup Storage Locations
TGZ_BACKUP_LOCATION="auto"
SESSION_BACKUP_LOCATION="auto"

# GitHub CLI Location (auto-detect or specify)
GITHUB_CLI_PATH="auto"

# Project Detection
PROJECT_CONFIG_DIR="\$ROOT_DIR/.backup-system/config"

# Advanced Settings
BACKUP_RETENTION_DAYS="30"
CHECKSUM_ALGORITHM="md5"
DEFAULT_SEARCH_ORDER="WORDPRESS_THEME_LARAGON,GIT_PROJECT"
EOF
    
    echo -e "${GREEN}✅ Configuration created: $config_file${NC}"
    echo -e "${BLUE}💡 You can edit this file anytime to change settings${NC}"
    echo ""
    echo "Test your setup with:"
    echo "  $0 your-project-name quick"
}

# Main script logic
case $PROJECT in
    "--setup")
        setup_config
        exit 0
        ;;
    "list")
        list_projects
        ;;
    "all")
        echo -e "${BLUE}🌍 Backing up ALL projects${NC}"
        echo ""
        for atlas_dir in "$ROOT_DIR/.claude/atlas"/atlas-*; do
            if [ -d "$atlas_dir" ]; then
                project_name=$(basename "$atlas_dir" | sed 's/atlas-//')
                backup_project "$project_name" "$BACKUP_TYPE"
            fi
        done
        ;;
    "")
        echo "Usage: $0 [project-name|all|list] [quick|session|full]"
        echo ""
        echo "Examples:"
        echo "  $0 polish full          # Full backup of Polish project"
        echo "  $0 tickpulse quick      # Quick git backup of TickPulse"
        echo "  $0 all session          # Session backup of all projects"
        echo "  $0 list                 # List available projects"
        echo ""
        echo "Backup Types:"
        echo "  quick   - Git commit and push only"
        echo "  session - Backup session documentation only"
        echo "  full    - Git + TGZ + Session backup (default)"
        echo ""
        list_projects
        ;;
    *)
        backup_project "$PROJECT" "$BACKUP_TYPE"
        ;;
esac

echo -e "${GREEN}🎉 Backup operation completed!${NC}"