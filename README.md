# Souls-like Proto

Prototype de combat souls-like en vue de dessus, en pixel art, fait avec **Godot 4.5**.

**Jouer dans le navigateur :** https://hoplytes.github.io/souls-like-proto/
(la page se met à jour automatiquement à chaque modification poussée sur `main`).

## Contenu du prototype

- Un chevalier en armure de plaques, deux armes : **épée longue** (rapide, arc large) et **lance** (longue portée, attaque lourde en fente).
- **Roulade** avec frames d'invincibilité, **endurance**, attaques **légères** (combo x3) et **lourdes** (super-armure pendant le coup).
- **Fioles** de soin (3) et un **feu de camp** : se reposer remet la santé et les fioles, et fait revenir les ennemis.
- 4 **squelettes** qui annoncent leurs attaques et laissent une fenêtre de punition.
- Le boss **Gorvak, Geôlier des Ruines** : estoc, saut écrasant et charge, tous annoncés par une zone rouge. En dessous de 50 % de vie, il entre en rage (attaques plus rapides, double estoc, onde de choc). Une charge dans un mur l'étourdit.

## Commandes

| Action | Clavier / souris | Manette |
|---|---|---|
| Se déplacer | ZQSD (AZERTY) / WASD (QWERTY) / flèches | Stick gauche, croix |
| Roulade | Espace ou Maj | B |
| Attaque légère | J ou clic gauche | X ou RB |
| Attaque lourde | K ou clic droit | Y ou RT |
| Boire une fiole | R | LB |
| Changer d'arme | Tab | Select |
| Se reposer au feu | E | A |
| Aide | H | Start |

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

## Régénérer les sprites

Les planches de `assets/sprites/` sont produites à partir du dépôt
[Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) :

```bash
python3 tools/compose_lpc.py <chemin-du-dépôt-LPC>/spritesheets
python3 tools/lpc_credits.py <chemin-du-dépôt-LPC>/CREDITS.csv
```

## Licences

Les sprites LPC sont sous licences libres (OGA-BY 3.0, CC-BY-SA 3.0 ou GPL 3.0 selon les pièces) :
voir [CREDITS-LPC.md](CREDITS-LPC.md). Ces crédits doivent accompagner le jeu s'il est distribué.
