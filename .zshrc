# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git zsh-autosuggestions fasd)

# Add zsh-completions to fpath
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

source $ZSH/oh-my-zsh.sh

# Load p10k config
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Persist zsh history
export HISTFILE=/workspaces/.zsh_history

# Load fasd
eval "$(fasd --init auto)"

# Start ssh-agent
eval $(ssh-agent) > /dev/null

# Utility to create temp pnpm projects
newpnpm() {
  local dir_suffix=$(ls -1d /tmp/pnpmproject* 2>/dev/null | wc -l | sed 's/ //g')
  if [ ! -z "${1}" ]; then
    dir_suffix="${dir_suffix}-${1}"
  fi
  mkdir -p "/tmp/pnpmproject-${dir_suffix}"
  cd "/tmp/pnpmproject-${dir_suffix}"
  pnpm init
}

alias newhh='newpnpm && pnpm add hardhat && pnpm hardhat --init'
alias lastpnpm='cd "/tmp/pnpmproject-$(ls -1d /tmp/* | grep pnpmproject | tail -n +2 | wc -l | sed '\''s/ //g'\'')"'

# pnpm setup
export PNPM_HOME="/root/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Prevent corepack from auto pinning versions
export COREPACK_ENABLE_AUTO_PIN=0

# Location to store last fetched PR metadata
export PR_META_FILE="/tmp/.last_pr_meta"

# Fetch PR branch locally
gprl() {
  if [ -z "$1" ]; then
    echo "Usage: gprl <PR_NUMBER>"
    return 1
  fi

  local pr="$1"
  local repo="NomicFoundation/hardhat"

  local json
  json="$(curl -fsSL \
    -H 'Accept: application/vnd.github.v3+json' \
    "https://api.github.com/repos/${repo}/pulls/${pr}")" || return 1

  if ! printf '%s' "$json" | jq -e . >/dev/null 2>&1; then
    echo "Error: GitHub API returned non-JSON (rate limited or network issue?)."
    printf '%s\n' "$json" | head -n 20
    return 1
  fi

  local head_repo head_ref
  head_repo="$(printf '%s' "$json" | jq -r '.head.repo.full_name // empty')"
  head_ref="$(printf '%s' "$json" | jq -r '.head.ref')"

  printf '%s %s\n' "$head_repo" "$head_ref" > "$PR_META_FILE"

  local branch="pr-${pr}-${head_ref}"
  git fetch origin "pull/${pr}/head:${branch}" &&
  git switch "$branch"
}

# Push to PR branch
gprp() {
  if [ ! -f "$PR_META_FILE" ]; then
    echo "No PR metadata found. Run gprl first."
    return 1
  fi

  read head_repo head_ref < "$PR_META_FILE"
  git push "git@github.com:${head_repo}.git" "HEAD:${head_ref}"
}

# Start ephemeral Verdaccio server
lverdaccio() {
  TMPDIR=$(mktemp -d)
  CONFIG="$TMPDIR/config.yaml"
  PORT=4873
  URL="http://127.0.0.1:$PORT"

  cat > "$CONFIG" <<EOF
storage: $TMPDIR/storage
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
packages:
  '**':
    access: \$all
    publish: \$all
    proxy: npmjs
listen: $URL
EOF

  echo "$URL" > ~/.local-verdaccio
  echo "//127.0.0.1:4873/:_authToken=dev" >> ~/.npmrc

  cleanup() {
    echo "Shutting down Verdaccio..."
    rm -f ~/.local-verdaccio
    sed -i '/127\.0\.0\.1:4873/d' ~/.npmrc
    rm -rf "$TMPDIR"
    echo "Cleaned up."
  }
  trap cleanup EXIT

  VERDACCIO_PUBLIC_URL="$URL" verdaccio --config "$CONFIG"
}

lpublish() {
  if ! npm whoami --registry http://127.0.0.1:4873 &>/dev/null; then
    echo "Logging in..."
    expect -c "
      spawn npm adduser --registry http://127.0.0.1:4873
      expect \"Username:\"
      send \"dev\r\"
      expect \"Password:\"
      send \"dev\r\"
      expect \"Email:\"
      send \"dev@test.com\r\"
      expect eof
    "
  fi
  npm_config_registry=http://127.0.0.1:4873 pnpm changeset publish "$@"
}

# Wrap package managers to use local Verdaccio if running
npm() {
  if [ -f ~/.local-verdaccio ]; then
    NPM_CONFIG_REGISTRY=$(<~/.local-verdaccio) command npm "$@"
  else
    command npm "$@"
  fi
}

npx() {
  if [ -f ~/.local-verdaccio ]; then
    NPM_CONFIG_REGISTRY=$(<~/.local-verdaccio) command npx "$@"
  else
    command npx "$@"
  fi
}

pnpm() {
  if [ -f ~/.local-verdaccio ]; then
    NPM_CONFIG_REGISTRY=$(<~/.local-verdaccio) command pnpm "$@"
  else
    command pnpm "$@"
  fi
}