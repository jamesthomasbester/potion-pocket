extends Control
const Art = preload("res://game/art_catalog.gd")
var model
var garden := false
var clock := 0.0
var redraw_clock := 0.0
var pulse := 0.0
var effect := ""
var customers: Array = []
var departures: Array = []
var next_customer := 0
var textures := {}
var character_sheets := {}
var actor_timers := {}
var particles: Array = []
var floaters: Array = []
var bounce := {}
var coin_tex: Texture2D
var tufts: Array = []
var selected := "cauldron"
var view_offset := Vector2.ZERO
var view_scale := 1.0
var view_xform := Transform2D.IDENTITY
var last_sale_fx := -10.0
const INK = Color("191b43")
var font = ThemeDB.fallback_font
# One oblique grid shared by the floor, walls and every prop, matched to the
# sprites' own long (U) and depth (V) edges. Scene space is 540x660.
const U = Vector2(52,18)
const V = Vector2(-34,32)
# The shop room is drawn at SS of the shared grid so the whole room fits on screen.
const SS = 0.86
const SU = Vector2(44.72,15.48)
const SV = Vector2(-29.24,27.52)
const SHOP_ORIGIN = Vector2(178,222)
const WALL_H = 190.0
const SHOP_FRAME = Rect2(0,-4,540,570)
const GARDEN_ORIGIN = Vector2(430,205)
const ROOM_U = 7.8
const ROOM_V = 5.6
const DOOR = Vector2(3.7,5.6)
const DOOR_L = 2.9
const DOOR_R = 4.5
# Queue spots: along the counter's front, then back out through the door.
const QUEUE = [Vector2(5.9,4.8),Vector2(4.8,5.05),Vector2(3.7,6.3),Vector2(3.7,7.3),Vector2(3.7,8.3),Vector2(3.7,9.3),Vector2(3.7,10.3),Vector2(3.7,11.3)]
# Garden bed slots in purchase order: two either side of the lane, then down the right.
const GARDEN_BEDS = [Vector2(-3.1,2.4),Vector2(2.3,5.4),Vector2(2.3,2.4),Vector2(2.3,8.4),Vector2(-2.9,5.3),Vector2(2.3,11.4)]
const BED_W = 180.0
const VISITOR = Vector2(7.1,4.95)
const SPROUT = [["4a9a3f","78c55a"],["3f7f3a","5ea452"],["9c3d2c","d8643f"],["2f7f8a","6cc0c8"],["3f7f3a","5ea452"]]
const STONE = Color("eadfc8")
# One outdoor look per branch, in economy BRANCHES order: ground, tufts and a scenery touch.
const THEMES = [
	{"ground":"a9d675","tuft":"8cc05f","extra":""},
	{"ground":"eedcae","tuft":"b9b46e","extra":"sea"},
	{"ground":"eef3f8","tuft":"c3d1e2","extra":"snow"},
	{"ground":"6f9468","tuft":"587a55","extra":"lanterns"},
	{"ground":"b9d86c","tuft":"97b94f","extra":"sunflowers"},
	{"ground":"b4bfe3","tuft":"929fcc","extra":"stars"}]

func iso(u:float,v:float) -> Vector2: return SHOP_ORIGIN+SU*u+SV*v
func giso(u:float,v:float) -> Vector2: return GARDEN_ORIGIN+U*u+V*v

func _ready():
	for name in ["cauldron","shelf","counter","leaves","flowers","bed","bush","plant","gate","owner","brewer","cashier","gardener","customer0","customer1","departing","energy","dream"]:
		var path="res://game/art/"+name+".png"
		if ResourceLoader.exists(path): textures[name]=load(path)
	for family in Art.FAMILIES:
		for tier in range(1,4):
			var name="%s_t%d" % [family,tier]
			textures[name]=load("res://game/art/"+name+".png")
	for name in ["owner","brewer","cashier","gardener","customer0","customer1","departing"]:
		var path="res://game/art/animations/"+name+".png"
		if ResourceLoader.exists(path): character_sheets[name]=load(path)
	coin_tex=load("res://game/art/coin.svg")
	# Fixed grass tufts so the lawn does not shimmer between frames.
	var rng:=RandomNumberGenerator.new()
	rng.seed=7
	for i in range(70): tufts.append(Vector2(rng.randf_range(0,540),rng.randf_range(0,660)))

func _process(dt):
	clock+=dt
	pulse=maxf(0,pulse-dt)
	if model:
		while customers.size()<int(model.s.queue):
			customers.append({"g":DOOR+Vector2(0,2.2),"path":[DOOR-Vector2(0,0.8)],"variant":next_customer%3,"dir":2,"moving":true,"hold":0.0})
			next_customer+=1
		while customers.size()>int(model.s.queue): leave_customer()
		for i in range(customers.size()): walk(customers[i],QUEUE[mini(i,QUEUE.size()-1)],dt)
		for c in departures: walk(c,c.path.back() if not c.path.is_empty() else c.g,dt)
		departures=departures.filter(func(c):return not c.path.is_empty())
	for key in actor_timers.keys(): actor_timers[key]=maxf(0,float(actor_timers[key])-dt)
	for k in bounce.keys(): bounce[k]=maxf(0,bounce[k]-dt*2.6)
	for q in particles:
		q.p+=q.v*dt
		q.v.y+=q.g*dt
		q.v*=1.0-q.drag*dt
		q.life-=dt
	particles=particles.filter(func(q):return q.life>0)
	for f in floaters:
		f.t+=dt
	floaters=floaters.filter(func(f):return f.t<1.3)
	redraw_clock+=dt
	if redraw_clock>=1.0/30.0:
		redraw_clock=0
		queue_redraw()

# Customers follow waypoints in grid space, then settle on their queue spot.
func walk(c:Dictionary,spot:Vector2,dt:float):
	if float(c.get("hold",0.0))>0:
		c.hold=maxf(0,float(c.hold)-dt)
		c.moving=false
		return
	var from=iso(c.g.x,c.g.y)
	var step:=dt*2.4
	while step>0:
		var target:Vector2=c.path[0] if not c.path.is_empty() else spot
		var d:float=c.g.distance_to(target)
		if d<=step:
			c.g=target
			step-=d
			if c.path.is_empty(): break
			c.path.pop_front()
		else:
			c.g=c.g.move_toward(target,step)
			break
	var delta=iso(c.g.x,c.g.y)-from
	c.moving=delta.length()>0.1
	if c.moving: c.dir=direction(delta)

func direction(delta:Vector2) -> int:
	if delta.y>=0: return 0 if delta.x<0 else 1
	return 2 if delta.x<0 else 3

func leave_customer():
	if customers.is_empty(): return
	var c=customers.pop_front()
	c.path=[DOOR-Vector2(0,0.8),DOOR+Vector2(0,2.6)]
	c.hold=.58
	c.moving=false
	departures.append(c)

func spray(at:Vector2,count:int,kind:String,color:Color,speed:=160.0,up:=-120.0,g:=320.0,life:=0.9):
	for i in range(count):
		var dir=Vector2.from_angle(randf_range(-PI,0))*randf_range(.35,1)*speed+Vector2(0,up)
		particles.append({"p":at+Vector2(randf_range(-14,14),randf_range(-6,6)),"v":dir,"g":g,"drag":1.2,"life":life*randf_range(.7,1.1),"max":life,"kind":kind,"color":color,"r":randf_range(3,6)*(1.6 if kind=="leaf" else 1.0),"spin":randf_range(-6,6)})

func bed_center(i:int) -> Vector2:
	if garden: return giso(GARDEN_BEDS[i].x,GARDEN_BEDS[i].y)
	return Vector2(318,58) if i==0 else Vector2(458,96)

func station_pos(id:String) -> Vector2:
	match id:
		"cauldron": return iso(1.45,1.75)
		"shelf": return iso(5.3,.9)
		"counter": return iso(6.3,3.8)
	return bed_center(0)

