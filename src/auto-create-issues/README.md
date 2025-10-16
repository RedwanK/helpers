# 🗒️ Markdown → GitHub Issues (Todo Sync)

Ce helper est un système automatique pour **transformer les cases à cocher (`- [ ]`) présentes dans les fichiers Markdown en Issues GitHub**.  
Chaque tâche non cochée devient une *Issue* avec ses labels, sa date d’échéance et un lien direct vers la ligne source.  
Quand tu coches la case (`- [x]`), l’Issue se ferme automatiquement.

---

## 🚀 Installation

1. **Copie les fichiers suivants** dans ton dépôt :


.github/
├── workflows/
│   └── markdown-todos.yml
└── scripts/
    └── markdown_todos_to_issues.py

2. **Valide les permissions par défaut** :  
- `issues: write` (nécessaire pour créer/fermer des Issues)
- `contents: read` (lecture des fichiers Markdown)

3. **Commit & Push** sur la branche `main` :
```bash
git add .github
git commit -m "✨ Ajout du système de todo automatique"
git push origin main
```

4. C’est tout !
   À chaque **push** contenant des fichiers `.md`, le workflow :

   * scanne tes fichiers Markdown ;
   * crée ou met à jour les Issues correspondantes ;
   * ferme les Issues si la tâche est cochée ou supprimée.

---

## 🧩 Syntaxe des tâches

Dans n’importe quel fichier Markdown (`.md`), écris simplement :

```markdown
## Exemple de réunion

- [ ] Envoyer le compte rendu (due: 2025-10-20) #followup !p1
- [ ] Mettre à jour la présentation #marketing
- [x] Appeler le client pour confirmation
```

### 🧠 Règles de parsing

| Élément             | Description                                    | Exemple                  |
| ------------------- | ---------------------------------------------- | ------------------------ |
| `- [ ]`             | Tâche à faire                                  | `- [ ] Préparer la démo` |
| `- [x]`             | Tâche terminée (ferme l’Issue)                 | `- [x] Envoyer mail`     |
| `due: YYYY-MM-DD`   | Date limite                                    | `due: 2025-10-18`        |
| `#label`            | Label GitHub à associer                        | `#maintenance`           |
| `!p1`, `!p2`, `!p3` | Priorité (ajoute un label `priority/p1`, etc.) | `!p2`                    |

Chaque tâche est liée à son **fichier source et numéro de ligne** dans le corps de l’Issue.

---

## 🏗️ Fonctionnement interne

1. Le workflow `markdown-todos.yml` se déclenche sur :

   * chaque **push** de fichiers `.md` sur `main` (ou `master`) ;
   * manuellement via l’onglet **Actions → Run workflow**.

2. Le script Python :

   * lit tous les `.md` du dépôt (sauf `.git`, `.github`, `vendor`, etc.) ;
   * détecte les lignes contenant des cases à cocher ;
   * crée ou met à jour les Issues correspondantes via l’API GitHub ;
   * ferme les Issues supprimées ou cochées ;
   * garde un cache local (`.github/todos-cache.json`) pour éviter les doublons.

3. Chaque Issue créée contient :

   * le **titre** de la tâche (nettoyé) ;
   * un **lien vers la ligne source** dans GitHub ;
   * les **labels** et la **date d’échéance** si présents ;
   * le tag `from-markdown` (pour les filtrer facilement).

---

## 💡 Bonnes pratiques

* Organise tes notes dans un dossier dédié :

  ```
  notes/
  ├── 2025-10-16_reunion_client_X.md
  ├── planning_sprint_43.md
  └── roadmap_projets.md
  ```

* Privilégie des tâches **atomiques** (une action claire par ligne).
  Exemple :

  ```markdown
  - [ ] Créer le plan de test pour le module IA ✅
  ```

  plutôt que

  ```markdown
  - [ ] Finaliser le module IA (design + plan de test + doc)
  ```

