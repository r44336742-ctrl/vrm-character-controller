# SPÉCIFICATION TECHNIQUE COMPLÈTE — Projet de déambulation nocturne
### Document de cadrage destiné à un agent IA de développement (Claude Code ou équivalent)

---

## 0. Rôle de l'agent et cadre de travail

Tu es un agent IA de développement logiciel autonome. Tu dois concevoir, écrire, assembler, tester et compiler ce projet **intégralement par le code et la ligne de commande**, sans jamais ouvrir manuellement une interface graphique de logiciel 3D (Blender, Maya, etc.) ni l'éditeur graphique d'un moteur de jeu (Unreal Engine, éditeur Unity, éditeur Godot en mode visuel). Toute action passe par : édition de fichiers texte/code, appels d'API, et commandes terminal en mode `--headless`.

L'environnement cible de développement et d'exécution est **Windows 11**, sur la configuration suivante (fournie par l'utilisateur) :
- CPU : AMD Ryzen 5 5600H (6 cœurs / 12 threads, 3.30 GHz base / 3.72 GHz observé)
- RAM : 27,9 Go
- GPU : double GPU portable — AMD Radeon (iGPU intégré au CPU) **et** NVIDIA GeForce (GPU dédié, architecture Optimus)
- Stockage : SSD NVMe

---

## 1. Nature du projet — ce que ce n'est PAS

Ce n'est **pas un jeu** au sens ludique. Il n'y a :
- aucun objectif, aucune mission, aucun score, aucune condition de victoire/défaite ;
- aucun ennemi, aucun fantôme, aucune entité hostile, aucun jump-scare scripté ;
- aucune mécanique de combat ni de "caméra-arme" (à ne pas confondre avec la référence Fatal Frame, voir section 2 — on ne reprend que la direction artistique, jamais le gameplay de chasse aux fantômes) ;
- aucun inventaire, aucun dialogue, aucun PNJ, aucune sauvegarde de progression ;
- **aucune interface utilisateur** : pas de menu principal, pas d'écran de chargement visible, pas de HUD, pas de curseur de souris visible, pas de pause accessible via un écran.

L'unique action possible pour l'utilisateur est de **se déplacer librement** dans un décor, à la troisième personne, pour observer l'ambiance.

---

## 2. Direction artistique (références impératives)

### 2.1 Fatal Frame / Project Zero — ce qu'on en retient
- Clair-obscur cinématographique très marqué, contrastes forts entre zones éclairées et ombres profondes.
- Architecture japonaise traditionnelle délabrée et abandonnée (couloirs en bois sombre, cloisons coulissantes, vieux temples/manoirs), matières usées, poussière, toiles d'araignées, papier déchiré.
- Grain photographique/filmique léger, désaturation globale (palette dominée par bleus profonds, gris, bruns terreux, avec de rares touches de rouge en accent).
- Brume basse au sol, lumière diffuse façon lanterne/lampe-torche.
- Sensation de lieu figé dans le temps, hanté mais vide — **on ne prend que l'atmosphère visuelle, jamais le gameplay de combat ni les fantômes**.

### 2.2 Vampire Hunter D: Bloodlust — ce qu'on en retient
- Royaume gothique nocturne sous une pleine lune surdimensionnée et dominante dans le ciel.
- Architecture européenne médiévale-fantastique en ruine, mêlée d'éléments organiques/végétaux envahissants.
- Brume volumétrique bleutée, contre-jour lunaire, silhouettes, échelle grandiose et mélancolique.
- Ciel nocturne profond, étoiles discrètes, aucune trace de lumière chaude/solaire.

### 2.3 Synthèse demandée pour le projet
Une zone unique, nocturne, sous pleine lune, mêlant ruine et abandon (inspiration architecturale libre entre les deux références, à la discrétion de l'agent tant que la cohérence visuelle est respectée), avec :
- éclairage dominant froid bleu-argenté (lune), aucune source de lumière chaude sauf accents ponctuels (ex. une lanterne isolée) ;
- brouillard volumétrique permanent, densité faible à moyenne ;
- palette désaturée, contraste fort, grain filmique léger en post-traitement ;
- aucune musique ni bruitage requis dans cette version (silence ambiant ou son minimal type vent — hors scope, à ne pas développer maintenant).

### 2.4 Personnage
- Féminin, **réaliste** (pas de style cartoon/stylisé), proportions humaines crédibles.
- Tenue cohérente avec l'ambiance : sombre, sobre, longue de préférence — à déterminer par l'agent en cohérence avec la DA, sans arme, sans équipement de combat.

### 2.5 Caméra
- Troisième personne façon GTA : recul fixe derrière le personnage, légère hauteur, orbite libre à la souris autour du personnage, pas de zoom dynamique, pas de changement de FOV. Le personnage s'oriente dans sa direction de déplacement ; la caméra suit en orbite derrière lui.

---

## 3. Choix technique retenu — moteur et langage

### 3.1 Recommandation principale : **Godot Engine 4.6.x (GDScript)**

Justification par rapport aux contraintes du projet (code-only, headless, capacités IA, hardware cible) :

| Critère | Pourquoi Godot 4.6 convient |
|---|---|
| Headless / sans GUI | Les scènes (`.tscn`), ressources (`.tres`) et scripts (`.gd`) sont des **fichiers texte purs**, entièrement lisibles et générables par une IA sans jamais ouvrir l'éditeur. Le moteur dispose d'un mode `--headless` complet (import, test, export) piloté uniquement en ligne de commande. |
| Rendu atmosphérique natif | Le renderer Forward+ intègre nativement le brouillard volumétrique, le glow HDR, le tonemap filmique, les `DirectionalLight3D` à ombres portées — tout ce qu'il faut pour l'ambiance Fatal Frame / Vampire Hunter D sans moteur lourd type UE5. |
| Compatibilité assets IA | Import natif et automatique des fichiers `.glb`/`.gltf`, format de sortie standard des générateurs 3D par IA (voir section 6). |
| Fiabilité de génération de code par IA | GDScript est un langage simple, à syntaxe légère, massivement documenté et représenté dans les corpus d'entraînement des modèles de langage — réduit le risque d'erreurs de compilation générées par l'agent, comparé à un langage à compilation stricte comme Rust. |
| Licence et coût | MIT, gratuit, aucune dépendance propriétaire. |
| Pilotage par agent IA | Il existe déjà un écosystème de serveurs MCP dédiés permettant à un agent IA de piloter un projet Godot (scènes, scripts, import, export) de façon entièrement automatisée si besoin, en plus du simple éditeur de fichiers + CLI. |
| Performance Windows | Sur Windows, Godot 4.6 utilise Direct3D 12 par défaut (Vulkan disponible en repli), adapté à une configuration avec GPU NVIDIA dédié. |

### 3.2 Alternatives envisagées (à garder en réserve, non retenues par défaut)

- **Bevy (Rust, ECS, moteur 100% code, basé sur wgpu)** : approche "code-only" encore plus radicale puisqu'il n'existe aucun fichier de scène ni éditeur du tout — uniquement du code Rust. Philosophiquement le plus proche de "tout fait en headless par une IA". Cependant : écosystème d'effets atmosphériques (brouillard volumétrique, post-processing cinématographique) moins mature et moins "clé en main" que Godot, compilation Rust plus lourde, et le langage Rust (gestion stricte de l'ownership) génère statistiquement plus d'erreurs lors d'une génération de code automatisée par IA que GDScript. À envisager seulement si Godot s'avère limitant.
- **Babylon.js ou Three.js (TypeScript/JavaScript) packagé en application Electron** : avantage d'un langage massivement représenté dans les modèles de langage (fiabilité de génération de code potentiellement très élevée) et d'un pipeline 100% code également. Inconvénient : surcouche Chromium/Electron qui consomme des ressources et complique l'atteinte de 60 fps stables sur cette configuration, comparé à un exécutable natif Godot.

**Décision** : Godot 4.6.x / GDScript reste le meilleur compromis risque/qualité/performance pour ce projet et cette configuration matérielle. Les alternatives ne doivent être considérées qu'en cas de blocage technique avéré.

### 3.3 Point de vigilance tranché : le personnage réaliste sans logiciel 3D
C'est le nœud technique du projet. Une génération **procédurale** (primitives géométriques + shaders codés à la main, sans pipeline d'asset externe) ne permet **pas** d'atteindre un rendu humain "réaliste" — visage, anatomie, vêtements crédibles restent hors de portée de cette technique, quel que soit le moteur de rendu choisi derrière. La seule réponse cohérente avec la contrainte "réaliste" + "aucun logiciel 3D ouvert manuellement" est le pipeline décrit en section 5.1 : génération par un service IA texte-vers-3D via **appel API** (donc toujours automatisé/headless), export `.glb`, import direct dans le moteur. Ce point n'est pas négociable sans renoncer soit au réalisme, soit à la contrainte "headless" — il ne faut pas chercher à contourner le problème par de la génération procédurale codée à la main, qui ne produira jamais qu'un résultat stylisé/abstrait, pas réaliste.

