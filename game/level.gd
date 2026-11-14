extends RefCounted
# The one hand-authored level: "The Sun Slept In".
# Layout notes (units are pixels; Bloop is 54 wide, a legs jump clears about 125):
#   meadow -> boing ledge -> rolling hill + pond leap -> boing garden ->
#   kick yard + gate -> hollow floor -> big boing wall -> long descent + launch -> bell.
const BOTTOM := 2000.0
const LEFT := -140.0
const RIGHT := 10950.0
const START := Vector2(180, 560)
const POND := Rect2(3180, 965, 360, 240)

static func c(x: float, y: float) -> Vector3:
	return Vector3(x, y, 1)

static func s(x: float, y: float) -> Vector3:
	return Vector3(x, y, 0)

static func build(w: Node) -> void:
	for chunk in [
		[c(-800, -300), c(LEFT, -300), c(LEFT, 600), s(200, 600), s(500, 590), s(800, 604), s(1100, 600), c(1260, 600)],
		[c(1260, 430), s(1700, 430), s(1900, 470), s(2200, 640), s(2500, 860), s(2750, 935), s(2950, 905), s(3100, 830), c(3180, 772)],
		[c(3180, 1180), c(3540, 1180)],
		[c(3540, 860), s(3800, 860), s(4100, 852), c(4300, 860)],
		[c(4300, 700), c(4650, 700)],
		[c(4650, 540), c(5000, 540)],
		[c(5000, 380), s(5400, 380), s(5800, 384), c(6300, 380)],
		[c(6300, 640), c(6600, 640)],
		[c(6600, 380), c(7000, 380)],
		[c(7000, 60), s(7300, 60), s(7500, 100), s(7900, 400), s(8300, 760), s(8700, 905), s(9000, 880), s(9200, 810), c(9300, 752), s(9390, 800), s(9560, 770), s(9760, 705), s(10000, 700), c(RIGHT, 700)],
		[c(RIGHT, -300), c(RIGHT + 700, -300)],
	]:
		w.add_ground(chunk)
	w.add_island(Vector2(700, 492), 150, 36)
	w.add_island(Vector2(4800, 250), 200, 44)
	w.add_island(Vector2(7150, -130), 180, 40)

	# Mushrooms: x, rotation, power, width.
	w.add_mushroom(1175, 0.0, 900, 120)
	w.add_mushroom(4225, 0.0, 900, 120)
	w.add_mushroom(4575, 0.0, 900, 120)
	w.add_mushroom(4925, 0.0, 900, 120)
	w.add_mushroom(6370, 0.0, 1090, 110)
	w.add_mushroom(6900, 0.0, 900, 160)

	for x in [1420, 3660, 5080, 6690, 7110, 9900]:
		w.add_checkpoint(x)

	w.add_sign(300, ["move"], "DRAG TO WALK")
	w.add_sign(590, ["jump"], "JUMP")
	w.add_sign(1030, ["boing"], "BOING")
	w.add_sign(1640, ["roll"], "TUCK + ROLL")
	w.add_sign(5390, ["kick"], "KICK")
	w.add_sign(6180, ["roll", "+", "jump", "+", "pound"], "SLAM")
	w.add_sign(6790, ["boing", "+", "jump"], "HOLD JUMP: BIG BOING")
	w.add_sign(7240, ["roll", "+", "boost"], "ZOOM")

	w.add_critter(450, ["Oh. You're up. Nobody else is. The sun slept in again.", "Seeds everywhere. Someone should pick those up. Not me."], "Morning! Finally. I was running out of yawns.", Color("b9a2f2"), 1.0, 1)
	w.add_critter(1530, ["Tuck your legs in and ROLL. Gravity does the rest. Gravity is very reliable.", "Fast down the hill, then the ramp. Do not think about the pond."], "You woke it! I watched. From here. Supportively.", Color("8fd6c0"), 1.25, 3)
	w.add_critter(3960, ["You flew. I felt a breeze. Best thing to happen all week.", "The mushrooms go BOING. That's the whole trick."], "", Color("ffb0a0"), 0.85, 2)
	w.add_critter(5190, ["That gate wants something heavy on its button. You are not heavy. No offence. KICK my crate over.", "Kick the crate. Not me. The crate."], "The gate is still grumpy. Some things never change.", Color("f2c26b"), 1.1, 1)
	w.add_critter(6120, ["Hollow floor ahead. Not that I ever curled up, jumped and SLAMMED on it. That would be irresponsible."], "", Color("b9a2f2"), 0.9, 3)
	w.add_critter(7170, ["Long way down. Looks fast. I'd roll. I'd boost. I'd scream a bit."], "", Color("8fd6c0"), 1.0, 2)
	w.add_critter(10150, ["There's the bell. Give it a bonk. The sun hates it. That's the point."], "Ha! Look at its face. Worth it.", Color("ffb0a0"), 1.2, 1)

	w.add_toy("ball", Vector2(5290, 340))
	w.add_toy("crate", Vector2(5520, 330))
	w.add_plate(5905)
	w.add_gate(6000)
	for i in 6:
		w.add_crumble(Vector2(6325 + i * 50, 405))
	w.add_bell(10420)
	w.add_snoozle(Vector2(4800, 240))
	w.add_snoozle(Vector2(6565, 630))
	w.add_snoozle(Vector2(7150, -140))

	# Sunseeds.
	w.seed_ground(260, 560, 60)
	w.seed_line(Vector2(660, 455), Vector2(740, 455), 3)
	w.seed_ground(820, 1010, 64)
	w.seed_arc(Vector2(1150, 500), Vector2(1235, 250), Vector2(1330, 380), 5)
	w.seed_ground(1380, 1620, 80)
	w.seed_ground(1780, 3060, 106)
	w.seed_arc(Vector2(3225, 700), Vector2(3540, 606), Vector2(3840, 730), 7)
	w.seed_ground(3740, 4120, 76)
	for base in [Vector2(4225, 860), Vector2(4575, 700), Vector2(4925, 540)]:
		w.seed_line(base + Vector2(0, -110), base + Vector2(40, -290), 3)
		w.seed_line(base + Vector2(140, -205), base + Vector2(300, -205), 3)
	w.seed_line(Vector2(4740, 205), Vector2(4860, 205), 3)
	w.seed_ground(5130, 5980, 94)
	w.seed_ground(6080, 6280, 66)
	for row in 2:
		w.seed_line(Vector2(6345, 520 + row * 60), Vector2(6555, 520 + row * 60), 4)
	w.seed_ground(6640, 6840, 66)
	w.seed_line(Vector2(6900, 250), Vector2(6950, 20), 4)
	w.seed_ground(7060, 7280, 72)
	w.seed_line(Vector2(7090, -178), Vector2(7210, -178), 2)
	w.seed_arc(Vector2(9330, 690), Vector2(9650, 605), Vector2(9960, 650), 6)
	w.seed_ground(7420, 9180, 110)
	w.seed_ground(10040, 10270, 76)