# Which station a tap in this control's local space lands on, if any.
func station_at(p:Vector2) -> String:
	var q=(p-view_offset)/view_scale
	if not garden and not model.s.visitor.is_empty() and Rect2(iso(VISITOR.x,VISITOR.y)-Vector2(40,150),Vector2(80,156)).has_point(q): return "visitor"
	if garden:
		var n:int=model.s.plots.size()
		if n<GARDEN_BEDS.size() and q.distance_to(bed_center(n))<85: return "plot"
		for i in range(n):
			if q.distance_to(bed_center(i))<95: return "garden"
		return ""
	for id in ["counter","shelf","cauldron"]:
		var half:Vector2={"cauldron":Vector2(75,150),"shelf":Vector2(80,165),"counter":Vector2(105,150)}[id]*SS
		var b=station_pos(id)
		if Rect2(b-half,Vector2(half.x*2,half.y+12)).has_point(q): return id
	return ""

func badge(p:Vector2,id:String):
	var on=id==selected
	var label="Lv. %d" % model.level(id)
	var w=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+18
	var st=StyleBoxFlat.new()
	st.bg_color=Color("7d52c9") if on else Color("fff7eb")
	st.border_color=Color("5b3a9e") if on else Color("d8c4b2")
	st.set_border_width_all(2)
	st.set_corner_radius_all(11)
	var r=Rect2(p-Vector2(w/2,11),Vector2(w,24))
	draw_style_box(st,r)
	text(r.position+Vector2(9,17),label,14,Color("fff7eb") if on else INK)

# Visual response to economy feedback; positions are in the 540x660 scene space.
func burst(kind:String):
	match kind:
		"harvest":
			actor_timers["gardener" if model.owned("gardener") else "owner"]=.7
			if garden:
				for i in range(model.s.plots.size()):
					spray(bed_center(i)-Vector2(0,30),9,"leaf",Color("8fd16a"),150,-180,300,1.0)
					bounce["bed"+str(i)]=1.0
		"brew":
			actor_timers["brewer" if model.owned("brewer") else "owner"]=.55
			if not garden:
				spray(station_pos("cauldron")-Vector2(0,85),12,"dot",Color("b58af1"),120,-150,380,.8)
				bounce["cauldron"]=1.0
		"stock":
			actor_timers["brewer" if model.owned("brewer") else "owner"]=.75
			if not garden:
				spray(station_pos("shelf")-Vector2(0,60),8,"star",Color("fff1af"),110,-60,60,.8)
				bounce["shelf"]=1.0
				bounce["cauldron"]=.6
		"sale","dream_sale":
			actor_timers["cashier" if model.owned("cashier") else "owner"]=.5
			var at=station_pos("counter")-Vector2(25,65) if not garden else Vector2(440,60)
			var amount=model.price(1 if kind=="dream_sale" else 0)
			# Fast checkouts merge into one rising total instead of a pile of labels.
			if clock-last_sale_fx<.35 and not floaters.is_empty() and floaters.back().has("amount"):
				var f=floaters.back()
				f.amount+=amount
				f.text="+"+model.short(f.amount)
				f.t=minf(f.t,.2)
			else:
				if not garden: spray(at,7,"coin",Color.WHITE,170,-230,520,1.0)
				floaters.append({"p":at-Vector2(20,30),"t":0.0,"amount":amount,"text":"+"+model.short(amount),"dream":kind=="dream_sale","coin":true})
			last_sale_fx=clock
			if not garden: bounce["counter"]=.7
		"request","vip":
			var at=iso(VISITOR.x,VISITOR.y)-Vector2(0,110)
			spray(at,16 if kind=="vip" else 10,"coin",Color.WHITE,220,-260,520,1.1)
			spray(at,14,"star",Color("ffd765"),220,-140,140,1.0)
			floaters.append({"p":at-Vector2(30,20),"t":0.0,"text":"+"+model.short(model.last_visitor_pay),"dream":kind=="vip","coin":true})
		"level","milestone":
			var at=station_pos(selected)-Vector2(0,70)
			if garden or selected=="garden": at=bed_center(0)-Vector2(0,40)
			bounce["bed0" if selected=="garden" else selected]=1.0
			if selected=="garden": bounce["bed1"]=1.0
			if kind=="milestone":
				spray(at,30,"star",Color("ffd765"),320,-160,160,1.3)
				spray(at,16,"dot",Color("b58af1"),260,-180,260,1.1)
				floaters.append({"p":at-Vector2(30,10),"t":0.0,"text":"×2!","dream":true,"coin":false})
			else:
				spray(at,10,"star",Color("fff1af"),150,-110,120,.8)
		"upgrade":
			spray(Vector2(270,300),26,"star",Color("ffd765"),300,-120,140,1.2)
			spray(Vector2(270,300),14,"dot",Color("b58af1"),260,-160,260,1.0)

func poly(points, color, outline:=false, line:=Color("b78059")):
	draw_colored_polygon(PackedVector2Array(points),color)
	if outline: draw_polyline(PackedVector2Array(points+[points[0]]),line,2,true)

func quad(a:Vector2,du:Vector2,dv:Vector2) -> Array: return [a,a+du,a+du+dv,a+dv]

func oval(p:Vector2,r:Vector2,c:Color):
	var points=[]
	for i in range(40): points.append(p+Vector2(cos(i*TAU/40)*r.x,sin(i*TAU/40)*r.y))
	poly(points,c)

func sprite(name:String,p:Vector2,w:float,tint:=Color.WHITE):
	if not textures.has(name): return
	var tex:Texture2D=textures[name]
	var h=w*tex.get_height()/tex.get_width()
	draw_texture_rect(tex,Rect2(p-Vector2(w/2,h),Vector2(w,h)),false,tint)

func sprite_bounce(name:String,p:Vector2,w:float,key:String,shear:=0.0):
	var t:float=bounce.get(key,0.0)
	var squash=sin(t*PI*3.0)*t*.12
	if not textures.has(name): return
	var tex:Texture2D=textures[name]
	var sw=w*(1+squash)
	var h=w*tex.get_height()/tex.get_width()*(1-squash)
	if shear!=0.0: draw_set_transform_matrix(view_xform*shear_at(p,shear))
	draw_texture_rect(tex,Rect2(p-Vector2(sw/2,h),Vector2(sw,h)),false)
	if shear!=0.0: draw_set_transform_matrix(view_xform)

# Vertical shear about p: verticals stay upright while the sprite's long
# edges tilt by k, so painted furniture lines up with the floor grid.
func shear_at(p:Vector2,k:float) -> Transform2D:
	return Transform2D(Vector2(1,k),Vector2(0,1),Vector2(0,-k*p.x))

func person(name:String,p:Vector2,w:=70.0,dir:=0,action:="idle",phase:=0.0):
	oval(p-Vector2(0,3),Vector2(w*.48,9),Color(0.35,0.22,0.16,.16))
	if not character_sheets.has(name):
		sprite(name,p,w)
		return
	var row=pose_row(action,phase)
	var bob:=absf(sin(clock*9+phase))*2.0 if action=="walk" else sin(clock*5+phase)*1.5 if action=="work" else 0.0
	var tex:Texture2D=character_sheets[name]
	var sw:=w*1.8*(1.02 if action=="work" and row==3 else 1.0)
	var sh:=w*1.36*1.8
	var source=Rect2(Vector2(dir*256,row*256),Vector2(256,256))
	draw_texture_rect_region(tex,Rect2(p-Vector2(sw/2,sh+bob),Vector2(sw,sh)),source)

func pose_row(action:String,phase:=0.0) -> int:
	match action:
		"walk": return 1 if int(floor(clock*6.5+phase))%2==0 else 0
		"pickup": return 2
		"work": return 3 if int(floor(clock*3.4+phase))%2==0 else 0
	return 0

func actor_action(name:String,working:=false) -> String:
	if float(actor_timers.get(name,0.0))>0: return "pickup"
	return "work" if working else "idle"

func customer_name(c:Dictionary) -> String:
	return ["customer0","customer1","departing"][int(c.variant)%3]