---

## 4. Pipeline de développement headless — règles strictes

1. Ne jamais ouvrir l'éditeur Godot en mode graphique/interactif.
2. Écrire et modifier directement les fichiers texte du projet : `project.godot`, `*.tscn`, `*.tres`, `*.gd`.
3. Utiliser les commandes CLI suivantes (exemples) :
   - `godot4 --headless --path <projet> --import` → force l'import des assets sans interface.
   - `godot4 --headless --path <projet> <scene.tscn> --quit-after 5` → valide l'absence d'erreurs de script/scène (le mode headless réel ne permet pas de juger le rendu visuel, seulement la validité technique).
   - `godot4 --headless --export-release "Windows Desktop" build/jeu.exe` → export final de l'exécutable.
4. La validation **visuelle** de l'ambiance (lumière, brouillard, lune, personnage) ne peut se faire qu'en lançant l'exécutable ou le projet en mode fenêtré classique sur la machine Windows de l'utilisateur — c'est la seule étape qui sort du cadre "headless", car il s'agit de l'exécution normale du jeu fini, pas d'un outil d'édition.
5. Si un pilotage de l'éditeur s'avère nécessaire pour une tâche précise, utiliser exclusivement un serveur MCP de contrôle Godot piloté par l'agent lui-même — jamais une interaction humaine manuelle à la souris/clavier dans l'éditeur.

