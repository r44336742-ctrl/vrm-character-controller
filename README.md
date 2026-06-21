# Moonlit Void - Projet de Déambulation Nocturne

## Stack Technique
- **Moteur :** Godot Engine 4.6.x (ou 4.x compatible)
- **Langage :** GDScript
- **Renderer :** Forward+ (Direct3D 12 / Vulkan)
- **Pipeline :** 100% Headless via CLI (aucune interface graphique d'édition)

## Commandes CLI (Pipeline Headless)
Toutes les commandes doivent être exécutées à la racine du projet depuis l'invite de commande Windows. Vous pouvez utiliser le fichier `pipeline_headless.bat` ou les lancer manuellement :

1. **Importer les assets (génère les .import) :**
   `godot4 --headless --path . --import`
2. **Valider la scène principale (vérifie les erreurs de script) :**
   `godot4 --headless --path . res://scenes/main.tscn --quit-after 5`
3. **Exporter le jeu (.exe Windows) :**
   `godot4 --headless --path . --export-release "Windows Desktop" build/jeu.exe`

## Lancer le jeu
Exécutez `build/jeu.exe` sur Windows 11.
- Le jeu se lance en plein écran sans menu.
- Contrôles : ZQSD/WASD ou Flèches directionnelles.
- Échap pour quitter.

## TODO - À compléter
- [x] Documenter l'intégration des assets API 3D (Meshy/Tripo) : Les assets ont été générés en placeholder via Godot faute de clé API. Utilisez le script `tripo_meshy_api.py` pour télécharger vos propres modèles et écrasez `assets/models/character.glb` et `assets/models/ruins.glb`.
- [x] Documenter les ajustements visuels de l'éclairage/brouillard si modifiés.
- [ ] Valider l'optimisation 60 FPS avec les vrais modèles.
