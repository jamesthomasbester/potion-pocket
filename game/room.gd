extends Control
# The garden tab: house front, lane, raised beds and the gardener, drawn in
# a 540x660 frame fitted to this control. The shop is game/shop_view.gd.
const Art = preload("res://game/art_catalog.gd")
var model
var clock := 0.0
var redraw_clock := 0.0
var pulse := 0.0
var effect := ""
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
# One oblique grid for the lane, beds and props, matched to the sprites' own
# long (U) and depth (V) edges.
const U = Vector2(52,18)
const V = Vector2(-34,32)
const GARDEN_ORIGIN = Vector2(430,205)
# Garden bed slots in purchase order: two either side of the lane, then down the right.
const GARDEN_BEDS = [Vector2(-3.1,2.4),Vector2(2.3,5.4),Vector2(2.3,2.4),Vector2(2.3,8.4),Vector2(-2.9,5.3),Vector2(2.3,11.4)]
const BED_W = 180.0
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

func spray(at:Vector2,count:int,kind:String,color:Color,speed:=160.0,up:=-120.0,g:=320.0,life:=0.9):
	for i in range(count):
		var dir=Vector2.from_angle(randf_range(-PI,0))*randf_range(.35,1)*speed+Vector2(0,up)
		particles.append({"p":at+Vector2(randf_range(-14,14),randf_range(-6,6)),"v":dir,"g":g,"drag":1.2,"life":life*randf_range(.7,1.1),"max":life,"kind":kind,"color":color,"r":randf_range(3,6)*(1.6 if kind=="leaf" else 1.0),"spin":randf_range(-6,6)})

func bed_center(i:int) -> Vector2:
	return giso(GARDEN_BEDS[i].x,GARDEN_BEDS[i].y)

# Which station a tap in this control's local space lands on, if any.
func station_at(p:Vector2) -> String:
	var q=(p-view_offset)/view_scale
	var n:int=model.s.plots.size()
	if n<GARDEN_BEDS.size() and q.distance_to(bed_center(n))<85: return "plot"
	for i in range(n):
		if q.distance_to(bed_center(i))<95: return "garden"
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
			for i in range(model.s.plots.size()):
				spray(bed_center(i)-Vector2(0,30),9,"leaf",Color("8fd16a"),150,-180,300,1.0)
				bounce["bed"+str(i)]=1.0
		"sale","dream_sale":
			# Sales still count up in the corner while you tend the garden.
			var amount=model.price(1 if kind=="dream_sale" else 0)
			if clock-last_sale_fx<.35 and not floaters.is_empty() and floaters.back().has("amount"):
				var f=floaters.back()
				f.amount+=amount
				f.text="+"+model.short(f.amount)
				f.t=minf(f.t,.2)
			else:
				floaters.append({"p":Vector2(420,30),"t":0.0,"amount":amount,"text":"+"+model.short(amount),"dream":kind=="dream_sale","coin":true})
			last_sale_fx=clock
		"level","milestone":
			var at=bed_center(0)-Vector2(0,40)
			bounce["bed0"]=1.0
			bounce["bed1"]=1.0
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
	var factor=minf(size.x/540.0,size.y/660.0)
	var base_height=size.y/factor
	# The scene is drawn past its 540x660 frame, so wider areas show more of it.
	draw_rect(Rect2(Vector2.ZERO,size),Color(theme().ground))
	view_offset=Vector2((size.x-540*factor)*.5,maxf(0,(base_height-660)*.35*factor))
	view_scale=factor
	view_xform=Transform2D(0,Vector2.ONE*factor,0,view_offset)
	draw_set_transform_matrix(view_xform)
	draw_garden()
	draw_effects()
	draw_set_transform(Vector2.ZERO)
