# Souls-like Proto

Prototype de souls-like en vue isométrique, fait avec **Godot 4.5**. Rendu net en 1280 × 720 et plus : l'art de
Flare est stocké à sa pleine résolution (`RES = 2` dans `tools/convert_flare.py`).

**Jouer dans le navigateur :** https://hoplytes.github.io/souls-like-proto/
(la page se met à jour automatiquement à chaque modification poussée sur `main`).

## Contenu du prototype

- **Créateur de personnage** au lancement : homme ou femme, tête, coiffe, torse, mains, jambes, pieds,
  arme (13 armes, 5 styles de combat), bouclier et teinte d'armure. Le héros est sauvegardé.
  Le créateur est aussi accessible depuis le **menu pause** (Échap).
- Un **monde ouvert** de 96 × 96 cases en quatre biomes, chacun avec sa musique, son ambiance sonore, sa lumière,
  ses ennemis et son **feu de camp** (se reposer remet la santé et les fioles, fait revenir les ennemis et devient
  le point de réapparition) :
  - **Plaine de l'Aube** (sud, départ) : forêts, gobelins ;
  - **Ruines d'Hélos** (ouest) : piliers, statues, squelettes et zombies ;
  - **Crêtes gelées** (est) : neige, glace, fourmis des glaces, et la wyverne **Glacevive** ;
  - **Grottes d'ambre** (nord) : stalagmites, fourmilions, fourmis de feu, et le portail du donjon.
- Le **Labyrinthe d'Astérion**, un donjon éclairé par des braseros, atteint par un portail dans les grottes.
- **Téléportation de test** : la touche **T** ouvre un menu vers tous les feux de camp et toutes les arènes de boss.
- **Combat** : roulade avec frames d'invincibilité (culbute), endurance, attaques légères (combo x3) et
  lourdes (super-armure pendant le coup), **bouclier** (blocage, parade au bon moment, riposte à double dégâts),
  fioles de soin. Chaque famille d'armes a son rythme : dague, épée, hache, arme contondante, arme à deux mains.
- Deux boss, **Glacevive, la Wyverne des cimes** et **Astérion, le Minotaure** : grand coup de hache en arc, saut écrasant et charge, annoncés par une
  zone rouge. Sous 50 % de vie, ils entrent en rage. Une barrière de lumière ferme l'arène au début du combat.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche, croix |
| Roulade | Espace | B |
| Bouclier (maintenir) / parade | L ou Maj | LB |
| Attaque légère | J ou clic gauche | X ou RB |
| Attaque lourde | K ou clic droit | Y ou RT |
| Boire une fiole | R | LT |
| Se reposer au feu | E | A |
| Téléportation (test) | T, puis un chiffre ou un clic | Select |
| Menu pause (reprendre, téléportation, son, aide, créateur, recommencer) | Échap ou P | Start |
| Aide | H | |
| Couper / remettre le son | M | |
| Sons enregistrés ↔ sons de synthèse | N | |

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/creator.gd` | Écran de création du personnage |
| `scripts/hero_config.gd` | Choix du héros (pièces, noms, sauvegarde dans `user://hero.json`) |
| `scripts/avatar_sprite.gd` | Le héros modulaire : une couche par emplacement, ordonnées selon la direction |
| `scripts/hd_sprite.gd` | Joue une planche en 8 directions (pièces du héros, ennemis, chevalier HD) |
| `scripts/game.gd` | Le monde ouvert (biomes, décors, donjon, portails, téléportation) et le déroulement de la partie |
| `scripts/game_menu.gd` | Menus du jeu en pause (pause, téléportation) |
| `scripts/player.gd` | Le joueur : états, roulade, endurance, combos, bouclier, soin |
| `scripts/weapons.gd` | **Les armes et leurs styles de combat, sous forme de données** |
| `scripts/actor.gd` | Base commune : santé, poise (résistance), coups reçus, parade, riposte, mort |
| `scripts/skeleton.gd` | Ennemis ordinaires (squelette, zombie, gobelin, fourmis…), un tableau de caractéristiques par type |
| `scripts/boss.gd` | Les boss (Minotaure, wyverne) et leurs attaques |
| `scripts/fx.gd`, `sfx.gd`, `music.gd` | Effets visuels, bruitages, musique |
| `tools/convert_flare.py` | Convertit l'art de Flare (héros, ennemis, tuiles) |
| `tools/make_sfx.py` | Synthétise les bruitages |
| `tools/autotest.gd` | Partie automatique avec captures (`godot -- --autotest=<dossier>`) |
| `tools/showcase.gd` | Filme les mouvements du héros (`godot -- --showcase=<dossier>`) |

## Graphismes

Héros, ennemis et tuiles des biomes viennent de [Flare](https://github.com/flareteam/flare-game) (CC-BY-SA 3.0), des rendus
3D en 8 directions, convertis par :

```bash
python3 tools/convert_flare.py <dépôt flare-game>                 # ennemis et tuiles
python3 tools/convert_flare.py <dépôt flare-game> --avatar-only   # pièces du héros
```

Les assets **sous licence payante** (par exemple le chevalier HD de SmallScaleInt, proposé comme modèle dans le
créateur) sont dans le dépôt **privé** `Hoplytes/souls-like-assets`, récupéré dans `local/` lors de la publication
(secret `ASSETS_TOKEN`). Ils ne doivent jamais être ajoutés à ce dépôt public.

## Sons

Deux jeux de sons, comparables en jeu avec la touche **N** :
- **enregistrés** (par défaut) : sons réels de l'*Oculus Audio Pack 01* (CC BY 4.0) et du pack *Impact Sounds* de
  Kenney (CC0), dans `assets/sfx_cc0/` ; crédits dans [CREDITS-AUDIO.md](CREDITS-AUDIO.md) ;
- **synthèse** : tous les sons générés par `tools/make_sfx.py` (`assets/sfx/`), sans licence à gérer.

**Musiques, ambiances et bruitages de Flare** (CC-BY-SA 3.0, `assets/flare_audio/`) : un thème par biome, des boucles
d'ambiance (oiseaux, corbeaux, vent, gouttes dans les grottes), les cris des ennemis et le portail.

**Musique des boss** (`scripts/music.gd`) : *Battle Theme A* de cynicmusic pendant la première phase, puis
*Boss Battle #8 [Metal]* de nene quand le boss entre en rage (deux morceaux CC0).

## Licences

- Art de Flare : CC-BY-SA 3.0, voir [CREDITS-FLARE.md](CREDITS-FLARE.md).
- Sons et musique : voir [CREDITS-AUDIO.md](CREDITS-AUDIO.md).
