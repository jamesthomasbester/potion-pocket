extends Control
var model
var garden := false
var clock := 0.0
var redraw_clock := 0.0
var pulse := 0.0
var effect := ""
var customers: Array = []
var departures: Array = []
var textures := {}
var floor_lines: Array = []
var particles: Array = []
var floaters: Array = []
var bounce := {}
var coin_tex: Texture2D
const INK = Color("191b43")
var font = ThemeDB.fallback_font

func _ready():
	var floor_shape=PackedVector2Array([Vector2(105,125),Vector2(620,290),Vector2(470,700),Vector2(-130,415)])
	var origin=Vector2(105,125)
	var u=Vector2(51.5,16.5)
	var v=Vector2(-29.375,36.25)
	for i in range(15):
		for segment in [PackedVector2Array([origin+i*u,origin+i*u+14*v]),PackedVector2Array([origin+i*v,origin+i*v+14*u])]:
			for clipped in Geometry2D.intersect_polyline_with_polygon(segment,floor_shape):floor_lines.append(clipped)
	for name in ["cauldron","shelf","counter","leaves","flowers","bed","bush","plant","gate","owner","brewer","cashier","gardener","customer0","customer1","departing","energy","dream"]:
		var path="res://game/art/"+name+".png"
		if ResourceLoader.exists(path): textures[name]=load(path)
	coin_tex=load("res://game/art/coin.svg")

func _process(dt):
	clock+=dt
	pulse=maxf(0,pulse-dt)
	if model:
		while customers.size()<int(model.s.queue): customers.append({"p":Vector2(235,605),"variant":customers.size()%2})
		while customers.size()>int(model.s.queue): leave_customer()
		for i in range(customers.size()): customers[i].p=customers[i].p.move_toward(Vector2(378-i*35,490+i*48),dt*80)
		for c in departures: c.p=c.p.move_toward(Vector2(215,700),dt*100)
		departures=departures.filter(func(c):return c.p.y<690)
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

# Visual response to economy feedback; positions are in the 540x660 scene space.
func burst(kind:String):
	match kind:
		"harvest":
			for i in range(2):
				var at=Vector2(185+i*170,320+i*90) if garden else Vector2(310+i*150,70+i*35)
				spray(at,12,"leaf",Color("8fd16a"),170,-190,300,1.1)
				bounce["bed"+str(i)]=1.0
		"brew":
			if not garden:
				spray(Vector2(113,240),12,"dot",Color("b58af1"),120,-150,380,.8)
				bounce["cauldron"]=1.0
		"stock":
			if not garden:
				spray(Vector2(445,250),8,"star",Color("fff1af"),110,-60,60,.8)
				bounce["shelf"]=1.0
				bounce["cauldron"]=.6
		"sale","dream_sale":
			var at=Vector2(400,410) if not garden else Vector2(440,70)
			if not garden:
				spray(at,7,"coin",Color.WHITE,170,-230,520,1.0)
				bounce["counter"]=.7
			floaters.append({"p":at-Vector2(20,30),"t":0.0,"text":"+%d"%model.price(1 if kind=="dream_sale" else 0),"dream":kind=="dream_sale"})
		"upgrade":
			spray(Vector2(270,300),26,"star",Color("ffd765"),300,-120,140,1.2)
			spray(Vector2(270,300),14,"dot",Color("b58af1"),260,-160,260,1.0)

func leave_customer():
	if not customers.is_empty(): departures.append(customers.pop_front())

func poly(points, color, outline:=false):
	draw_colored_polygon(PackedVector2Array(points),color)
	if outline: draw_polyline(PackedVector2Array(points+[points[0]]),Color("b78059"),2,true)

func oval(p:Vector2,r:Vector2,c:Color):
	var points=[]
	for i in range(40): points.append(p+Vector2(cos(i*TAU/40)*r.x,sin(i*TAU/40)*r.y))
	poly(points,c)

func sprite(name:String,p:Vector2,w:float):
	if not textures.has(name): return
	var tex:Texture2D=textures[name]
	var h=w*tex.get_height()/tex.get_width()
	draw_texture_rect(tex,Rect2(p-Vector2(w/2,h),Vector2(w,h)),false)

func sprite_bounce(name:String,p:Vector2,w:float,key:String):
	var t:float=bounce.get(key,0.0)
	var squash=sin(t*PI*3.0)*t*.12
	if not textures.has(name): return
	var tex:Texture2D=textures[name]
	var sw=w*(1+squash)
	var h=w*tex.get_height()/tex.get_width()*(1-squash)
	draw_texture_rect(tex,Rect2(p-Vector2(sw/2,h),Vector2(sw,h)),false)

