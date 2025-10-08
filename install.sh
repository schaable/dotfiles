#!/bin/sh

set -e
set -x

# Copy dotfiles
cp ~/dotfiles/.zshrc ~/.zshrc
cp ~/dotfiles/.p10k.zsh ~/.p10k.zsh

echo "Dotfiles installed!"