# CONSIGNES DE TRAVAIL — Répartition du code entre deux modèles

## Contexte (lis ceci avant de commencer)

Le document `Spec projet deambulation nocturne.md` joint à ce message est la **source de vérité unique** du projet. Tu ne dois rien y ajouter, rien y retirer, ni réinterpréter une exigence — si un point te semble flou, signale-le explicitement plutôt que de combler le vide par une hypothèse personnelle.

**Important pour la suite : tu ne travailleras pas seul sur ce projet jusqu'au bout.** Une fois ton travail terminé, un second modèle, moins puissant que toi (Gemini 3.5 Flash ou Gemini 3.1 Pro, exécuté localement sur la machine Windows de l'utilisateur), prendra le relais pour :
- lancer les commandes de build/import/export en pratique sur la machine cible,
- intégrer les assets 3D générés par les API IA (Meshy/Tripo/Rodin),
- peupler et ajuster le décor (placement des éléments, réglages fins de l'éclairage/brouillard),
- itérer visuellement jusqu'à obtenir le rendu voulu.

**Conséquence directe pour toi :** ton code doit être immédiatement compréhensible et exploitable par un modèle moins capable que toi, sans qu'il ait besoin de "deviner" ton intention. Pas de raccourcis implicites, pas d'astuces non commentées, pas de dépendance cachée entre deux fichiers sans que ce soit dit explicitement.

---

## Répartition du travail

### Ce que TU dois produire maintenant (parties à plus fort risque d'erreur)

Ce sont les parties où une erreur de logique casse tout le reste du projet, ou compromet directement la direction artistique — donc celles qui bénéficient le plus d'un modèle puissant :

1. **Le squelette complet du projet Godot** : `project.godot` (renderer Forward+, paramètres de fenêtre plein écran/bordless), arborescence de dossiers conforme à la section 10 du spec.
2. **La configuration `InputMap`** basée sur `physical_keycode` (section 7 du spec) — c'est un point précis et facile à mal configurer ; vérifie-la deux fois.
3. **Le setup `WorldEnvironment` + `DirectionalLight3D`** : brouillard volumétrique, glow, tonemap, lune dominante, éclairage froid — c'est le cœur de toute l'ambiance Fatal Frame / Vampire Hunter D décrite en section 2 du spec. Une mauvaise valeur ici et l'ambiance entière rate sa cible.
4. **Le contrôleur de personnage (`CharacterBody3D`) et le rig de caméra 3e personne** (section 5.3) — code standard mais à livrer propre et fonctionnel dès le premier essai, puisque tout le reste s'appuie dessus.
5. **Les scripts CLI du pipeline headless** (section 4 du spec) : commandes d'import/export exactes, avec les bons chemins, prêtes à être copiées-collées par le modèle suivant sans qu'il ait à les corriger.
6. **Le squelette du `README.md`** (section 13) : structure complète, avec les commandes exactes déjà renseignées — le modèle suivant n'aura qu'à documenter ses propres ajouts dedans, pas à l'écrire de zéro.

### Ce que tu NE dois PAS faire maintenant (laissé au modèle suivant)

- Les appels effectifs aux API de génération 3D (Meshy/Tripo/Rodin) et le téléchargement des assets — tu peux en revanche écrire le script d'appel API en lui-même (ça reste du code), mais ne simule pas un résultat ni n'invente un asset.
- Le placement fin des éléments de décor dans la scène (composition visuelle de la zone).
- Tout réglage visuel qui nécessite de voir le rendu réel à l'écran (impossible pour toi, possible seulement en mode fenêtré sur la machine de l'utilisateur).

---

## Règles de qualité pour faciliter la passation

- Commente chaque fichier en tête avec : son rôle, ses dépendances vers d'autres fichiers, et ce qui reste à compléter par le modèle suivant (s'il y a quelque chose).
- Utilise des marqueurs explicites dans le code pour les zones à compléter, par exemple :
  ```gdscript
  # TODO[modèle suivant] : appeler l'API Meshy ici et stocker le .glb dans /assets/models/
  ```
- Ne laisse aucune fonction à moitié écrite sans le signaler en commentaire — un code incomplet non signalé sera pris pour un bug par le modèle suivant, pas pour une tâche en attente.
- Respecte strictement les noms de fichiers et l'arborescence donnés dans le spec (section 10), pour que la passation n'introduise pas de confusion de chemins.

---

## Livrable attendu de toi pour ce tour

1. Les 6 éléments listés dans "Ce que tu dois produire maintenant", chacun en bloc de code séparé et complet.
2. Une **note de passation** à la fin, rédigée pour le modèle suivant (pas pour l'utilisateur), qui décrit étape par étape, sans ambiguïté, ce qu'il doit faire en premier en reprenant le projet, dans quel ordre, et quels fichiers il a le droit de modifier librement vs lesquels il doit éviter de toucher sans bonne raison.
