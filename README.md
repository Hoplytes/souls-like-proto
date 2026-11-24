# Souls-like Proto

Prototype de souls-like en vue isométrique, fait avec **Godot 4.5**, rendu à la résolution de l'écran (1280 × 720
et plus).

**Jouer dans le navigateur :** https://hoplytes.github.io/souls-like-proto/
(la page se met à jour automatiquement à chaque modification poussée sur `main`).

## Contenu du prototype

- **Choix du héros** au lancement (aussi dans le menu pause) : le combattant au bouclier rond du pack *Fantasy
  tileset* (combo de trois coups différents, deux coups lourds, pas chassés et course arrière en verrouillage) ou le
  chevalier HD (trois coups dont un tournoyant, vraie roulade, blocage en deux temps), tous deux de SmallScaleInt.
- Un **monde ouvert** de 96 × 96 cases dessiné avec le pack *Fantasy tileset - 2D Isometric* de SmallScaleInt, en
  quatre biomes, chacun avec sa musique, son ambiance sonore, sa lumière, ses ennemis et son **feu de camp** (se
  reposer remet la santé et les fioles, fait revenir les ennemis et devient le point de réapparition) :
  - **Plaine de l'Aube** (sud, départ) : chênes, haies, brigands ; un **village** (maisons de pierre et de bois,
    place pavée, puits, étals, moulin) et un **lac** aux berges de terre ;
  - **Ruines d'Hélos** (ouest) : herbe d'automne, dallages, statues, colonnes, squelettes et brigands ;
  - **Forêt des Cimes** (est) : pins, rochers, et l'arène de la wyverne **Glacevive** entourée de menhirs ;
  - **Terres mortes** (nord) : arbres morts, cristaux, squelettes, et le portail du donjon.
- Le **Labyrinthe d'Astérion**, un donjon de pierre éclairé par des braseros, atteint par le portail.
- **Téléportation de test** : la touche **T** ouvre un menu vers les feux de camp, le village, le lac et les boss.
- **Combat** façon Souls : le déplacement répond tout de suite, mais chaque action engage. Une attaque ne s'oriente
  qu'au début de son armement et ne s'annule qu'en fin de récupération ; une touche pressée pendant une action part à
  sa fin. **Verrouillage** comme dans les Souls : le héros fait face à la cible, se déplace en pas chassés autour
  d'elle, la caméra cadre les deux, et la cible suivante est prise si la première meurt. Roulade avec frames
  d'invincibilité, endurance, attaques légères (combo x3) et lourdes (super-armure pendant le coup), **bouclier**
  (blocage, parade au bon moment, riposte à double dégâts), fioles de soin.
- Deux boss (art de Flare), **Glacevive, la Wyverne des cimes** et **Astérion, le Minotaure** : grand coup de hache
  en arc, saut écrasant et charge, annoncés par une zone rouge. Sous 50 % de vie, ils entrent en rage. Une barrière
  de lumière ferme l'arène au début du combat.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche, croix |