---

## 5. Personnage jouable

### 5.1 Génération du modèle 3D
- Utiliser un service de génération IA texte-vers-3D via API (ex. Meshy, Tripo, Rodin/Hyper3D), avec un prompt textuel précis décrivant le personnage souhaité (réaliste, féminin, vêtement sombre et long, cohérent avec la direction artistique définie en section 2.4).
- Exporter en **GLB**, avec rig humanoïde si l'outil le permet (squelette idéalement compatible Mixamo pour faciliter la récupération d'animations standard).

### 5.2 Animations minimales requises
- Idle (immobile).
- Marche avant / arrière / latérale (strafe), avec transitions douces (blend via `AnimationTree`).
- Une vitesse secondaire de déplacement plus rapide (course légère) est une option laissée à l'agent, non obligatoire.
- Source d'animations : bibliothèque standard Mixamo (squelette humanoïde générique). Si un retargeting est nécessaire, il peut être scripté via Blender en mode `--background --python script.py` : ceci reste conforme à la contrainte "headless" puisqu'aucune fenêtre/interface graphique n'est ouverte, seul un script pilote Blender en arrière-plan, sans aucune intervention manuelle humaine.

### 5.3 Contrôleur de personnage
- Nœud `CharacterBody3D`.
- Déplacement relatif à l'orientation de la caméra (le personnage avance dans la direction projetée au sol de la caméra), avec rotation du personnage vers sa direction de déplacement — comportement de référence type GTA.
- Pas de saut prévu par défaut. À ne proposer que si cela s'avère nécessaire pour franchir naturellement certains éléments du décor — ne pas l'imposer sans raison.

