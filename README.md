# Helpers

Repo perso pour gérer mes utilitaires.

Pour installer un utilitaire, utiliser `src/install_helper.sh` avec deux arguments :
- chemin vers le script/helper à installer (ex. `src/copyfile.sh`)
- nom voulu pour la commande (ex. `copyfile`)

Exemple :

```bash
src/install_helper.sh src/copyfile.sh copyfile
```

Le script crée un lien symbolique dans le dossier `bin` de l'utilisateur (détecté automatiquement) afin que la commande soit accessible partout.