func twinkle(p:Vector2,r:float,c:Color):
	poly([p+Vector2(0,-r),p+Vector2(r*.28,-r*.28),p+Vector2(r,0),p+Vector2(r*.28,r*.28),p+Vector2(0,r),p+Vector2(-r*.28,r*.28),p+Vector2(-r,0),p+Vector2(-r*.28,-r*.28)],c)

func glints(center:Vector2,spread:Vector2,seed:float):
	for i in range(3):
		var t=fmod(clock*.8+i*.37+seed,1.0)
		var a=sin(t*PI)
		twinkle(center+Vector2(sin(i*2.1+seed)*spread.x,cos(i*1.7+seed)*spread.y),3+a*5,Color(1,.96,.7,a))

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
		draw_string_outline(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,6,Color(1,1,1,a))
		draw_string(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,Color(c,a))
		var w=font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s).x
		draw_texture_rect(coin_tex,Rect2(p+Vector2(w+4,-s*.8),Vector2(s*.85,s*.85)),false,Color(1,1,1,a))

func person(name:String,p:Vector2,w:=70.0):
	oval(p-Vector2(0,3),Vector2(w*.34,9),Color(0.35,0.22,0.16,.16))
	sprite(name,p-Vector2(0,sin(clock*3+p.x)*1.4),w)

func text(p:Vector2,s:String,n:=18,c:=INK):
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,n,c)

func pill(p:Vector2,title:String,progress:float,w:=100.0):
	var st=StyleBoxFlat.new()
	st.bg_color=Color("fff7eb")
	st.set_corner_radius_all(14)
	draw_style_box(st,Rect2(p,Vector2(w,43)))
	text(p+Vector2(10,18),title,14)
	st=st.duplicate();st.bg_color=Color("ded7e4");st.set_corner_radius_all(6)
	draw_style_box(st,Rect2(p+Vector2(7,25),Vector2(w-14,11)))
	st=st.duplicate();st.bg_color=Color("b58af1")
	draw_style_box(st,Rect2(p+Vector2(7,25),Vector2(maxf(3,(w-14)*clampf(progress,0,1)),11)))

func leaf(base:Vector2,tip:Vector2):
	var side=(tip-base).orthogonal().normalized()*4
	var mid=base.lerp(tip,.52)
	var shape=[base,mid+side,tip,mid-side]
	poly(shape,Color("6aa34d"))
	draw_polyline(PackedVector2Array(shape+[base]),Color("48743d"),.8,true)
	draw_line(base,tip,Color("96bd65"),.7,true)

func plant(p:Vector2,crop:int,stage:float):
	for j in range(3):
		var q=p+Vector2((j-1)*22,(j%2)*8)
		var h=14+stage*21
		draw_line(q,q-Vector2(0,h),Color("42764a"),2,true)
		for k in range(5):
			var base=q-Vector2(0,4+k*h/6)
			leaf(base,base+Vector2((-1 if k%2 else 1)*(8+stage*5),-5-stage*5))
		if crop==1 and stage>.55:
			for k in range(5): draw_circle(q-Vector2(0,h)+Vector2.from_angle(k*TAU/5)*4,3.5,Color("fff7dd"))
			draw_circle(q-Vector2(0,h),2,Color("ebca64"))

func wall(a:Vector2,b:Vector2,h:float):
	poly([a,b,b-Vector2(0,h),a-Vector2(0,h)],Color("ecd8c3"),true)
	poly([a,b,b-Vector2(0,h*.29),a-Vector2(0,h*.29)],Color("d8c4b2"))
	draw_line(a-Vector2(0,h*.29),b-Vector2(0,h*.29),Color("f9e9d3"),2,true)
	draw_line(a-Vector2(0,h),b-Vector2(0,h),Color("986447"),18,true)
	draw_line(a-Vector2(0,h+3),b-Vector2(0,h+3),Color("c98c62"),11,true)
	for t in [.2,.55,.8]:
		var q=a.lerp(b,t)-Vector2(0,h+2)
		draw_line(q,q+(b-a).normalized()*22,Color("b67b52"),1.2,true)
	for p in [a,b]:
		draw_line(p,p-Vector2(0,h+9),Color("966144"),19,true)
		draw_line(p-Vector2(3,0),p-Vector2(3,h+9),Color("bd8159"),12,true)

