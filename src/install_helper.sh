#!/usr/bin/env bash
# install_helper: installe un script helper en créant un lien symbolique dans le dossier bin de l'utilisateur.
# Usage: install_helper <chemin_du_helper> <nom_de_commande>

set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: install_helper <chemin_du_helper> <nom_de_commande>
USAGE
  exit 1
}

die() { printf 'Erreur: %s\n' "$*" >&2; exit 1; }

resolve_abs_path() {
  local target="$1"
  if [[ "$target" == /* ]]; then
    printf '%s\n' "$target"
    return
  fi

  local dir part
  dir="${target%/*}"
  part="${target##*/}"

  if [[ "$dir" == "$target" ]]; then
    dir='.'
  fi

  (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$part") || die "Impossible de résoudre le chemin absolu de $target"
}

bin_dir_for_os() {
  if [[ -n "${INSTALL_HELPER_BIN_DIR:-}" ]]; then
    printf '%s\n' "$INSTALL_HELPER_BIN_DIR"
    return
  fi

  case "$(uname -s)" in
    Linux|Linux-*)
      printf '%s\n' "$HOME/.local/bin"
      ;;
    Darwin)
      printf '%s\n' "$HOME/bin"
      ;;
    *)
      printf '%s\n' "$HOME/bin"
      ;;
  esac
}

[[ $# -eq 2 ]] || usage

HELPER_PATH="$1"
COMMAND_NAME="$2"

[[ -n "$COMMAND_NAME" ]] || die "Le nom de la commande ne peut pas être vide"

HELPER_ABS="$(resolve_abs_path "$HELPER_PATH")"
[[ -e "$HELPER_ABS" ]] || die "Fichier introuvable: $HELPER_PATH"
if [[ ! -x "$HELPER_ABS" ]]; then
  chmod +x "$HELPER_ABS" || die "Impossible de rendre $HELPER_ABS exécutable"
  echo "🔧  Droits d'exécution appliqués sur $HELPER_ABS"
fi

BIN_DIR="$(bin_dir_for_os)"
[[ -n "$BIN_DIR" ]] || die "Impossible de déterminer le dossier bin cible"
mkdir -p "$BIN_DIR"

TARGET_LINK="$BIN_DIR/$COMMAND_NAME"

if [[ -e "$TARGET_LINK" || -L "$TARGET_LINK" ]]; then
  if [[ -L "$TARGET_LINK" ]]; then
    LINK_TARGET="$(readlink "$TARGET_LINK")"
    if [[ "$LINK_TARGET" == "$HELPER_ABS" ]]; then
      echo "✔️  Le lien $TARGET_LINK pointe déjà vers $HELPER_ABS"
      exit 0
    fi
  fi
  die "Le fichier $TARGET_LINK existe déjà. Supprimez-le ou choisissez un autre nom."
fi

ln -s "$HELPER_ABS" "$TARGET_LINK"

echo "✅ Lien créé: $TARGET_LINK -> $HELPER_ABS"

echo "📎 Dossier d'installation: $BIN_DIR"

if ! echo ":$PATH:" | grep -q ":$BIN_DIR:"; then
  echo "⚠️  $BIN_DIR n'est pas dans votre PATH. Ajoutez-le pour utiliser '$COMMAND_NAME' partout." >&2
fi
