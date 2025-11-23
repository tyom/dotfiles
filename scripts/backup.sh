#!/bin/bash

source scripts/vars
source shell/utils

# Backup frequency as date format
BACKUP_DIR="$HOME/dotfiles_old/$(date +%Y-%m-%d--%H-%M)/"
SUMMARY_FILE="$BACKUP_DIR/see-hidden-files"

# Populate list of existing clashing dotfiles
EXISTING_DOTFILES=()
for f in ${PAYLOAD_FILES[@]}; do
  [ -f "$HOME/.$f" ] && EXISTING_DOTFILES+=("$f")
done

if [ ${#EXISTING_DOTFILES[@]} -eq 0 ]; then
  print_info "Skipping backup, no existing files will be changed"

else
  print_step "Backing up old dotfiles in '$BACKUP_DIR' "

  mkdir -p "$BACKUP_DIR"

  # Create new file
  >$SUMMARY_FILE

  # Copy existing files to backup directory
  # and create summary of files copied
  for file in "${EXISTING_DOTFILES[@]}"; do
    filename=$(basename "$file")
    home_file="$HOME/.$filename"
    if [ -e "$home_file" ]; then
      cp -L "$HOME/.$filename" "$BACKUP_DIR/.$filename"
      echo ".$filename" >>$SUMMARY_FILE
      echo " - .$filename"
    fi
  done
fi
