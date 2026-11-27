# Souls-like Proto

Prototype de souls-like en vue isométrique, fait avec **Godot 4.5**, rendu à la résolution de l'écran (1280 × 720
et plus).

**Jouer dans le navigateur :** https://hoplytes.github.io/souls-like-proto/
(la page se met à jour automatiquement à chaque modification poussée sur `main`).

## Contenu du prototype

- **Boucle de Souls** : chaque ennemi tué donne des **âmes**. À la mort (écran « VOUS ÊTES MORT »), elles restent
  par terre dans une **tache de sang** (verte, aussi marquée sur la carte) : on les récupère avec E en y retournant,
  mais mourir encore avant les fait perdre pour de bon. Les **feux de camp** sont éteints tant qu'on ne les a pas
  allumés (sauf celui du départ) ; s'y reposer rend la santé et les fioles, fait revenir les ennemis, devient le point
  de réapparition et ouvre leur menu : **monter de niveau** avec les âmes (Vigueur → santé, Endurance → endurance,
  Force → dégâts, chaque niveau coûtant plus cher) et **voyager** entre les feux allumés.
- **Sauvegarde** automatique (`user://save.json`, dans le navigateur le stockage du site) : âmes, niveau,
  caractéristiques, feux allumés, boss vaincus, objets pris, tache de sang. L'écran d'accueil propose **Continuer** ou
  **Nouvelle partie** (avec confirmation).
- **Objets et coffres** : des lueurs blanches (un rayon de lumière les signale de loin) à ramasser et des coffres à
  ouvrir (maisons, ruines, camp, ville, donjon, hautes terres, ponton) ; quatre **éclats de fiole** portent les fioles
  de 3 à 7. Les ennemis laissent parfois tomber un objet.
- **Objets à utiliser** (emplacement rapide en bas à gauche, F pour utiliser, G pour changer) : **bombe incendiaire**
  (explose en flammes, le sol brûle un moment), **couteau de lancer**, **résine de charbon** (arme enflammée une
  minute, plus de dégâts), **mousse violette** (guérit du poison), **os du retour** (ramène au dernier feu).
- **Renforcer l'arme** au feu de camp, de +1 à +5, avec des **éclats de titanite** (coffres, élites) et des âmes.
- **Poison** : des nappes de gaz dans les Terres mortes remplissent une jauge ; pleine, le héros est empoisonné et perd
  de la santé un moment (la mousse violette ou un feu de camp en guérissent).
- **Fiche du personnage** dans le menu pause : niveau, caractéristiques, arme, fioles, objets, progression.
- **Élites** : plus grands, plus sombres et bien plus coriaces, ils gardent les trésors (camp, cimetière, donjon),
  rapportent cinq fois plus d'âmes et souvent un éclat de titanite.
- **Messages au sol** (glyphes orange, E pour lire) : conseils et avertissements laissés par ceux qui sont passés
  avant.
- **Brouillard des boss** : un mur de brume blanche entoure leur arène ; E pour le traverser, et plus de sortie tant
  que le boss vit. Vaincu, il laisse beaucoup d'âmes.

- **Choix du héros** au lancement (aussi dans le menu pause) : le combattant au bouclier rond du pack *Fantasy
  tileset* (combo de trois coups différents, deux coups lourds, pas chassés et course arrière en verrouillage) ou le
  chevalier HD (trois coups dont un tournoyant, vraie roulade, blocage en deux temps), tous deux de SmallScaleInt.
