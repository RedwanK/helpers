#!/bin/bash

# Vérification du nombre minimum d'arguments
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 [--remove] <file_or_dir1> [file_or_dir2 ...]"
  exit 1
fi

# Détection du mode (--remove ou ajout par défaut)
MODE="add"
if [ "$1" == "--remove" ]; then
  MODE="remove"
  shift
fi

GITIGNORE_PATH="./.gitignore"

# Exécution selon le mode
if [ "$MODE" == "add" ]; then
  for ITEM in "$@"; do
    if grep -Fxq "$ITEM" "$GITIGNORE_PATH"; then
      echo "✔️  '$ITEM' déjà présent dans $GITIGNORE_PATH"
    else
      echo "$ITEM" >> "$GITIGNORE_PATH"
      echo "➕  '$ITEM' ajouté dans $GITIGNORE_PATH"
    fi
  done
  echo "✅ Ajout terminé."
else
  for ITEM in "$@"; do
    if grep -Fxq "$ITEM" "$GITIGNORE_PATH"; then
      # Supprime la ligne exacte correspondante
      sed -i.bak "/^${ITEM//\//\\/}\$/d" "$GITIGNORE_PATH"
      echo "🗑️  '$ITEM' supprimé de $GITIGNORE_PATH"
    else
      echo "⚠️  '$ITEM' n'était pas présent dans $GITIGNORE_PATH"
    fi
  done
  echo "✅ Suppression terminée."
fi
