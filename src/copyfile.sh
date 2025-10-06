#!/usr/bin/env bash
# copyfile: copie le contenu d'un fichier dans le presse-papiers.
# Usage: copyfile <chemin_du_fichier>
#        cat fichier | copyfile   # (stdin supporté)

set -euo pipefail

die() { echo "Erreur: $*" >&2; exit 1; }

# Lire depuis un fichier ou depuis stdin
if [[ $# -gt 0 ]]; then
  FILE="$1"
  [[ -f "$FILE" ]] || die "Fichier introuvable: $FILE"
  INPUT_CMD=(cat -- "$FILE")
else
  # pas d'argument → lire depuis stdin
  # vérifier qu'il y a bien quelque chose sur stdin
  if [ -t 0 ]; then
    die "Aucun fichier fourni et stdin est vide. Utilisation: copyfile <fichier>"
  fi
  INPUT_CMD=(cat)
fi

copy_with() {
  # $1 = commande, $2... = args
  if command -v "$1" >/dev/null 2>&1; then
    "${INPUT_CMD[@]}" | "$1" "${@:2}"
    echo "✔ Copié dans le presse-papiers via $1"
    exit 0
  fi
}

# Ordre de préférence selon l'OS/environnement
# Linux Wayland
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  copy_with wl-copy
fi

# Linux X11
copy_with xclip -selection clipboard
copy_with xsel --clipboard --input

# macOS
copy_with pbcopy

# WSL/Windows (depuis WSL)
copy_with clip.exe

die "Aucun utilitaire de presse-papiers trouvé.
Installez l'un de ces paquets:
  - Wayland:  wl-clipboard  (commande: wl-copy)
  - X11:      xclip         (commande: xclip)
             ou xsel         (commande: xsel)
  - macOS:    pbcopy est déjà présent
  - WSL:      clip.exe est fourni par Windows"

