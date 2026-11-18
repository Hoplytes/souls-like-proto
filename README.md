# Souls-like Proto

Prototype de combat souls-like en vue de dessus, en pixel art, fait avec **Godot 4.5**.

**Jouer dans le navigateur :** https://hoplytes.github.io/souls-like-proto/
(la page se met à jour automatiquement à chaque modification poussée sur `main`).

## Contenu du prototype

- Un **hoplite spartiate** (casque à crête, cuirasse de bronze, cape rouge, bouclier rond), deux armes : **lance** (longue portée, attaque lourde en fente) et **épée courte** (rapide, arc large).
- **Roulade** avec frames d'invincibilité, **endurance**, attaques **légères** (combo x3) et **lourdes** (super-armure pendant le coup).
- **Bouclier** : maintenir pour bloquer les coups de face (coûte de l'endurance ; à court d'endurance, la garde est brisée). Le lever **au moment de l'impact** déclenche une **parade** : aucun coût, l'ennemi est déséquilibré et le coup suivant fait une **riposte** à double dégâts. Le saut écrasant et l'onde de choc du boss ne se bloquent pas : il faut rouler.
- **Fioles** de soin (3) et un **feu de camp** : se reposer remet la santé et les fioles, et fait revenir les ennemis.
- 4 **squelettes** qui annoncent leurs attaques et laissent une fenêtre de punition.
- Le boss **Gorvak, Geôlier des Ruines** : estoc, saut écrasant et charge, tous annoncés par une zone rouge. En dessous de 50 % de vie, il entre en rage (attaques plus rapides, double estoc, onde de choc). Une charge dans un mur l'étourdit.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche, croix |
| Roulade | Espace | B |
| Bouclier (maintenir) / parade | L ou Maj | LB |
| Attaque légère | J ou clic gauche | X ou RB |
| Attaque lourde | K ou clic droit | Y ou RT |
| Boire une fiole | R | LT |
| Changer d'arme | Tab | Select |
| Se reposer au feu | E | A |
| Aide | H | Start |
| Couper / remettre le son | M | |
| Sons enregistrés ↔ sons de synthèse | N | |

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/main.gd` | Construit le niveau, le feu de camp, l'arène, les commandes |
| `scripts/player.gd` | Le joueur : états, roulade, endurance, combos, soin |
| `scripts/weapons.gd` | **Les armes sous forme de données** : ajouter une arme = ajouter une entrée |
| `scripts/actor.gd` | Base commune : santé, poise (résistance), coups reçus, mort |
| `scripts/skeleton.gd` | Ennemi de base |
| `scripts/boss.gd` | Le boss et ses attaques |
| `scripts/lpc_sprite.gd` | Superpose les couches de sprites (arme arrière, corps, arme avant) |
| `scripts/fx.gd` | Effets : étincelles, zones d'alerte, tremblement d'écran, hit-stop |
| `tools/compose_lpc.py` | Assemble les sprites LPC en planches pour Godot |
| `tools/autotest.gd` | Partie automatique qui prend des captures (`godot -- --autotest=<dossier>`) |

## Décors

Le sol (herbe dorée d'automne, chemins pavés), les arbres, rochers, plantes et piliers viennent de
[LPC Revised](https://github.com/ElizaWy/LPC). `scripts/ground.gd` choisit automatiquement les tuiles
de bord et d'angle de l'herbe ; `scripts/prop.gd` place les éléments de décor.

## Sons

Deux jeux de sons, comparables en jeu avec la touche **N** :
- **enregistrés** (par défaut) : sons réels de l'*Oculus Audio Pack 01* (CC BY 4.0) et du pack *Impact Sounds* de
  Kenney (CC0), dans `assets/sfx_cc0/` ; crédits dans [CREDITS-AUDIO.md](CREDITS-AUDIO.md) ;
- **synthèse** : tous les sons générés par `tools/make_sfx.py` (`assets/sfx/`), sans licence à gérer.

Les sons sans enregistrement (soin, feu de camp, saut et charge du boss…) utilisent la synthèse dans les deux cas.
La correspondance entre événements du jeu et fichiers est dans `scripts/sfx.gd`.

## Régénérer les sprites

Les planches de `assets/sprites/` sont produites à partir du dépôt
[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) :

```bash
python3 tools/compose_lpc.py <chemin-du-dépôt-LPC>/spritesheets
python3 tools/lpc_credits.py <chemin-du-dépôt-LPC>/CREDITS.csv
python3 tools/extract_env.py <chemin-du-dépôt-LPC-Revised>
```

## Licences

Les sprites LPC sont sous licences libres (OGA-BY 3.0, CC-BY-SA 3.0 ou GPL 3.0 selon les pièces) :
voir [CREDITS-LPC.md](CREDITS-LPC.md). Les décors sont sous licence OGA-BY 3.0 : voir [CREDITS-ENV.md](CREDITS-ENV.md). Ces crédits doivent accompagner le jeu s'il est distribué.