func customer_action(c:Dictionary) -> String:
	if float(c.get("hold",0.0))>0: return "pickup"
	if bool(c.get("moving",false)): return "walk"
	if model.s.serving and not customers.is_empty() and c==customers[0]: return "work"
	return "idle"

func text(p:Vector2,s:String,n:=18,c:=INK):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,n,c)

func pill(p:Vector2,title:String,progress:float,w:=100.0,fill:=Color("b58af1")):
	var st=StyleBoxFlat.new()
	st.bg_color=Color("fff7eb")
	st.set_corner_radius_all(14)
	st.shadow_color=Color(0.2,0.15,0.3,0.15)
	st.shadow_size=4
	st.shadow_offset=Vector2(0,2)
	draw_style_box(st,Rect2(p,Vector2(w,43)))
	text(p+Vector2(10,18),title,14)
	st=StyleBoxFlat.new();st.bg_color=Color("ded7e4");st.set_corner_radius_all(6)
	draw_style_box(st,Rect2(p+Vector2(7,25),Vector2(w-14,11)))
	st=st.duplicate();st.bg_color=fill
	draw_style_box(st,Rect2(p+Vector2(7,25),Vector2(maxf(3,(w-14)*clampf(progress,0,1)),11)))

func bubble(p:Vector2,title:String):
	var w=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+44
	var st=StyleBoxFlat.new()
	st.bg_color=Color("f1fbe9")
	st.border_color=Color("9fd17f")
	st.set_border_width_all(2)
	st.set_corner_radius_all(15)
	draw_style_box(st,Rect2(p-Vector2(w/2,0),Vector2(w,32)))
	poly([p+Vector2(-8,30),p+Vector2(8,30),p+Vector2(0,40)],Color("f1fbe9"))
	mint_leaf(p+Vector2(-w/2+19,22),p+Vector2(-w/2+25,8),5,Color("5aa64a"))
	text(p+Vector2(-w/2+33,21),title,15)

func twinkle(p:Vector2,r:float,c:Color):
	poly([p+Vector2(0,-r),p+Vector2(r*.28,-r*.28),p+Vector2(r,0),p+Vector2(r*.28,r*.28),p+Vector2(0,r),p+Vector2(-r*.28,r*.28),p+Vector2(-r,0),p+Vector2(-r*.28,-r*.28)],c)

func glints(center:Vector2,spread:Vector2,seed:float):
	for i in range(3):
		var t=fmod(clock*.8+i*.37+seed,1.0)
		var a=sin(t*PI)
		twinkle(center+Vector2(sin(i*2.1+seed)*spread.x,cos(i*1.7+seed)*spread.y),3+a*5,Color(1,.96,.7,a))

func mint_leaf(base:Vector2,tip:Vector2,width:float,c:Color):
	var axis=tip-base
	var side=axis.orthogonal().normalized()*width
	var shape=[base]
	for k in range(1,6):
		var t=k/6.0
		shape.append(base+axis*t+side*sin(t*PI)*(1.08 if k%2 else .9))
	shape.append(tip)
	for k in range(5,0,-1):
		var t=k/6.0
		shape.append(base+axis*t-side*sin(t*PI)*(1.08 if k%2 else .9))
	poly(shape,c)
	draw_polyline(PackedVector2Array(shape+[base]),c.darkened(.32),1.2,true)
	draw_line(base,base+axis*.85,c.lightened(.28),1.1,true)

# Leafy rosette: back leaves first, then the brighter front ones.
func rosette(p:Vector2,size:float,dark:Color,light:Color):
	oval(p+Vector2(0,2),Vector2(size*.8,size*.28),Color(0.25,0.15,0.08,.25))
	for k in range(5):
		var a=-PI/2+(k-2)*.55
		mint_leaf(p,p+Vector2.from_angle(a)*size*1.05,size*.32,dark)
	for k in range(4):
		var a=-PI/2+(k-1.5)*.95+.08*sin(clock*1.5+p.x)
		mint_leaf(p+Vector2(0,1),p+Vector2(0,1)+Vector2.from_angle(a)*size*.85,size*.3,light)

func blossom(p:Vector2,r:float):
	for k in range(5):
		var a=-PI/2+k*TAU/5
		var tip=p+Vector2.from_angle(a)*r
		var side=Vector2.from_angle(a+PI/2)*r*.38
		var mid=p+Vector2.from_angle(a)*r*.5
		var petal=[p,mid+side,tip,mid-side]
		poly(petal,Color("faf6ff"))
		draw_polyline(PackedVector2Array(petal+[p]),Color("b9a3e8"),1.3,true)
		draw_line(p,p+Vector2.from_angle(a)*r*.6,Color("d9c9fa"),1.6,true)
	draw_circle(p,r*.26,Color("f2c94c"))
	draw_circle(p-Vector2(1,1),r*.1,Color("fff2b0"))

# Seedlings are vector rosettes; grown plants switch to the tiered sprites.
func crop_plant(p:Vector2,crop:int,stage:float,size:float):
	var s=size*(.35+.65*clampf(stage,0,1))
	rosette(p,s*(.9 if crop in [1,4] else 1.0),Color(SPROUT[crop][0]),Color(SPROUT[crop][1]))

# Soil corners (left, back, right, front) in each bed sprite's pixels, so
# plants root inside the box instead of on its rim.
const BED_SOIL = {"bed_t1":[Vector2(66,124),Vector2(141,58),Vector2(350,152),Vector2(259,213)],"bed_t2":[Vector2(68,136),Vector2(154,69),Vector2(354,162),Vector2(258,225)],"bed_t3":[Vector2(71,152),Vector2(183,77),Vector2(360,175),Vector2(252,239)]}
# The bed art is painted steeper than the U axis; this shear levels its long side.
const BED_SHEAR = -0.11
const COUNTER_SHEAR = 0.1

# A raised bed drawn from its centre, with a 3x2 grid of plants in the soil.
func garden_bed(center:Vector2,w:float,plot:Dictionary,key:String):
	var name:String=Art.name_for("bed",model.level("garden"))
	var tex:Texture2D=textures[name]
	var sc=w/tex.get_width()
	# Place the sprite so its soil centre lands on the bed's grid centre.
	var mid:=Vector2.ZERO
	for q in BED_SOIL[name]: mid+=q/4.0
	var foot=center-(mid-Vector2(tex.get_width()/2.0,tex.get_height()))*sc
	sprite_bounce(name,foot,w,key,BED_SHEAR)
	var corners=[]
	for q in BED_SOIL[name]:
		var at=foot+(q-Vector2(tex.get_width()/2.0,tex.get_height()))*sc
		corners.append(at+Vector2(0,BED_SHEAR*(at.x-foot.x)))
	var stage=plot.progress/model.grow_time(int(plot.crop))
	# Back row first so front plants overlap the ones behind them.
	for v in [.3,.72]:
		for u in [.2,.5,.8]:
			var at=soil_point(corners,u,v)
			if stage<.18: crop_plant(at,int(plot.crop),stage,w*.12)
			else: sprite(Art.name_for(Art.CROPS[int(plot.crop)],model.level("garden")),at,w*.14*(.35+.65*stage))
	if stage>=1: glints(soil_point(corners,.5,.4)-Vector2(0,w*.06),Vector2(w*.26,w*.05),key.length()*.3)

# u runs along the long side, v from the back edge to the front edge.
func soil_point(c:Array,u:float,v:float) -> Vector2:
	return c[1].lerp(c[2],u).lerp(c[0].lerp(c[3],u),v)

