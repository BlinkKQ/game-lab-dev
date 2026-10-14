class_name GolfCourses
extends RefCounted

## Original map data from GDD 0.2. Walls are solid rectangles; bounds mark
## the inner surfaces of the four external walls.
const ALL: Array = [
	{
		"name": "Bosque Sereno",
		"start": Vector2(360.0, 990.0),
		"hole": Vector2(360.0, 260.0),
		"bounds": Rect2(64.0, 200.0, 592.0, 900.0),
		"walls": [],
		"hazard": Rect2(),
	},
	{
		"name": "Terraços do Sol",
		"start": Vector2(260.0, 990.0),
		"hole": Vector2(260.0, 280.0),
		"bounds": Rect2(64.0, 200.0, 592.0, 900.0),
		"walls": [Rect2(64.0, 550.0, 366.0, 28.0)],
		"hazard": Rect2(),
	},
	{
		"name": "Travessia Azul",
		"start": Vector2(360.0, 990.0),
		"hole": Vector2(360.0, 280.0),
		"bounds": Rect2(64.0, 200.0, 592.0, 900.0),
		"walls": [Rect2(248.0, 650.0, 224.0, 28.0), Rect2(64.0, 360.0, 136.0, 28.0)],
		"hazard": Rect2(520.0, 460.0, 136.0, 180.0),
	},
]
