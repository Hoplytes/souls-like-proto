class_name Items
## Consumable items (the quick item slot, as in the Souls): their names,
## what they do, how many can be carried, and their little icons (drawn).
## Counts are kept in Progress.data.items; the selected one in .item.

const DATA := {
	"firebomb": {"name": "Bombe incendiaire", "desc": "Lancée, elle explose en flammes et le sol brûle un moment.",
		"max": 10, "time": 0.8, "at": 0.42, "anim": "throw"},
	"knife": {"name": "Couteau de lancer", "desc": "Vole droit : pour frapper de loin, ou attirer un ennemi seul.",
		"max": 20, "time": 0.5, "at": 0.25, "anim": "throw"},
	"resin": {"name": "Résine de charbon", "desc": "Enflamme l'arme pendant une minute : plus de dégâts.",
		"max": 5, "time": 0.9, "at": 0.6, "anim": "heal"},
	"moss": {"name": "Mousse violette", "desc": "Guérit du poison et vide sa jauge.",
		"max": 5, "time": 0.9, "at": 0.6, "anim": "heal"},
	"bone": {"name": "Os du retour", "desc": "Ramène au dernier feu où l'on s'est reposé.",
		"max": 5, "time": 1.4, "at": 1.25, "anim": "heal"},
}
const ORDER := ["firebomb", "knife", "resin", "moss", "bone"]

static func count(id: String) -> int:
	return int(Progress.data.items.get(id, 0))

static func add(id: String, n: int) -> int:
	var c := mini(count(id) + n, int(DATA[id].max))
	Progress.data.items[id] = c
	if Progress.data.item == "" or count(Progress.data.item) <= 0:
		Progress.data.item = id
	return c

static func take(id: String) -> bool:
	if count(id) <= 0:
		return false
	Progress.data.items[id] = count(id) - 1
	return true

## The item in the slot, or "" when none is carried.
static func selected() -> String:
	var id: String = Progress.data.get("item", "")
	if id != "" and count(id) > 0:
		return id
	for k in ORDER:  # the selected one ran out: the next one carried
		if count(k) > 0:
			Progress.data.item = k
			return k
	return ""

## Selects the next item carried (or the previous one).
static func cycle(step: int = 1) -> String:
	var cur := selected()
	if cur == "":
		return ""
	var k := ORDER.find(cur)
	for n in ORDER.size():
		k = posmod(k + step, ORDER.size())
		if count(ORDER[k]) > 0:
			Progress.data.item = ORDER[k]
			return ORDER[k]
	return cur

## Draws an item's icon, `s` px wide, centred on `c`.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var u := s / 20.0
	match id:
		"firebomb":
			ci.draw_circle(c + Vector2(0, 2) * u, 6.5 * u, Color(0.18, 0.16, 0.15))
			ci.draw_circle(c + Vector2(-2, 0) * u, 2.0 * u, Color(0.4, 0.38, 0.36))
			ci.draw_line(c + Vector2(2, -4) * u, c + Vector2(5, -8) * u, Color(0.6, 0.45, 0.3), 1.5 * u)
			ci.draw_circle(c + Vector2(5.5, -8.5) * u, 2.0 * u, Color(1.0, 0.6, 0.15))
			ci.draw_circle(c + Vector2(5.5, -8.5) * u, 1.0 * u, Color(1.0, 0.95, 0.6))
		"knife":
			ci.draw_line(c + Vector2(-7, 7) * u, c + Vector2(-2, 2) * u, Color(0.4, 0.25, 0.12), 3.0 * u)
			ci.draw_line(c + Vector2(-3, 1) * u, c + Vector2(1, 5) * u, Color(0.55, 0.5, 0.42), 1.5 * u)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 2) * u, c + Vector2(7, -7) * u,
				c + Vector2(1, 0) * u]), Color(0.85, 0.88, 0.92))
		"resin":
			ci.draw_rect(Rect2(c + Vector2(-5, -3) * u, Vector2(10, 10) * u), Color(0.45, 0.28, 0.12))
			ci.draw_rect(Rect2(c + Vector2(-3, -6) * u, Vector2(6, 3) * u), Color(0.3, 0.2, 0.1))
			ci.draw_circle(c + Vector2(0, 2) * u, 3.5 * u, Color(1.0, 0.5, 0.1))
			ci.draw_circle(c + Vector2(0, 2) * u, 1.6 * u, Color(1.0, 0.85, 0.4))
		"moss":
			for k in 5:
				var a := -PI / 2.0 + (k - 2) * 0.45
				ci.draw_line(c + Vector2(0, 6) * u, c + Vector2(0, 6) * u + Vector2.from_angle(a) * 10.0 * u,
					Color(0.6, 0.3, 0.7), 2.2 * u)
			ci.draw_circle(c + Vector2(0, 6) * u, 3.0 * u, Color(0.45, 0.2, 0.5))
		"bone":
			ci.draw_line(c + Vector2(-5, 5) * u, c + Vector2(5, -5) * u, Color(0.92, 0.9, 0.82), 2.5 * u)
			for e in [Vector2(-5, 5), Vector2(5, -5)]:
				ci.draw_circle(c + (e + e.orthogonal().normalized() * 1.6) * u, 2.2 * u, Color(0.92, 0.9, 0.82))
				ci.draw_circle(c + (e - e.orthogonal().normalized() * 1.6) * u, 2.2 * u, Color(0.92, 0.9, 0.82))
		"titanite":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8) * u, c + Vector2(6, 0) * u,
				c + Vector2(0, 8) * u, c + Vector2(-6, 0) * u]), Color(0.6, 0.78, 0.9))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8) * u, c + Vector2(6, 0) * u,
				c + Vector2(0, 0) * u]), Color(0.85, 0.95, 1.0))
