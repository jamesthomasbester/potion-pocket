extends Node2D
# Shared by the shop and garden scenes: the characters' timers and bounces,
# particles and floating numbers, and the badges and bars drawn on Overlay.
const Art = preload("res://game/art_catalog.gd")
const Actor = preload("res://game/actor.gd")

var model
var selected := ""
var clock := 0.0
var font := ThemeDB.fallback_font
var coin_tex: Texture2D = preload("res://game/art/ui/coin.png")
var sheets := {}
var particles: Array = []
var floaters: Array = []
var actor_timers := {}
var bounce := {}
var pulse := 0.0
var effect := ""
var last_sale_fx := -10.0
# Badges and bars draw larger than the scene, which is shown scaled down.
var ui_scale := 1.0
@onready var props: Node2D = $Props
@onready var overlay: Node2D = $Overlay

func _ready():
	for name in ["owner","brewer","cashier","gardener","customer0","customer1","departing"]:
		sheets[name]=load("res://game/art/animations/"+name+".png")
	overlay.draw.connect(draw_overlay)

func add_actor(sheet:String,w:float):
	var a=Actor.new()
	a.sheet=sheets[sheet]
	a.w=w
	a.phase=randf()*3
	props.add_child(a)
	return a

func actor_action(name:String,working:=false) -> String:
	if float(actor_timers.get(name,0.0))>0: return "pickup"
	return "work" if working else "idle"

func direction(delta:Vector2) -> int:
	if delta.y>=0: return 0 if delta.x<0 else 1
	return 2 if delta.x<0 else 3

# Advances timers, bounces, particles and floaters; scenes call this first.
func step_effects(dt:float):
	clock+=dt
	pulse=maxf(0,pulse-dt)
	for key in actor_timers.keys(): actor_timers[key]=maxf(0,float(actor_timers[key])-dt)
	for k in bounce.keys(): bounce[k]=maxf(0,bounce[k]-dt*2.6)
	for q in particles:
		q.p+=q.v*dt
		q.v.y+=q.g*dt
		q.v*=1.0-q.drag*dt
		q.life-=dt
	particles=particles.filter(func(q):return q.life>0)
	for f in floaters: f.t+=dt
	floaters=floaters.filter(func(f):return f.t<1.3)
	overlay.queue_redraw()

func spray(at:Vector2,count:int,kind:String,color:Color,speed:=160.0,up:=-120.0,g:=320.0,life:=0.9):
	for i in range(count):
		var dir=Vector2.from_angle(randf_range(-PI,0))*randf_range(.35,1)*speed+Vector2(0,up)
		particles.append({"p":at+Vector2(randf_range(-14,14),randf_range(-6,6)),"v":dir,"g":g,"drag":1.2,"life":life*randf_range(.7,1.1),"max":life,"kind":kind,"color":color,"r":randf_range(3,6)*(1.6 if kind=="leaf" else 1.0),"spin":randf_range(-6,6)})

# A coin floater that merges fast checkouts into one rising total.
func sale_floater(at:Vector2,kind:String):
	var amount=model.price(1 if kind=="dream_sale" else 0)
	if clock-last_sale_fx<.35 and not floaters.is_empty() and floaters.back().has("amount"):
		var f=floaters.back()
		f.amount+=amount
		f.text="+"+model.short(f.amount)
		f.t=minf(f.t,.2)
	else:
		floaters.append({"p":at-Vector2(20,30),"t":0.0,"amount":amount,"text":"+"+model.short(amount),"dream":kind=="dream_sale","coin":true})
	last_sale_fx=clock

func draw_overlay():
	pass

func text(o:CanvasItem,p:Vector2,s:String,n:=16,c:=Color("2b1a3d")):
	o.draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,n,c)

func badge(o:CanvasItem,p:Vector2,id:String):
	var on:=id==selected
	var label:="Lv. %d" % model.level(id)
	var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+20
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("7d52c9") if on else Color("fff3df")
	st.border_color=Color("4a2a7a") if on else Color("6b3f24")
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	var r:=Rect2(-Vector2(w/2,12),Vector2(w,25))
	o.draw_set_transform(p,0,Vector2.ONE*ui_scale)
	o.draw_style_box(st,r)
	text(o,r.position+Vector2(10,18),label,15,Color("fff3df") if on else Color("2b1a3d"))
	o.draw_set_transform(Vector2.ZERO)

# A titled progress bar; p is its top-left corner at scale 1, and it grows
# about its top centre.
func pill(o:CanvasItem,p:Vector2,title:String,progress:float,w:=110.0,fill:=Color("8a5cd6")):
	o.draw_set_transform(p+Vector2(w/2,0),0,Vector2.ONE*ui_scale)
	p=Vector2(-w/2,0)
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("fff3df")
	st.border_color=Color("6b3f24")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	o.draw_style_box(st,Rect2(p,Vector2(w,44)))
	text(o,p+Vector2(11,19),title,14)
	var bar:=StyleBoxFlat.new()
	bar.bg_color=Color("e6d9f2")
	bar.set_corner_radius_all(6)
	o.draw_style_box(bar,Rect2(p+Vector2(8,26),Vector2(w-16,10)))
	bar=bar.duplicate()
	bar.bg_color=fill
	o.draw_style_box(bar,Rect2(p+Vector2(8,26),Vector2(maxf(3,(w-16)*clampf(progress,0,1)),10)))
	o.draw_set_transform(Vector2.ZERO)

func twinkle(o:CanvasItem,p:Vector2,r:float,c:Color):
	o.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r*.28,-r*.28),p+Vector2(r,0),p+Vector2(r*.28,r*.28),p+Vector2(0,r),p+Vector2(-r*.28,r*.28),p+Vector2(-r,0),p+Vector2(-r*.28,-r*.28)]),c)

func glints(o:CanvasItem,center:Vector2,spread:Vector2,seed:float):
	for i in range(3):
		var t=fmod(clock*.8+i*.37+seed,1.0)
		var a=sin(t*PI)
		twinkle(o,center+Vector2(sin(i*2.1+seed)*spread.x,cos(i*1.7+seed)*spread.y),3+a*5,Color(1,.96,.7,a))

func draw_effects(o:CanvasItem):
	for q in particles:
		var a=clampf(q.life/q.max*1.6,0,1)
		match q.kind:
			"coin": o.draw_texture_rect(coin_tex,Rect2(q.p-Vector2(10,10),Vector2(20,20)),false,Color(1,1,1,a))
			"star": twinkle(o,q.p,q.r+2,Color(q.color,a))
			"leaf":
				var d=Vector2.from_angle(q.life*q.spin)*q.r*1.4
				o.draw_colored_polygon(PackedVector2Array([q.p-d,q.p+d.orthogonal()*.45,q.p+d,q.p-d.orthogonal()*.45]),Color(q.color,a))
			_: o.draw_circle(q.p,q.r*(.5+a*.5),Color(q.color,a))
	for f in floaters:
		var e=1-pow(1-minf(f.t/1.3,1),3)
		var p=f.p-Vector2(0,e*70)
		var a=clampf((1.3-f.t)*2.5,0,1)
		var s=26+int(10*maxf(0,.25-f.t)/.25)
		var c=Color("7b3fd1") if f.dream else Color("2f7d4f")
		if not f.get("coin",true): s+=10
		o.draw_string_outline(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,6,Color(1,1,1,a))
		o.draw_string(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,Color(c,a))
		var w=font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s).x
		if f.get("coin",true): o.draw_texture_rect(coin_tex,Rect2(p+Vector2(w+4,-s*.85),Vector2(s*.9,s*.9)),false,Color(1,1,1,a))