---

## 6. Décor / environnement

### 6.1 Portée
Une **zone unique**, pensée pour être étendue facilement plus tard (l'utilisateur a précisé vouloir l'améliorer par itérations). Structurer la scène en sections modulaires identifiables (point d'entrée, zone centrale, limites extensibles) pour faciliter l'ajout de contenu sans refonte complète.

### 6.2 Assets
- Générés via les mêmes outils IA texte-vers-3D que le personnage, ou récupérés depuis des bibliothèques de modèles libres de droits compatibles glTF.
- Aucune modélisation manuelle humaine dans un logiciel 3D ouvert en interface graphique.

### 6.3 Éclairage et atmosphère (configuration `WorldEnvironment` + `DirectionalLight3D`)
- `DirectionalLight3D` unique simulant le clair de lune : teinte froide bleu-argentée, intensité modérée, angle bas/oblique pour des ombres longues, ombres portées activées.
- Brouillard volumétrique activé dans `WorldEnvironment` : densité faible à moyenne, teinte bleu-gris.
- Glow/bloom léger sur les sources lumineuses, tonemap filmique, vignette légère optionnelle pour le rendu "photographique" façon Fatal Frame.
- Ciel nocturne avec pleine lune visible, volontairement surdimensionnée (référence Vampire Hunter D: Bloodlust), étoiles discrètes, aucun cycle jour/nuit — il est toujours nuit, fixe.

---

## 7. Contrôles clavier — gestion automatique AZERTY/QWERTY

**Principe impératif : se baser sur la position physique des touches, jamais sur leur étiquette logicielle.**

- Dans Godot, configurer l'`InputMap` en utilisant le `physical_keycode` (et non `keycode`/`unicode`) des événements clavier.
- Mapper les 4 directions de déplacement sur la **position physique** correspondant à W/A/S/D sur un clavier QWERTY de référence. Le moteur traduit automatiquement cette position physique en Z/Q/S/D sur un clavier AZERTY et en W/A/S/D sur QWERTY — **sans qu'aucun code de détection de disposition ne soit nécessaire**.
- Ajouter en permanence, en parallèle, les flèches directionnelles comme méthode alternative toujours active, quelle que soit la disposition détectée par l'OS.
- (Optionnel, pour le débogage uniquement) L'agent peut interroger `OS.get_locale()` ou l'API Windows `GetKeyboardLayout` à titre de log/vérification, mais la fonctionnalité réelle des contrôles doit reposer sur le binding physique ci-dessus, plus robuste et universel que toute détection de locale.

---

## 8. Absence totale d'interface

- Aucun menu, aucun écran de chargement visible, aucun HUD, aucun curseur de souris visible à l'écran, aucun sous-titre, aucune pause accessible via un écran.
- Au lancement de l'exécutable : la fenêtre s'ouvre directement dans la scène, personnage déjà positionné dans le décor, contrôle disponible dès la première frame stable. **Aucune entrée autre qu'Échap (pour quitter) n'est requise pour commencer à marcher** — démarrage strictement instantané, sans aucune étape intermédiaire.
- Fenêtre en plein écran natif à la résolution du bureau de l'utilisateur, idéalement en mode bordless pour limiter la latence d'entrée tout en restant bien intégré à Windows.
- Seule sortie prévue : fermeture native de la fenêtre. Si le mode plein écran exclusif empêche un accès simple à la fermeture, la touche **Échap** peut quitter proprement l'application — exception tolérée car il s'agit d'une fonction système, pas d'un élément d'interface visible.

---

## 9. Performance — objectif secondaire (optimisation différée)

- Cible : 60 images/seconde stables sur la configuration matérielle décrite en section 0.
- S'assurer que l'exécutable final utilise le GPU NVIDIA dédié plutôt que l'iGPU AMD intégré. En pratique, le renderer Forward+ de Godot (Vulkan/D3D12) a déjà tendance à favoriser le GPU dédié par défaut sur les configurations à double carte graphique — ce n'est donc pas un point bloquant a priori, mais il doit être **vérifié empiriquement** une fois l'exécutable buildé (observer la carte graphique réellement utilisée, par exemple via le Gestionnaire des tâches Windows). Si l'iGPU est utilisé par erreur, appliquer en filet de sécurité une préférence GPU manuelle pour l'exécutable dans les paramètres graphiques Windows ou le panneau de contrôle NVIDIA.
- **Pour cette première itération, prioriser la correction fonctionnelle et le respect de la direction artistique plutôt que l'optimisation.** Une passe d'optimisation ultérieure pourra inclure, par ordre de priorité :
  1. **Frustum culling** — déjà géré nativement par le moteur de rendu de Godot, à ne pas recoder manuellement.
  2. **Distance de rendu limitée couplée au brouillard** pour masquer le clipping en bord de champ de vision, plutôt que d'afficher du décor inutilement loin.
  3. **Batching des appels de dessin** — utiliser `MultiMesh` pour les éléments répétés du décor (pierres, végétation, débris) plutôt que des instances individuelles.
  4. LOD sur les meshes les plus denses du décor, occlusion culling supplémentaire si nécessaire.
  5. Réduction de la résolution interne du brouillard volumétrique, passage à un éclairage semi-statique plutôt qu'un GI temps réel coûteux si la fps cible n'est pas atteinte.

---

## 10. Arborescence de projet indicative

```
/projet
  project.godot
  /scenes
    main.tscn              # scène principale : décor + environnement + personnage
    character.tscn         # personnage + caméra + script de contrôle
  /scripts
    character_controller.gd
    camera_rig.gd
  /assets
    /models
      character.glb
      environment_*.glb
    /textures
    /environment            # ressources WorldEnvironment, ciel, etc.
  /addons                    # plugins éventuels
```

---

## 11. Évolutivité future (hors scope immédiat)

Le décor est destiné à être enrichi par itérations successives selon le retour visuel. L'architecture de scène doit donc rester modulaire (zones clairement délimitées, conventions de nommage cohérentes) pour permettre l'ajout futur de contenu sans refonte complète. **Ne pas anticiper ni développer ces évolutions maintenant** (pas de système caché, pas de gameplay latent) — seulement s'assurer que l'architecture ne les empêche pas.

---

## 12. Critères d'acceptation de la version 1

- [ ] Le projet s'exporte en `.exe` Windows via un pipeline 100% CLI, sans aucune ouverture manuelle de l'éditeur.
- [ ] Au lancement : fenêtre plein écran, scène nocturne avec pleine lune dominante, brouillard volumétrique, architecture en ruine visible, éclairage froid bleu-argenté.
- [ ] Personnage féminin réaliste visible en troisième personne, contrôlable immédiatement dès le lancement.
- [ ] Déplacement fonctionnel en WASD (QWERTY) et ZQSD (AZERTY) automatiquement via le binding par position physique, plus les flèches directionnelles en permanence.
- [ ] Aucun menu, HUD, texte à l'écran, curseur de souris visible, ou élément d'interface de quelque nature que ce soit.
- [ ] Le jeu tend vers 60 fps sur la configuration cible (objectif secondaire, non bloquant pour cette version).

## 13. Livrables attendus de l'agent

1. Le code source complet du projet (scènes, scripts, ressources), organisé selon l'arborescence de la section 10.
2. Un fichier `README.md` à la racine du projet expliquant : la stack technique retenue et sa justification, les commandes exactes pour importer/tester/exporter le projet en mode headless, la procédure pour lancer l'exécutable final sur Windows 11.
3. L'exécutable Windows (`.exe`) exporté et prêt à être lancé par l'utilisateur.
