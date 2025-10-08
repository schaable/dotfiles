#!/usr/bin/env bash

# exit on error (-e), 
# error on unset vars (-u), 
# fail if any command in a pipeline fails (pipefail),
# and trace commands as they run (-x)
set -euo pipefail -x

clone_or_update() {
  local repo="$1" dest="$2"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" pull --ff-only --quiet || true
  else
    git clone --depth=1 "$repo" "$dest" >/dev/null 2>&1 || true
  fi
}

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Install Powerlevel10k theme
clone_or_update https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

# Install zsh plugins
clone_or_update https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
clone_or_update https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions

# Copy dotfiles
cp ~/dotfiles/.p10k.zsh ~/.p10k.zsh
cp ~/dotfiles/.zshrc ~/.zshrc

echo "Dotfiles installed!"