| Roulade | Espace | B |
| Bouclier (maintenir) / parade | L ou Maj | LB |
| Attaque légère | J ou clic gauche | X ou RB |
| Attaque lourde | K ou clic droit | Y ou RT |
| Boire une fiole | R | LT |
| Verrouiller un ennemi / lâcher | I ou clic molette | R3 (clic du stick droit) |
| Changer de cible verrouillée | U / O ou molette | Stick droit gauche / droite |
| Se reposer au feu | E | A |
| Carte | Tab | Select |
| Téléportation (test) | T, puis un chiffre ou un clic | (menu pause) |
| Menu pause (reprendre, carte, téléportation, caméra, son, aide, choix du héros, recommencer) | Échap ou P | Start |
| Aide | H | |
| Couper / remettre le son | M | |
| Sons enregistrés ↔ sons de synthèse | N | |

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/creator.gd` | Écran de choix du héros |
| `scripts/hero_config.gd` | Le modèle choisi (sauvegardé dans `user://hero.json`) |
| `scripts/hd_sprite.gd` | Joue une planche en 8 directions (héros, ennemis, boss) |
| `scripts/game.gd` | Le monde ouvert (biomes, décors, village, lac, donjon, portails, téléportation) et le déroulement de la partie |
| `scripts/game_menu.gd` | Menus du jeu en pause (pause, téléportation) |
| `scripts/map_view.gd` | L'écran de carte |
| `scripts/player.gd` | Le joueur : états, roulade, endurance, combos, bouclier, soin |
| `scripts/weapons.gd` | **Les armes et leurs styles de combat, sous forme de données** |
| `scripts/actor.gd` | Base commune : santé, poise (résistance), coups reçus, parade, riposte, mort |
| `scripts/skeleton.gd` | Ennemis ordinaires (squelettes, brigands), un tableau de caractéristiques par type |
| `scripts/boss.gd` | Les boss (Minotaure, wyverne) et leurs attaques |
| `scripts/fx.gd`, `sfx.gd`, `music.gd` | Effets visuels, bruitages, musique |
| `tools/convert_fantasy.py` | Convertit le pack payant de SmallScaleInt vers `local/fantasy/` (dépôt privé) |
| `tools/convert_flare.py` | Convertit les boss, les musiques et les bruitages de Flare |
| `tools/make_sfx.py` | Synthétise les bruitages |
| `tools/autotest.gd` | Partie automatique avec captures (`godot -- --autotest=<dossier>`) |
| `tools/profile.gd` | Traverse des biomes et note les images lentes (`godot -- --profile=<dossier>`) |
| `tools/showcase.gd` | Filme les mouvements du héros (`godot -- --showcase=<dossier>`) |

## Graphismes

**Pack payant** : le décor, le héros, les squelettes et les brigands viennent du pack *Fantasy tileset - 2D
Isometric* de SmallScaleInt, et le chevalier HD du même auteur. Ces fichiers sont dans le dépôt **privé**
`Hoplytes/souls-like-assets`, récupéré dans `local/` lors de la publication (secret `ASSETS_TOKEN`). Ils ne doivent
jamais être ajoutés à ce dépôt public. Conversion du pack (le zip est attaché à une release du dépôt privé) :

```bash
python3 tools/convert_fantasy.py <zip ou dossier du pack> local/fantasy
```

Les deux **boss** (Minotaure, wyverne) viennent de [Flare](https://github.com/flareteam/flare-game) (CC-BY-SA 3.0),
convertis par `python3 tools/convert_flare.py <dépôt flare-game>`, qui copie aussi ses musiques et bruitages.

## Sons

Deux jeux de sons, comparables en jeu avec la touche **N** :
- **enregistrés** (par défaut) : sons réels de l'*Oculus Audio Pack 01* (CC BY 4.0) et du pack *Impact Sounds* de
  Kenney (CC0), dans `assets/sfx_cc0/` ; crédits dans [CREDITS-AUDIO.md](CREDITS-AUDIO.md) ;
- **synthèse** : tous les sons générés par `tools/make_sfx.py` (`assets/sfx/`), sans licence à gérer.

**Musiques, ambiances et bruitages de Flare** (CC-BY-SA 3.0, `assets/flare_audio/`) : un thème par biome, des boucles
d'ambiance (oiseaux, corbeaux, vent, chouette), les cris des ennemis et le portail.

**Musique des boss** (`scripts/music.gd`) : *Battle Theme A* de cynicmusic pendant la première phase, puis
*Boss Battle #8 [Metal]* de nene quand le boss entre en rage (deux morceaux CC0).

## Licences

- Art de Flare (boss) : CC-BY-SA 3.0, voir [CREDITS-FLARE.md](CREDITS-FLARE.md).
- Pack de SmallScaleInt : licence commerciale, fichiers non redistribués (dépôt privé).
- Sons et musique : voir [CREDITS-AUDIO.md](CREDITS-AUDIO.md).