* Utilise des **sections claires** (`## Titre`) pour contextualiser les tâches.
  Ces titres apparaissent dans le corps de l’Issue.

* Pour le tri :

  * `#client/<nom>` → par client
  * `#area/<domaine>` → par thème (IIoT, maintenance, etc.)
  * `!p1` → urgent, `!p3` → faible priorité

* Ferme une tâche simplement en cochant la case (`- [x]`), puis en commitant.
  L’Issue sera fermée automatiquement au prochain push.

* Si tu veux ignorer certains fichiers (par exemple `README.md` ou `templates/`),
  tu peux modifier la liste `IGNORE_DIRS` dans le script Python.

---

## 📊 Intégration avec GitHub Projects

Tu peux toujours garder un fonctionnement simple :

* Crée un **Project** existant (Kanban ou Table).
* Ajoute une règle automatique :

  > “Add to project when label = from-markdown”
* Tu auras ainsi une vue centralisée de toutes tes tâches issues de Markdown.

### 🚀 Roadmap automatique (optionnel)

Le script sait désormais piloter GitHub Projects (nouvelle génération) via GraphQL :

* il crée un projet `Roadmap` s’il n’existe pas encore ;
* il ajoute l’Issue en tant qu’item du projet ;
* il renseigne `Start date` avec la date d’exécution et `Target date` à partir du `due:` présent dans le Markdown (la valeur est nettoyée si le `due` disparaît ou si la tâche est cochée).

Avant de modifier le workflow, prépare un token qui dispose des droits nécessaires :

1. Génère un PAT GitHub (fine-grained recommandé) avec les scopes `repo` et `project`.
2. Ajoute-le dans `Settings → Secrets and variables → Actions` du dépôt (ou de l’organisation) sous le nom `PROJECT_AUTOMATION_TOKEN`.

Pour activer cette fonctionnalité, ajoute les variables d’environnement suivantes dans ton workflow :

```yaml
      - name: Run sync script
        env:
          GITHUB_REPOSITORY: ${{ github.repository }}
          GITHUB_SHA: ${{ github.sha }}
          GITHUB_TOKEN: ${{ secrets.PROJECT_AUTOMATION_TOKEN }}  # PAT avec scopes repo + project
          GITHUB_PROJECT_SYNC: "true"
          GITHUB_PROJECT_TITLE: "Roadmap"           # Optionnel – nom du projet
          GITHUB_PROJECT_START_FIELD: "Start date"  # Optionnel – champ date de début
          GITHUB_PROJECT_END_FIELD: "Target date"   # Optionnel – champ date de fin
        run: |
          python .github/scripts/markdown_todos_to_issues.py
```

> ℹ️ Le token GitHub Actions par défaut ne peut pas créer un Project V2. Crée un PAT (ou utilise un GitHub App) avec les scopes `repo` et `project`, stocke-le dans `PROJECT_AUTOMATION_TOKEN`, et passe-le au script via `GITHUB_TOKEN` comme ci-dessus.

Tu peux désactiver la synchronisation projets à tout moment en omettant `GITHUB_PROJECT_SYNC` ou en le mettant à `false`.

---

## 🧹 Maintenance

* Le cache local est enregistré dans `.github/todos-cache.json`.
  Il garde la correspondance entre les lignes Markdown et les Issues GitHub.
* Tu peux le supprimer sans risque (il sera régénéré automatiquement).
* Pour forcer une resynchronisation complète :

  ```bash
  rm .github/todos-cache.json
  git add .github/todos-cache.json
  git commit -m "🔄 Reset todo cache"
  git push
  ```

---

## 🧰 Technologies utilisées

* **GitHub Actions** – exécution automatique à chaque push
* **Python 3** – lecture et parsing des fichiers Markdown
* **GitHub REST API v3** – création et mise à jour des Issues
* **GitHub GraphQL API v4** – gestion automatique du Project Roadmap
* **Labels dynamiques** – auto-création des labels détectés dans le texte

---