func wall(a:Vector2,b:Vector2,h:float,face:=Color("ecd8c3"),low:=Color("d8c4b2"),trim:=Color("c98c62"),motif:="plain"):
	poly([a,b,b-Vector2(0,h),a-Vector2(0,h)],face,true)
	poly([a,b,b-Vector2(0,h*.29),a-Vector2(0,h*.29)],low)
	draw_line(a-Vector2(0,h*.29),b-Vector2(0,h*.29),Color("f9e9d3"),2,true)
	draw_line(a-Vector2(0,h),b-Vector2(0,h),trim.darkened(.35),18,true)
	draw_line(a-Vector2(0,h+3),b-Vector2(0,h+3),trim,11,true)
	if motif=="panel":
		for t in [.25,.65]:
			var q=a.lerp(b,t)-Vector2(0,h*.62)
			draw_line(q-Vector2(0,24),q+Vector2(0,24),trim,2,true)
	elif motif=="vine":
		for t in [.2,.5,.8]:
			var q=a.lerp(b,t)-Vector2(0,h*.24)
			draw_line(q,q-Vector2(0,h*.46),Color("579162"),2,true)
			for k in range(3): mint_leaf(q-Vector2(0,k*18+7),q+Vector2(10 if k%2 else -10,-k*18-17),4,Color("78a76d"))
	for p in [a,b]: post(p,h)

func post(p:Vector2,h:float):
	draw_line(p,p-Vector2(0,h+9),Color("966144"),19,true)
	draw_line(p-Vector2(3,0),p-Vector2(3,h+9),Color("bd8159"),12,true)

func theme() -> Dictionary:
	return THEMES[int(model.s.prestige.branches) % THEMES.size()]

func lawn():
	var th:=theme()
	draw_rect(Rect2(Vector2(-400,-300),Vector2(1400,1300)),Color(th.ground))
	var tuft:=Color(th.tuft)
	for t in tufts:
		draw_line(t,t+Vector2(-3,-7),tuft,2,true)
		draw_line(t+Vector2(3,0),t+Vector2(4,-8),tuft,2,true)
	match th.extra:
		"sea":
			# A strip of sea along the far edge, with drifting wave crests and shells.
			poly([Vector2(-400,-300),Vector2(1000,-300),Vector2(1000,34),Vector2(-400,34)],Color("7cc6d6"))
			poly([Vector2(-400,34),Vector2(1000,34),Vector2(1000,44),Vector2(-400,44)],Color("f6efd9"))
			for k in range(10):
				var x=fmod(k*64.0+clock*12.0,640.0)-50
				draw_arc(Vector2(x,18+(k%2)*8),12,PI*1.1,PI*1.9,8,Color("e9f7fa"),3,true)
			for i in range(0,tufts.size(),6): oval(tufts[i],Vector2(7,4),Color("f2b9a6"))
		"snow":
			for i in range(0,tufts.size(),2):
				var q:Vector2=tufts[i]
				var y=fmod(q.y+clock*28.0,700.0)-20
				var at=Vector2(q.x+sin(clock+i)*8,y)
				draw_circle(at,4.2,Color("b9c9de"))
				draw_circle(at,3.2,Color.WHITE)
		"lanterns":
			for row in [[Vector2(-10,30),Vector2(560,4)],[Vector2(-10,640),Vector2(560,610)]]:
				var a:Vector2=row[0]
				var b:Vector2=row[1]
				draw_line(a,b,Color("3e3a52"),2,true)
				for k in range(1,9):
					var p=a.lerp(b,k/9.0)+Vector2(0,10)
					draw_circle(p,18,Color(1,.78,.35,.25))
					oval(p,Vector2(9,12),Color("f4a640") if k%2 else Color("e4574a"))
			for i in range(0,tufts.size(),7):
				if sin(clock*2+i)>.2: draw_circle(tufts[i]+Vector2(sin(clock+i)*6,-14),2,Color("fff4b0"))
		"sunflowers":
			for i in range(0,tufts.size(),4):
				var q:Vector2=tufts[i]
				draw_line(q,q-Vector2(0,34),Color("5e9a3c"),4,true)
				mint_leaf(q-Vector2(0,12),q+Vector2(12,-22),5,Color("6fae45"))
				for k in range(10): draw_circle(q-Vector2(0,40)+Vector2.from_angle(k*TAU/10)*9,5.5,Color("f6c531"))
				draw_circle(q-Vector2(0,40),7,Color("8a5a2b"))
		"stars":
			for i in range(0,tufts.size(),4):
				var glow=.5+.5*sin(clock*1.6+i*1.7)
				twinkle(tufts[i]+Vector2(0,-6),6+glow*5,Color(1,.96,.75,.5+glow*.5))

func stone(c:Vector2,o:Vector2):
	var a=c-U*.42-V*.42
	var pts=quad(a,U*.84,V*.84)
	poly(pts,STONE,true,Color("d2c2a3"))
	draw_line(pts[0]+Vector2(3,2),pts[1]+Vector2(-3,2),Color("f7f0e2"),2,true)

func picket_fence(a:Vector2,b:Vector2,n:int):
	draw_line(a-Vector2(0,14),b-Vector2(0,14),Color("e3e0ea"),5,true)
	draw_line(a-Vector2(0,30),b-Vector2(0,30),Color("e3e0ea"),5,true)
	for i in range(n+1):
		var p=a.lerp(b,float(i)/n)
		poly([p+Vector2(-6,0),p+Vector2(6,0),p+Vector2(6,-38),p+Vector2(0,-46),p+Vector2(-6,-38)],Color("fbfaff"),true,Color("c9c4d6"))

func padlock(p:Vector2):
	draw_arc(p-Vector2(0,14),11,PI,TAU,18,Color("6f6d78"),5,true)
	var st=StyleBoxFlat.new()
	st.bg_color=Color("7d7b86")
	st.set_corner_radius_all(6)
	draw_style_box(st,Rect2(p+Vector2(-17,-15),Vector2(34,28)))
	draw_circle(p,4,Color("4e4c57"))

func dashed(points:Array,c:Color):
	for i in range(points.size()):
		var a:Vector2=points[i]
		var b:Vector2=points[(i+1)%points.size()]
		var n=int(a.distance_to(b)/14)
		for k in range(n):
			if k%2==0: draw_line(a.lerp(b,float(k)/n),a.lerp(b,float(k+1)/n),c,4,true)

