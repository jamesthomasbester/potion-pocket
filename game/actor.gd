extends Node2D
# One character in the shop, drawn from its 4x4 pose sheet (columns face the
# four travel directions; rows are idle, walk, pickup and work). The node sits
# on the character's feet so the shop's y-sort layers it with the furniture.

var sheet: Texture2D
var w := 80.0
var dir := 0
var action := "idle"
var phase := 0.0
var clock := 0.0

func _process(dt):
	clock += dt
	queue_redraw()

func pose_row() -> int:
	match action:
		"walk": return 1 if int(floor(clock*6.5+phase))%2==0 else 0
		"pickup": return 2
		"work": return 3 if int(floor(clock*3.4+phase))%2==0 else 0
	return 0

func _draw():
	if sheet == null: return
	draw_set_transform(Vector2(0,-3),0,Vector2(1,.25))
	draw_circle(Vector2.ZERO,w*.5,Color(0.2,0.1,0.15,.22))
	draw_set_transform(Vector2.ZERO)
	var bob:=absf(sin(clock*9+phase))*2.0 if action=="walk" else sin(clock*5+phase)*1.5 if action=="work" else 0.0
	var row:=pose_row()
	var sw:=w*1.8*(1.02 if action=="work" and row==3 else 1.0)
	var sh:=w*1.36*1.8
	draw_texture_rect_region(sheet,Rect2(Vector2(-sw/2,-sh-bob),Vector2(sw,sh)),Rect2(Vector2(dir*256,row*256),Vector2(256,256)))

# Screen-space box around the drawn character, for tap tests.
func hit_rect() -> Rect2:
	return Rect2(Vector2(-w*.55,-w*2.0),Vector2(w*1.1,w*2.0))