- Un **monde ouvert** de 128 × 128 cases dessiné avec le pack *Fantasy tileset - 2D Isometric* de SmallScaleInt et
  tracé par `scripts/world_map.gd` : quatre régions aux frontières naturelles, des hautes terres coupées de vallées,
  une rivière qui descend des hauteurs de l'est vers un lac puis vers le sud, des routes entre les feux de camp (bords
  d'herbe, ponts de planches), des forêts denses avec clairières et sous-bois. Chaque région a sa musique, son ambiance
  sonore, sa lumière, ses ennemis et son **feu de camp** (se reposer remet la santé et les fioles, fait revenir les
  ennemis et devient le point de réapparition) :
  - **Plaine de l'Aube** (sud, départ) : chênaies, haies, brigands et leur **camp** ; le **village** (deux rues, une
    place avec son puits, une quinzaine de maisons où l'on peut entrer, le toit s'efface), ses **champs** clôturés et
    son moulin ; le **lac** et son ponton ; une ferme de l'autre côté de la rivière ;
  - **Ruines d'Hélos** (ouest) : bois d'automne et la **ville en ruine** (rues pavées, murs effondrés, place à
    colonnade) ;
  - **Forêt des Cimes** (est) : hautes terres couvertes de pins, et le cirque de falaises de la wyverne **Glacevive** ;
  - **Terres mortes** (nord) : arbres morts, rochers et cristaux, un cimetière, et la **grotte** du donjon au pied
    d'une falaise.
- **Relief** : les hautes terres sont bordées de falaises ; on y monte par des rampes taillées dans la roche ; les
  personnages et le décor d'en haut sont dessinés un niveau plus haut.
- **Forêts** : les arbres devant le héros s'estompent en douceur, d'autant plus qu'ils le cachent (une éclaircie qui
  le suit, sans clignotement), et sa silhouette reste visible à travers les bois épais ; un ennemi caché par un arbre
  passe au premier plan.
- **Rivages** : l'eau et la terre se rejoignent le long d'une rive courbe et irrégulière (terre mouillée, eau claire
  des hauts-fonds, écume qui vient lécher le bord), tracée par les shaders de `shaders/`.
- **Décor destructible** : tonneaux, jarres, caisses, foin, hautes herbes, petits arbres et tas de pierres, cassés en
  plusieurs coups (2 coups légers pour l'herbe, 3 pour le bois, 4 pour la pierre ; un coup lourd compte double), avec
  éclats de bois ou de pierre à chaque coup.
- Le **Labyrinthe d'Astérion**, un donjon de pierre éclairé par des braseros, atteint par la grotte.
- **Téléportation de test** : la touche **T** ouvre un menu vers les feux de camp, le village, le lac, la ville en
  ruine, le camp des brigands et les boss.
- **Combat** façon Souls : le déplacement répond tout de suite, mais chaque action engage. Une attaque ne s'oriente
  qu'au début de son armement et ne s'annule qu'en fin de récupération ; une touche pressée pendant une action part à
  sa fin. **Verrouillage** comme dans les Souls : le héros fait face à la cible, se déplace en pas chassés autour
  d'elle, la caméra cadre les deux, et la cible suivante est prise si la première meurt. Roulade avec frames
  d'invincibilité (au relâchement de la touche : **la maintenir fait courir**, en dépensant de l'endurance ; sans
  direction, c'est un **pas en arrière**), endurance, attaques légères (combo x3) et lourdes (super-armure pendant le
  coup), **attaque en courant**, **bouclier** (blocage, parade au bon moment), fioles de soin.
- **Coups critiques** : une attaque légère dans le dos d'un ennemi qui ne vous fait pas face (**coup dans le dos**),
  ou sur un ennemi déséquilibré par une parade ou une garde brisée (**riposte**), est une longue frappe, invincible,
  à triple dégâts.
- **Ennemis façon Souls** (`scripts/skeleton.gd`) : ils montent la garde et ne voient que devant eux (on peut les
  surprendre par derrière), préviennent leurs voisins, tournent autour du héros en attendant une ouverture, puis
  attaquent avec les coups de leur animation (le coup part sur la bonne image), parfois en enchaînant ; pas plus de
  deux à la fois. Le squelette à la hache fend, charge et libère une onde magique ; le **mage** recule et lance des
  traits, la foudre (un cercle au sol : sortez-en) et une onde quand on l'approche ; le **porte-bouclier** pare les
  coups de face jusqu'à ce que sa garde cède (prenez-le de côté) ; les **brigands** sont rapides, bondissent et
  reculent après leurs combos ; le **lanceur** jette des couteaux. Frappés hors de leurs attaques, ils vacillent, mais
  pas indéfiniment ; trop loin de leur poste, ils y retournent et guérissent. Barre de vie et dégâts cumulés au-dessus
  d'eux.