func draw_garden():
	lawn()
	var wall_style:Dictionary=Art.WALLS[int(model.s.decor.wall)]
	# House front: one wall plane along U with an arched purple door.
	var h0=giso(-1.9,0)
	var h1=giso(9,0)
	var wall_h=175.0
	poly([h0,h1,h1-Vector2(0,wall_h),h0-Vector2(0,wall_h)],Color(wall_style.face),true,Color(wall_style.trim))
	poly([h0,h1,h1-Vector2(0,26),h0-Vector2(0,26)],Color(wall_style.low))
	var back=-V*2.6-Vector2(0,40)
	var t0=h0-Vector2(0,wall_h)
	var t1=h1-Vector2(0,wall_h)
	poly([t0-Vector2(8,0),t1,t1+back,t0+back-Vector2(8,0)],Color("e0835a"),true,Color("b65f3e"))
	for k in range(1,4):
		var f=k/4.0
		draw_line(t0.lerp(t0+back,f),t1.lerp(t1+back,f),Color("c96b46"),2,true)
	draw_line(t0-Vector2(10,2),t1-Vector2(0,2),Color("b65f3e"),6,true)
	var d0=giso(-.6,0)
	var d1=giso(.6,0)
	var arch=[]
	var mid=(d0+d1)/2-Vector2(0,108)
	for k in range(13):
		var t=PI*k/12.0
		arch.append(mid+(d1-d0)/2*cos(t)-Vector2(0,30*sin(t)))
	var door=[d0,d1]+arch
	poly(door,Color("8457cf"),true,Color("5b3a9e"))
	for k in [.33,.66]: draw_line(d0.lerp(d1,k),d0.lerp(d1,k)-Vector2(0,118),Color("7044bd"),2,true)
	draw_circle(d0.lerp(d1,.78)-Vector2(0,55),4,Color("f2c94c"))
	poly(quad(d0-V*.15-U*.1,(d1-d0)*1.18,V*.45),Color("d7cbb6"),true,Color("bca98c"))
	var w0=giso(1.6,0)-Vector2(0,48)
	poly(quad(w0-Vector2(0,72),U*1.4,Vector2(0,72)),Color("fdfaf2"),true,Color("c9b9a4"))
	poly(quad(w0-Vector2(-6,64),U*1.4-Vector2(12,4),Vector2(0,58)),Color("3c3d68"))
	oval(w0+U*.7-Vector2(0,20),Vector2(14,10),Color("23244a"))
	poly(quad(w0-Vector2(4,-2),U*1.4+Vector2(8,4),Vector2(0,8)),Color("e9dccb"),true,Color("c9b9a4"))
	# Fence along the back-left edge and lower right.
	picket_fence(giso(-5.4,-3),giso(-5.4,9.5),14)
	# A stone lane from the door down between the bed columns.
	for k in range(13):
		for side in [-.5,.5]: stone(giso(side,k+.6),Vector2.ZERO)
	sprite(Art.name_for("bush",model.level("garden")),Vector2(70,150),150)
	sprite(Art.name_for("bush",model.level("garden")),Vector2(-10,520),120)
	# Props by the house.
	draw_barrel(giso(-2.3,.4))
	draw_crate(giso(-1.25,.55),38)
	draw_watering_can(giso(-5.8,0.4))
	# The next purchasable plot: dashed outline, padlock and its price.
	var count:int=model.s.plots.size()
	if count<GARDEN_BEDS.size():
		var lc=bed_center(count)
		var lp=quad(lc-U*1.05-V*.75,U*2.1,V*1.5)
		poly(lp,Color(1,1,1,.2))
		dashed(lp,Color(1,1,1,.9))
		padlock(lc-Vector2(0,6))
		var cost="%s" % model.short(model.plot_cost())
		var w=font.get_string_size(cost,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+34
		var st=StyleBoxFlat.new()
		st.bg_color=Color("fff7eb")
		st.set_corner_radius_all(12)
		draw_style_box(st,Rect2(lc+Vector2(-w/2,16),Vector2(w,26)))
		draw_texture_rect(coin_tex,Rect2(lc+Vector2(-w/2+6,19),Vector2(20,20)),false)
		text(lc+Vector2(-w/2+29,35),cost,16)
	var hired=model.owned("gardener")
	var order=range(count)
	order.sort_custom(func(a,b):return bed_center(a).y<bed_center(b).y)
	for i in order:
		var c=bed_center(i)
		var plot=model.s.plots[i]
		garden_bed(c,BED_W,plot,"bed"+str(i))
		var ready=plot.progress>=model.grow_time(int(plot.crop))
		sign_post(c+Vector2(-82,14),int(plot.crop))
		pill(c+Vector2(-40,26),"Ready" if ready else "Growing",plot.progress/model.grow_time(int(plot.crop)),96,Color("5fbf6a"))
		if i==0:
			if hired:
				var pip=giso(-1.0,2.15)
				person("gardener",pip,80,0,actor_action("gardener",not ready),.4)
				bubble(pip+Vector2(-24,-120),"Auto-harvest ON")
			else:
				person("owner",giso(.1,2.6),88,1,actor_action("owner",not ready),.7)
	if hired: person("owner",giso(.9,.9),80,1,actor_action("owner"))
	badge(bed_center(0)+Vector2(70,40),"garden")
	sprite(Art.name_for("bush",model.level("garden")),Vector2(520,640),140)
	picket_fence(giso(6.6,6),giso(6.6,13),8)

func sign_post(p:Vector2,crop:int):
	draw_line(p,p-Vector2(0,26),Color("8b5a3c"),5,true)
	var st=StyleBoxFlat.new()
	st.bg_color=Color("f4e2c4")
	st.border_color=Color("a9744e")
	st.set_border_width_all(2)
	st.set_corner_radius_all(5)
	draw_style_box(st,Rect2(p+Vector2(-17,-58),Vector2(34,34)))
	sprite(Art.CROPS[crop]+"_t1",p-Vector2(0,27),28)

func draw_barrel(p:Vector2):
	oval(p,Vector2(22,8),Color(0.25,0.15,0.08,.22))
	poly([p+Vector2(-20,-4),p+Vector2(20,-4),p+Vector2(23,-30),p+Vector2(20,-56),p+Vector2(-20,-56),p+Vector2(-23,-30)],Color("a9683f"),true,Color("6f4129"))
	oval(p-Vector2(0,56),Vector2(20,7),Color("c8875a"))
	for y in [-14,-44]: draw_line(p+Vector2(-21,y),p+Vector2(21,y),Color("7b7f89"),4,true)

func draw_crate(p:Vector2,s:float):
	var su=U*(s/60.0)
	var sv=V*(s/90.0)
	var h=s*.55
	var top=p-Vector2(0,h)
	poly([p-su*.5+sv*.5,p+su*.5+sv*.5,p+su*.5+sv*.5-Vector2(0,h),p-su*.5+sv*.5-Vector2(0,h)],Color("c48a57"),true,Color("7d4f2f"))
	poly([p+su*.5+sv*.5,p+su*.5-sv*.5,p+su*.5-sv*.5-Vector2(0,h),p+su*.5+sv*.5-Vector2(0,h)],Color("a9703f"),true,Color("7d4f2f"))
	poly(quad(top-su*.5-sv*.5,su,sv),Color("8a5734"),true,Color("7d4f2f"))
	draw_line(p-su*.5+sv*.5-Vector2(0,h*.5),p+su*.5+sv*.5-Vector2(0,h*.5),Color("9c6a42"),2,true)

func draw_watering_can(p:Vector2):
	oval(p,Vector2(26,8),Color(0.2,0.15,0.1,.2))
	poly([p+Vector2(-20,-2),p+Vector2(18,-2),p+Vector2(20,-40),p+Vector2(-18,-40)],Color("4a9fb2"),true,Color("2f6f80"))
	draw_line(p+Vector2(18,-12),p+Vector2(42,-38),Color("4a9fb2"),7,true)
	poly([p+Vector2(38,-44),p+Vector2(50,-36),p+Vector2(44,-30)],Color("3b8798"))
	draw_arc(p-Vector2(2,40),14,PI,TAU,14,Color("2f6f80"),5,true)

func draw_sign(p:Vector2):
	draw_line(p+Vector2(-24,0),p+Vector2(-10,-74),Color("7a4b2f"),6,true)
	draw_line(p+Vector2(24,0),p+Vector2(10,-74),Color("7a4b2f"),6,true)
	poly([p+Vector2(-26,-14),p+Vector2(26,-14),p+Vector2(16,-70),p+Vector2(-16,-70)],Color("3e4659"),true,Color("7a4b2f"))
	# Chalk flask: round body, neck and cork.
	var b=p-Vector2(0,34)
	var chalk=Color("f3efe6")
	var flask=[]
	for k in range(21):
		var t=-PI*.32+k*(PI*1.64/20)
		flask.append(b+Vector2(cos(t+PI/2)*11,sin(t+PI/2)*11))
	flask.append(b+Vector2(-4,-10))
	flask.append(b+Vector2(-4,-19))
	flask.append(b+Vector2(4,-19))
	flask.append(b+Vector2(4,-10))
	draw_polyline(PackedVector2Array(flask+[flask[0]]),chalk,2.2,true)
	draw_line(b+Vector2(-6,-21),b+Vector2(6,-21),chalk,3,true)
	draw_line(b+Vector2(-7,3),b+Vector2(7,3),Color(chalk,.6),1.6,true)

func draw_visitor():
	if model.s.visitor.is_empty(): return
	var v:Dictionary=model.s.visitor
	var p=iso(VISITOR.x,VISITOR.y)
	var vip:bool=v.kind=="vip"
	person("customer1" if vip else "customer0",p,72*SS,0,"work" if model.visitor_potion()>=0 else "idle")
	if vip:
		var c=p-Vector2(0,84)
		poly([c+Vector2(-15,8),c+Vector2(15,8),c+Vector2(18,-10),c+Vector2(8,-2),c+Vector2(0,-14),c+Vector2(-8,-2),c+Vector2(-18,-10)],Color("f2c94c"),true,Color("b9822a"))
	# Speech bubble: wanted potion (or any, for a VIP), pay multiplier, countdown ring.
	var ready:bool=model.visitor_potion()>=0
	var b=p-Vector2(0,125)+Vector2(0,sin(clock*3)*2)
	var st=StyleBoxFlat.new()
	st.bg_color=Color("fff7eb")
	st.border_color=Color("f2b632") if vip else Color("b58af1")
	st.set_border_width_all(3)
	st.set_corner_radius_all(16)
	draw_style_box(st,Rect2(b-Vector2(46,24),Vector2(92,44)))
	poly([b+Vector2(-7,19),b+Vector2(7,19),b+Vector2(0,30)],Color("fff7eb"))
	var icon=Art.name_for(Art.POTIONS[model.visitor_potion() if vip and ready else int(v.recipe)],model.level("cauldron"))
	if vip and not ready: icon="energy_t1"
	sprite(icon,b+Vector2(-22,16),26,Color.WHITE if ready else Color(1,1,1,.45))
	text(b+Vector2(-4,7),"×%d" % int(model.cfg.visitors.vip_pay if vip else model.cfg.visitors.request_pay),20,Color("b9822a") if vip else Color("7b3fd1"))
	var left:float=clampf(v.left/float(model.cfg.visitors.wait),0,1)
	draw_arc(b+Vector2(36,-14),9,-PI/2,-PI/2+TAU*left,20,Color("e46b5a") if left<.3 else Color("5fbf6a"),4,true)
	if ready and fmod(clock,1.2)<.6: twinkle(b+Vector2(-40,-20),6,Color("fff1af"))

func draw_shop():
	var renovated=model.owned("renovation")
	var floor_style:Dictionary=Art.FLOORS[int(model.s.decor.floor)]
	var wall_style:Dictionary=Art.WALLS[int(model.s.decor.wall)]
	var face=Color(wall_style.face)
	var low=Color(wall_style.low)
	var trim=Color(wall_style.trim)
	lawn()
	# Outside, below the room: a path to the door, bushes and the chalkboard sign.
	for k in range(5): stone(iso((DOOR_L+DOOR_R)/2,ROOM_V+.7+k*.9),Vector2.ZERO)
	for p in [Vector2(20,600),Vector2(150,650),Vector2(470,560),Vector2(560,470)]: sprite(Art.name_for("bush",model.level("garden")),p,110)
	# Floor, then the two back walls.
	draw_floor(floor_style)
	shop_wall(iso(0,ROOM_V),iso(0,0),face,low,trim,wall_style.motif)
	shop_wall(iso(0,0),iso(ROOM_U,0),face,low,trim,wall_style.motif)
	wall_window(iso(0,0),SV,1.15,2.45,renovated)
	wall_window(iso(0,0),SU,1.9,3.2,renovated)
	star_chart(iso(0,0),SV,3.1,4.4)
	for t in [[SV,.65],[SU,3.6],[SU,7.1]]: sconce(iso(0,0)+t[0]*t[1])
	if renovated:
		# Fairy lights along the beam and the shop's name above the back wall.
		for i in range(7):
			var p=iso(.3+i*1.05,0)-Vector2(0,WALL_H-18)
			draw_line(p,p+SU*1.05,Color("6d5a4a"),1.2,true)
			draw_circle(p+SU*.52+Vector2(0,5),4,Color("fff1af",.6+.4*sin(clock*3+i)))
		var board=iso(3.9,0)-Vector2(0,WALL_H+32)
		for k in [.2,.8]: draw_line(board+SU*2.4*k+Vector2(0,28),board+SU*2.4*k+Vector2(0,34),Color("6d5a4a"),4,true)
		poly(quad(board,SU*2.4,Vector2(0,28)),Color("7d52c9"),true,Color("5b3a9e"))
		draw_set_transform_matrix(view_xform*shear_at(board,U.y/U.x))
		text(board+Vector2(14,21),"Little Lux",15,Color("fff7eb"))
		draw_set_transform_matrix(view_xform)
	rug(iso(1.9,1.9),SU*2.8,SV*2.2)
	# Everything standing on the floor draws back to front by its foot.
	var items:Array=[]
	var cauldron=station_pos("cauldron")
	var shelf=station_pos("shelf")
	var counter=station_pos("counter")
	items.append([iso(.55,.5).y,func(): sprite(Art.name_for("plant",model.level("garden")),iso(.55,.5),62*SS)])
	items.append([shelf.y,func():
		sprite_bounce(Art.name_for("shelf",model.level("shelf")),shelf,150*SS,"shelf")
		shelf_bottles(shelf,150*SS)])
	items.append([iso(7.2,.6).y,func(): sprite(Art.name_for("plant",model.level("garden")),iso(7.2,.6),48*SS)])
	items.append([cauldron.y,func():
		if model.s.pot!=-1:
			oval(cauldron-Vector2(0,24*SS),Vector2(66,28)*SS,Color("b38bff"))
			oval(cauldron-Vector2(0,24*SS),Vector2(61,24)*SS,Color("fff6ff"))
		sprite_bounce(Art.name_for("cauldron",model.level("cauldron")),cauldron,140*SS,"cauldron")
		if model.s.ready: glints(cauldron-Vector2(0,85*SS),Vector2(45,12)*SS,.2)
		if model.s.pot!=-1:
			for i in range(5):
				var t=fmod(clock*.5+i*.2,1.0)
				draw_circle(cauldron+Vector2(sin(i*3+clock)*20,-78-t*45),3+2*t,Color(.8,.6,1,1-t))])
	var brew_spot=iso(2.55,.85)
	if model.owned("brewer"): items.append([brew_spot.y,func(): person("brewer",brew_spot,78*SS,0,actor_action("brewer",model.s.pot!=-1),.3)])
	elif model.s.pot!=-1: items.append([brew_spot.y,func(): person("owner",brew_spot,83*SS,0,actor_action("owner",not model.s.ready),.3)])
	for crate in [["leaves",iso(1.15,3.5)],["flowers",iso(1.15,4.8)]]:
		items.append([crate[1].y,func(): sprite(crate[0],crate[1],92*SS)])
	if model.owned("brewer") or model.s.pot==-1:
		var u=2.75+sin(clock*.6)*.45
		var v=2.85+cos(clock*.6)*.3
		var travel=SU*(cos(clock*.6)*.45)-SV*(sin(clock*.6)*.3)
		var at=iso(u,v)
		items.append([at.y,func(): person("owner",at,90*SS,direction(travel),"walk" if float(actor_timers.get("owner",0.0))<=0 else "pickup",.7)])
	var cashier_spot=iso(6.4,2.65)
	if model.owned("cashier"): items.append([cashier_spot.y,func(): person("cashier",cashier_spot,70*SS,0,actor_action("cashier",model.s.serving),.8)])
	items.append([counter.y,func(): sprite_bounce(Art.name_for("counter",model.level("counter")),counter,206*SS,"counter",COUNTER_SHEAR)])
	if not model.s.visitor.is_empty():
		var vp=iso(VISITOR.x,VISITOR.y)
		items.append([vp.y,func(): draw_visitor()])
	for c in customers+departures:
		if c.g.y>ROOM_V: continue
		var cp=iso(c.g.x,c.g.y)
		items.append([cp.y,func(): person(customer_name(c),cp,70*SS,int(c.get("dir",2)),customer_action(c),float(c.g.x)*.3)])
	items.sort_custom(func(a,b): return a[0]<b[0])
	for it in items: it[1].call()
	badge(cauldron+Vector2(0,-2),"cauldron")
	badge(shelf+Vector2(-64,-104),"shelf")
	badge(counter+Vector2(-62,-92),"counter")
	if model.s.pot!=-1: pill(cauldron+Vector2(-112,-122),"Ready to stock" if model.s.ready else "Brewing",model.s.brew_progress/model.brew_time(model.s.pot),115)
	# Low front railing with an open doorway, then the street side.
	railing(iso(0,ROOM_V),iso(DOOR_L,ROOM_V),low,trim)
	railing(iso(DOOR_R,ROOM_V),iso(ROOM_U,ROOM_V),low,trim)
	railing(iso(ROOM_U,0),iso(ROOM_U,ROOM_V),low,trim)
	for p in [iso(0,ROOM_V),iso(DOOR_L,ROOM_V),iso(DOOR_R,ROOM_V),iso(ROOM_U,ROOM_V),iso(ROOM_U,0),iso(ROOM_U,ROOM_V*.5),iso(DOOR_L*.5,ROOM_V)]: post_box(p,trim)
	poly(quad(iso(DOOR_L+.2,ROOM_V+.15),SU*(DOOR_R-DOOR_L-.4),SV*.9),Color("a8323f"),true,Color("7a2230"))
	# Outside the door, customers and props also draw back to front.
	var outside:Array=[]
	for c in customers+departures:
		if c.g.y<=ROOM_V: continue
		var cp=iso(c.g.x,c.g.y)
		outside.append([cp.y,func(): person(customer_name(c),cp,70*SS,int(c.get("dir",2)),customer_action(c),float(c.g.x)*.3)])
	for spot in [iso(DOOR_L-.7,ROOM_V+.5),iso(DOOR_R+.7,ROOM_V+.5)]:
		outside.append([spot.y,func(): sprite(Art.name_for("plant",model.level("garden")),spot,54*SS)])
	var chalk=iso(DOOR_L-1.9,ROOM_V+1.7)
	outside.append([chalk.y,func(): draw_sign(chalk)])
	outside.sort_custom(func(a,b): return a[0]<b[0])
	for it in outside: it[1].call()

func draw_floor(style:Dictionary):
	var a=Color(style.a)
	var b=Color(style.b)
	var line=Color(style.line)
	poly(quad(iso(0,0),SU*ROOM_U,SV*ROOM_V),a)
	if style.motif=="planks":
		# Boards run along U; joints stagger from row to row.
		var rows:=int(ROOM_V/.45)
		for r in range(rows):
			var v0=r*.45
			if r%2: poly(quad(iso(0,v0),SU*ROOM_U,SV*.45),b)
			draw_line(iso(0,v0),iso(ROOM_U,v0),line,1.4,true)
			var u=fmod(r*1.3,2.6)
			while u<ROOM_U:
				draw_line(iso(u,v0),iso(u,v0+.45),line,1.2,true)
				u+=2.6
		return
	for u in range(int(ceil(ROOM_U))):
		for v in range(int(ceil(ROOM_V))):
			var su=minf(1.0,ROOM_U-u)
			var sv=minf(1.0,ROOM_V-v)
			if (u+v)%2: poly(quad(iso(u,v),SU*su,SV*sv),b)
			var centre=iso(u+.5*su,v+.5*sv)
			if (u+v)%5==0 and style.motif=="diamond":
				poly([centre+Vector2(0,-5),centre+Vector2(6,0),centre+Vector2(0,5),centre+Vector2(-6,0)],Color(Color("b995e4"),.45))
			elif (u+v)%5==0 and style.motif=="leaf":
				mint_leaf(centre-Vector2(4,3),centre+Vector2(5,-5),3,Color(Color("70aa6f"),.4))
	for u in range(int(ceil(ROOM_U))): draw_line(iso(u,0),iso(u,ROOM_V),line,1.2,true)
	for v in range(int(ceil(ROOM_V))): draw_line(iso(0,v),iso(ROOM_U,v),line,1.2,true)

# A tall back wall: plaster above wainscot panels, timber posts and a top beam.
func shop_wall(a:Vector2,b:Vector2,face:Color,low:Color,trim:Color,motif:String):
	var h:=WALL_H
	var up:=Vector2(0,h)
	poly([a,b,b-up,a-up],face)
	if motif=="plain":
		# Faint stonework in the plaster.
		for row in range(5):
			var z=h*(.42+row*.11)
			var n:=int(a.distance_to(b)/34)
			for k in range(n):
				var t=(k+.5*(row%2))/n
				if t<1: draw_line(a.lerp(b,t)-Vector2(0,z),a.lerp(b,minf(1,t+.6/n))-Vector2(0,z),face.darkened(.06),2,true)
	elif motif=="panel":
		for t in [.2,.5,.8]:
			var q=a.lerp(b,t)-Vector2(0,h*.7)
			draw_line(q-Vector2(0,22),q+Vector2(0,22),trim,2,true)
	elif motif=="vine":
		for t in [.15,.45,.75]:
			var q=a.lerp(b,t)-Vector2(0,h*.36)
			draw_line(q,q-Vector2(0,h*.5),Color("579162"),2,true)
			for k in range(4): mint_leaf(q-Vector2(0,k*18+7),q+Vector2(10 if k%2 else -10,-k*18-17),4,Color("78a76d"))
	var dado=h*.34
	poly([a,b,b-Vector2(0,dado),a-Vector2(0,dado)],low)
	var panels:=int(a.distance_to(b)/38)
	for k in range(1,panels): draw_line(a.lerp(b,float(k)/panels)-Vector2(0,6),a.lerp(b,float(k)/panels)-Vector2(0,dado-6),low.darkened(.14),2,true)
	draw_line(a-Vector2(0,dado),b-Vector2(0,dado),trim,6,true)
	draw_line(a-Vector2(0,dado+3),b-Vector2(0,dado+3),trim.lightened(.25),2,true)
	draw_line(a-Vector2(0,3),b-Vector2(0,3),trim.darkened(.3),6,true)
	var beams:=maxi(1,int(a.distance_to(b)/120))
	for k in range(beams+1):
		var p=a.lerp(b,float(k)/beams)
		draw_line(p,p-up,trim.darkened(.25),12,true)
		draw_line(p-Vector2(2,0),p-up-Vector2(2,0),trim.darkened(.05),6,true)
	draw_line(a-up,b-up,trim.darkened(.35),16,true)
	draw_line(a-up-Vector2(0,4),b-up-Vector2(0,4),trim,8,true)

# Arched window on a wall plane: dir runs along the wall, s0..s1 in grid units.
func wall_window(origin:Vector2,dir:Vector2,s0:float,s1:float,curtains:bool):
	var a=origin+dir*s0
	var b=origin+dir*s1
	var z0=WALL_H*.4
	var z1=WALL_H*.78
	var r=(z1-z0)*.28
	var pts=[]
	for k in range(9): pts.append(a.lerp(b,k/8.0)-Vector2(0,z1+r*sin(PI*k/8.0)))
	var outline=[a-Vector2(0,z0)]+pts+[b-Vector2(0,z0)]
	poly(outline,Color("6f4a32"))
	var inset=[]
	var mid=(a+b)/2-Vector2(0,(z0+z1)/2)
	for q in outline: inset.append(mid+(q-mid)*.86)
	poly(inset,Color("a9d8ef"))
	poly([inset[0],inset[0].lerp(inset[5],.5),inset[inset.size()-1].lerp(inset[5],.5),inset[inset.size()-1]],Color("8cc6e6"))
	var top=a.lerp(b,.5)-Vector2(0,z1+r)
	draw_line(a.lerp(b,.5)-Vector2(0,z0),top,Color("6f4a32"),4,true)
	draw_line(a-Vector2(0,(z0+z1)/2),b-Vector2(0,(z0+z1)/2),Color("6f4a32"),4,true)
	draw_line(inset[2],inset[2]+(b-a)*.12+Vector2(0,10),Color(1,1,1,.55),3,true)
	poly([a-Vector2(0,z0-2)-(b-a)*.08,b-Vector2(0,z0-2)+(b-a)*.08,b-Vector2(0,z0-8)+(b-a)*.08,a-Vector2(0,z0-8)-(b-a)*.08],Color("c48a57"),true,Color("7d4f2f"))
	if curtains:
		for side in [0.0,1.0]:
			var c=a.lerp(b,side)
			var out=(b-a).normalized()*(-1 if side==0 else 1)
			poly([c-Vector2(0,z1+r+6),c+out*14-Vector2(0,z1+r+6),c+out*18-Vector2(0,z0-14),c-out*2-Vector2(0,z0-14)],Color("a8323f"),true,Color("7a2230"))
			draw_circle(c+out*7-Vector2(0,z0+30),3.5,Color("f2c94c"))

func sconce(p:Vector2):
	var c=p-Vector2(0,WALL_H*.62)
	draw_circle(c,18,Color(1,.85,.45,.18+.06*sin(clock*4)))
	poly([c+Vector2(-5,10),c+Vector2(5,10),c+Vector2(4,-2),c+Vector2(-4,-2)],Color("d1a24a"),true,Color("8a6424"))
	oval(c-Vector2(0,6),Vector2(4,7),Color("ffe28a"))
	oval(c-Vector2(0,7),Vector2(2,4),Color("fff8d8"))

# Framed star chart hung on a wall plane.
func star_chart(origin:Vector2,dir:Vector2,s0:float,s1:float):
	var a=origin+dir*s0
	var b=origin+dir*s1
	var z0=WALL_H*.44
	var z1=WALL_H*.82
	poly([a-Vector2(0,z0),b-Vector2(0,z0),b-Vector2(0,z1),a-Vector2(0,z1)],Color("d1a24a"),true,Color("8a6424"))
	var m=.08
	var ia=a.lerp(b,m)
	var ib=b.lerp(a,m)
	poly([ia-Vector2(0,z0+5),ib-Vector2(0,z0+5),ib-Vector2(0,z1-5),ia-Vector2(0,z1-5)],Color("23264f"))
	var c=a.lerp(b,.5)-Vector2(0,(z0+z1)/2)
	draw_arc(c,16,0,TAU,24,Color("d1a24a",.6),1.2,true)
	twinkle(c,9,Color("f2c94c"))
	for k in range(5): draw_circle(c+Vector2.from_angle(k*1.9)*Vector2(22,14),1.6,Color("fff1af"))

func rug(at:Vector2,du:Vector2,dv:Vector2):
	poly(quad(at,du,dv),Color("8e2a3c"),true,Color("6a1e2c"))
	var inset=.1
	poly(quad(at+du*inset+dv*inset,du*(1-2*inset),dv*(1-2*inset)),Color("a8364a"))
	var edge=quad(at+du*inset+dv*inset,du*(1-2*inset),dv*(1-2*inset))
	draw_polyline(PackedVector2Array(edge+[edge[0]]),Color("e0b45a"),2,true)
	var c=at+du*.5+dv*.5
	poly([c-du*.12,c-dv*.16,c+du*.12,c+dv*.16],Color("e0b45a"))
	poly([c-du*.07,c-dv*.09,c+du*.07,c+dv*.09],Color("a8364a"))

# Low railing between two floor corners along the room's front edges.
func railing(a:Vector2,b:Vector2,low:Color,trim:Color):
	var h=44.0
	poly([a,b,b-Vector2(0,h),a-Vector2(0,h)],low.darkened(.08),true,trim.darkened(.35))
	var n:=maxi(1,int(a.distance_to(b)/26))
	for k in range(1,n): draw_line(a.lerp(b,float(k)/n)-Vector2(0,5),a.lerp(b,float(k)/n)-Vector2(0,h-5),low.darkened(.2),2,true)
	draw_line(a-Vector2(0,h),b-Vector2(0,h),trim.darkened(.3),10,true)
	draw_line(a-Vector2(0,h+3),b-Vector2(0,h+3),trim,6,true)

# A square timber post with a gold cap, standing on p.
func post_box(p:Vector2,trim:Color):
	var a=.22
	var h=64.0
	var l=p-SU*a+SV*a
	var f=p+SU*a+SV*a
	var r=p+SU*a-SV*a
	poly([l,f,f-Vector2(0,h),l-Vector2(0,h)],trim.darkened(.15),true,trim.darkened(.45))
	poly([f,r,r-Vector2(0,h),f-Vector2(0,h)],trim.darkened(.32),true,trim.darkened(.45))
	var top=[l-Vector2(0,h),f-Vector2(0,h),r-Vector2(0,h),p-SU*a-SV*a-Vector2(0,h)]
	poly(top,Color("f2c94c"),true,Color("b9822a"))
	var apex=p-Vector2(0,h+14)
	poly([top[0],top[1],apex],Color("e0b040"),true,Color("b9822a"))
	poly([top[1],top[2],apex],Color("c99a32"),true,Color("b9822a"))

func shelf_bottles(base:Vector2,w:float):
	# Bottles stand on the shelf's two boards, following the boards' slope.
	var sc=w/359.0
	var origin=base-Vector2(179.5,377)*sc
	# Most valuable potions first, matching the order customers buy them.
	var kinds=[]
	for r in range(model.s.stock.size()-1,-1,-1):
		for n in range(int(model.s.stock[r])): kinds.append(r)
	var count=mini(kinds.size(),12)
	var per_row=3 if model.capacity()<=6 else 6
	var bw=30.0 if per_row==3 else 21.0
	for i in range(count):
		var r=i/per_row
		var k=i%per_row
		var a=Vector2(70,158+r*103)
		var b=Vector2(250,207+r*103)
		var p=origin+a.lerp(b,(k+.5)/per_row)*sc
		sprite(Art.name_for(Art.POTIONS[kinds[i]],model.level("cauldron")),p,bw)

func draw_effects():
	for q in particles:
		var a=clampf(q.life/q.max*1.6,0,1)
		match q.kind:
			"coin": draw_texture_rect(coin_tex,Rect2(q.p-Vector2(9,9),Vector2(18,18)),false,Color(1,1,1,a))
			"star": twinkle(q.p,q.r+2,Color(q.color,a))
			"leaf":
				var d=Vector2.from_angle(q.life*q.spin)*q.r*1.4
				poly([q.p-d,q.p+d.orthogonal()*.45,q.p+d,q.p-d.orthogonal()*.45],Color(q.color,a))
			_: draw_circle(q.p,q.r*(.5+a*.5),Color(q.color,a))
	for f in floaters:
		var e=1-pow(1-minf(f.t/1.3,1),3)
		var p=f.p-Vector2(0,e*70)
		var a=clampf((1.3-f.t)*2.5,0,1)
		var s=24+int(10*maxf(0,.25-f.t)/.25)
		var c=Color("7b3fd1") if f.dream else Color("2f7d4f")
		if not f.get("coin",true): s+=10
		draw_string_outline(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,6,Color(1,1,1,a))
		draw_string(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,Color(c,a))
		var w=font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s).x
		if f.get("coin",true): draw_texture_rect(coin_tex,Rect2(p+Vector2(w+4,-s*.8),Vector2(s*.85,s*.85)),false,Color(1,1,1,a))