func _draw():
	if not model:return
	var factor=minf(size.x/540.0,size.y/660.0)
	var base_height=size.y/factor
	# Extend the landscape behind a uniformly scaled scene on taller phones.
	draw_rect(Rect2(Vector2.ZERO,size),Color("bba1d7"))
	draw_set_transform(Vector2((size.x-540*factor)*.5,maxf(0,(base_height-660)*.35*factor)),0,Vector2.ONE*factor)
	poly([Vector2(120,-140),Vector2(650,10),Vector2(550,230),Vector2(140,125)],Color("9cbd70"))
	for p in [Vector2(220,40),Vector2(510,100),Vector2(555,215)]:sprite("bush",p,135)
	if not garden:
		for i in range(2):
			var p=Vector2(310+i*150,95+i*35)
			sprite_bounce("bed",p,140,"bed"+str(i))
			var plot=model.s.plots[i]
			plant(p-Vector2(0,28),int(plot.crop),plot.progress/model.grow_time(int(plot.crop)))
			if plot.progress>=model.grow_time(int(plot.crop)): glints(p-Vector2(0,45),Vector2(40,10),i*.5)
	poly([Vector2(105,125),Vector2(620,290),Vector2(470,700),Vector2(-130,415)],Color("fae7cb"))
	for line in floor_lines:draw_polyline(line,Color("e5ceb0"),1.2,true)
	wall(Vector2(-25,273),Vector2(126,132),112)
	wall(Vector2(126,132),Vector2(292,187),112)
	sprite("gate",Vector2(339,201),92)
	wall(Vector2(391,220),Vector2(575,279),112)
	if garden:
		# Garden view foreground beds keep crop actions legible.
		for i in range(2):
			var p=Vector2(185+i*170,350+i*90)
			sprite_bounce("bed",p,205,"bed"+str(i))
			var plot=model.s.plots[i]
			plant(p-Vector2(0,43),int(plot.crop),plot.progress/model.grow_time(int(plot.crop)))
			if plot.progress>=model.grow_time(int(plot.crop)): glints(p-Vector2(0,70),Vector2(60,14),i*.5)
			pill(p+Vector2(-65,-135),"Harvest ready" if plot.progress>=model.grow_time(plot.crop) else "Growing herbs",plot.progress/model.grow_time(plot.crop),130)
		person("gardener" if model.owned("gardener") else "owner",Vector2(235,535),95)
	else:
		sprite("plant",Vector2(365,292),48)
		sprite_bounce("shelf",Vector2(449,334),153,"shelf")
		for i in range(mini(model.stock_count(),12)):
			var shelfpos=Vector2(403+(i%3)*36,252+(i%3)*11+(i/3)*24)
			sprite("dream" if i<int(model.s.stock[1]) else "energy",shelfpos,28)
		if model.owned("brewer"):person("brewer",Vector2(174,279),78)
		elif model.s.pot!=-1: person("owner",Vector2(177,275),83)
		if model.s.pot!=-1:
			oval(Vector2(113,292),Vector2(63,29),Color("b38bff"))
			oval(Vector2(113,292),Vector2(59,25),Color("fff6ff"))
		sprite_bounce("cauldron",Vector2(113,318),139,"cauldron")
		if model.s.ready: glints(Vector2(113,235),Vector2(45,12),.2)
		if model.s.pot!=-1:
			pill(Vector2(61,139),"Ready to stock" if model.s.ready else "Brewing",model.s.brew_progress/model.brew_time(model.s.pot),115)
			for i in range(5):
				var t=fmod(clock*.5+i*.2,1.0)
				draw_circle(Vector2(114+sin(i*3+clock)*26,230-t*55),3+2*t,Color(.8,.6,1,1-t))
		sprite("leaves",Vector2(47,388),93)
		sprite("flowers",Vector2(123,425),93)
		if model.owned("brewer") or model.s.pot==-1:person("owner",Vector2(272+sin(clock*.6)*14,410),90)
		if model.owned("cashier"):person("cashier",Vector2(459,419),70)
		sprite_bounce("counter",Vector2(435,499),202,"counter")
		for c in customers:person("customer"+str(c.variant),c.p,69)
		if model.owned("renovation"):
			for i in range(6):draw_circle(Vector2(155+i*65,40+i*21),4,Color("fff1af"))
	wall(Vector2(-25,454),Vector2(156,522),91)
	wall(Vector2(310,583),Vector2(493,654),91)
	poly([Vector2(155,523),Vector2(310,583),Vector2(281,641),Vector2(119,581)],Color("d9b082"),true)
	if not garden:
		for c in departures:
			person("departing",c.p,74)
	for p in [Vector2(28,558),Vector2(90,600),Vector2(390,702),Vector2(514,701)]:sprite("bush",p,115)
	sprite("plant",Vector2(133,552),44)
	sprite("plant",Vector2(322,651),53)
	if pulse>0 and effect=="stock" and not garden:
		# Arc the new bottle from cauldron to shelf.
		var t=clampf((1.2-pulse)/.6,0,1)
		var p=Vector2(150,240).lerp(Vector2(440,245),t)-Vector2(0,sin(t*PI)*70)
		if t<1: sprite("dream" if model.s.recipe else "energy",p,31)
	draw_effects()
	draw_set_transform(Vector2.ZERO)