- Deux boss (art de Flare), **Glacevive, la Wyverne des cimes** et **Astérion, le Minotaure** : grand coup de hache
  en arc, saut écrasant et charge, annoncés par une zone rouge. Sous 50 % de vie, ils entrent en rage.
- Un troisième boss, **Ossian, le Roi des Os** (`scripts/skeleton_king.gd`), squelette géant du pack, sur la place de la
  ville en ruine : coups de hache, ruée, onde magique, vague d'énergie ; en rage, tempête de foudre, souffle de
  flammes et morts qui se relèvent de leurs os. Les squelettes vaincus s'effondrent en tas d'os.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche, croix |
| Roulade (au relâchement) ; maintenir : courir ; sans direction : pas en arrière | Espace | B |
| Bouclier (maintenir) / parade | L ou Maj | LB |
| Attaque légère | J ou clic gauche | RB |
| Attaque lourde | K ou clic droit | Y ou RT |
| Boire une fiole | R | LT |
| Utiliser l'objet de l'emplacement rapide | F | X |
| Changer d'objet | G | Croix haut / bas |
| Verrouiller un ennemi / lâcher | I ou clic molette | R3 (clic du stick droit) |
| Changer de cible verrouillée | U / O ou molette | Stick droit gauche / droite |
| Interagir : feu de camp, objet, coffre, tache de sang, brouillard | E | A |
| Carte | Tab | Select |
| Téléportation (test) | T, puis un chiffre ou un clic | (menu pause) |
| Menu pause (reprendre, fiche du personnage, carte, téléportation, caméra, son, aide, menu principal, recommencer) | Échap ou P | Start |
| Aide | H | |
| Couper / remettre le son | M | |
| Sons enregistrés ↔ sons de synthèse | N | |

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/creator.gd` | Écran d'accueil : choix du héros, continuer ou nouvelle partie |
| `scripts/progress.gd` | **La progression sauvegardée** : âmes, niveau et caractéristiques, feux, boss, objets, tache de sang |
| `scripts/hero_config.gd` | Le modèle choisi (sauvegardé dans `user://hero.json`) |
| `scripts/hd_sprite.gd` | Joue une planche en 8 directions (héros, ennemis, boss) |
| `scripts/world_map.gd` | **La géographie** : régions, relief, eau, routes, forêts, emplacements (village, champs, ville, camps) |
| `scripts/game.gd` | Construit le monde à partir de la carte (sol, décor par blocs, relief, maisons, donjon, portails) et le déroulement de la partie |
| `scripts/game_menu.gd` | Menus du jeu en pause (pause, feu de camp, niveaux, voyage, téléportation) |
| `scripts/map_view.gd` | L'écran de carte |
| `scripts/player.gd` | Le joueur : états, roulade, endurance, combos, bouclier, soin |
| `scripts/weapons.gd` | **Les armes et leurs styles de combat, sous forme de données** |
| `scripts/actor.gd` | Base commune : santé, poise (résistance), coups reçus, parade, riposte, mort |
| `scripts/breakable.gd` | Décor destructible |
| `scripts/skeleton.gd` | Ennemis ordinaires (squelettes, brigands) : comportement, **types et coups sous forme de données** |
| `scripts/projectile.gd` | Traits magiques et couteaux lancés |
| `scripts/skeleton_king.gd` | Le Roi des Os, boss de la ville en ruine |
| `scripts/items.gd`, `thrown.gd` | Objets à utiliser (emplacement rapide), bombe incendiaire |
| `scripts/enemy_bar.gd` | Barre de vie au-dessus des ennemis |
| `scripts/pickup.gd`, `bonfire.gd`, `fog_wall.gd` | Objets et tache de sang, feux de camp, brouillard des boss |
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