func _draw():
	if not model:return
	# The garden fills a 540x660 frame; the shop frames just its room. The
	# scene is drawn past its frame, so wider areas show more of it.
	var frame:Rect2=Rect2(0,0,540,660) if garden else SHOP_FRAME
	var factor=minf(size.x/frame.size.x,size.y/frame.size.y)
	var base_height=size.y/factor
	draw_rect(Rect2(Vector2.ZERO,size),Color(theme().ground))
	view_offset=Vector2((size.x-frame.size.x*factor)*.5,maxf(0,(base_height-frame.size.y)*.35*factor))-frame.position*factor
	view_scale=factor
	view_xform=Transform2D(0,Vector2.ONE*factor,0,view_offset)
	draw_set_transform_matrix(view_xform)
	if garden: draw_garden()
	else: draw_shop()
	if pulse>0 and effect=="stock" and not garden:
		# Arc the new bottle from cauldron to shelf.
		var t=clampf((1.2-pulse)/.6,0,1)
		var p=station_pos("cauldron").lerp(station_pos("shelf"),t)-Vector2(0,90+sin(t*PI)*60)
		if t<1: sprite(Art.name_for(Art.POTIONS[int(model.s.recipe)],model.level("cauldron")),p,31)
	draw_effects()
	draw_set_transform(Vector2.ZERO)
