class_name GameConfig
extends RefCounted

## Gameplay coordinates stay independent from window and display dimensions.
const LOGICAL_SIZE := Vector2(720.0, 1280.0)
const PHYSICS_STEP := 1.0 / 60.0
const BALL_RADIUS := 14.0
const TOUCH_RADIUS := 72.0
const DEAD_ZONE := 12.0
const MAX_DRAG := 180.0
const MAX_SPEED := 1000.0
const DECELERATION := 500.0
const RESTITUTION := 0.78
const STOP_SPEED := 12.0
const STOP_CONFIRM_TIME := 0.12
const CAPTURE_RADIUS := 22.0
const CAPTURE_SPEED := 150.0
const CAPTURE_TIME := 0.7
const RETURN_TIME := 0.35
const WORLD_SCALE := 0.01
const GRAVITY_3D := 9.8
const RECORD_PATH_3D := "user://record_3d.json"

const BACKGROUND := Color("101827")
const FIELD := Color("183e35")
const FOREGROUND := Color("f3f6fa")
const ACCENT := Color("50d9d0")
const WARNING := Color("f7a546")
