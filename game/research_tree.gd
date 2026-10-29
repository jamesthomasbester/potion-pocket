extends Control
# One Grimoire chapter drawn as a tree on parchment: tier one at the bottom,
# the keystone at the top, ink lines between tiers. Tap a page to select it.
# Celestial pages are the Moon Star talents, which have no tier gating.

signal picked(id: String)

var model
var chapter := "herb"
var selected := ""
var icons := {}
var clock := 0.0
var font := ThemeDB.fallback_font
const INK = Color("2b1a3d")
const WOOD = Color("6b3f24")
const CREAM = Color("fff3df")
const GOLD = Color("f2b632")
const PURPLE = Color("8a5cd6")
# Where each Moon Star talent sits in the Celestial chapter: [tier, column].
const CELESTIAL = {"roots":[1,0],"bubbles":[1,1],"street":[1,2],"patrons":[2,0],"night":[2,2],"team":[3,1]}

func _process(dt):
	clock+=dt
	queue_redraw()

# Every page in this chapter as {id, tier, col, ranks, rank, state, key}.
func entries() -> Array:
	var out:=[]
	if chapter=="star":
		for t in model.cfg.talents:
			var spot:Array=CELESTIAL[t.id]
			var r:int=model.talent(t.id)
			var state:="learned" if r>=int(t.ranks) else "ready" if model.stars_free()>=model.talent_cost(t.id) else "locked"
			out.append({"id":t.id,"tier":spot[0],"col":spot[1],"ranks":int(t.ranks),"rank":r,"state":state,"key":spot[0]==3})
		return out
	for page in model.research.pages:
		if page.chapter!=chapter: continue
		out.append({"id":page.id,"tier":int(page.tier),"col":int(page.col),"ranks":int(page.ranks),"rank":model.rank(page.id),"state":model.page_state(page.id),"key":int(page.tier)==3})
	return out

func spot(e:Dictionary) -> Vector2:
	return Vector2(size.x*(.2+e.col*.3),size.y*(1.1-e.tier*.31))

func color() -> Color:
	for c in model.research.chapters:
		if c.id==chapter: return Color(c.color)
	return GOLD

func _gui_input(event):
	if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
		for e in entries():
			if event.position.distance_to(spot(e))<40:
				selected=e.id
				picked.emit(e.id)
				accept_event()
				return

func _draw():
	if not model: return
	var bg:=StyleBoxFlat.new()
	bg.bg_color=Color("fbf1df")
	bg.border_color=WOOD
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(18)
	draw_style_box(bg,Rect2(Vector2.ZERO,size))
	for y in range(26,int(size.y),26): draw_line(Vector2(12,y),Vector2(size.x-12,y),Color(WOOD,.05),1)
	var list:=entries()
	for i in range(3):
		var y:float=maxf(16,size.y*(1.1-(i+1)*.31)-40)
		draw_string(font,Vector2(12,y),["TIER ONE","TIER TWO","KEYSTONE"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("9a8466"))
	# Ink lines: gold once the lower page has a rank, dashed while it doesn't.
	for a in list:
		for b in list:
			if b.tier!=a.tier+1: continue
			if a.rank>0: draw_line(spot(a),spot(b),Color("c9932b"),3,true)
			else: draw_dashed_line(spot(a),spot(b),Color("b9a283"),2,7,true)
	var hue:=color()
	for e in list: draw_page(e,hue)

func draw_page(e:Dictionary,hue:Color):
	var p:=spot(e)
	var r:=34.0 if e.key else 29.0
	var fill:Color={"learned":hue,"studying":CREAM,"ready":CREAM,"locked":Color("efe4d2")}[e.state]
	# Partly learned pages carry a wash of the chapter's colour.
	if e.rank>0 and e.state!="learned": fill=CREAM.lerp(hue,.45)
	var ring:Color={"learned":WOOD,"studying":PURPLE,"ready":GOLD,"locked":Color("b9a283")}[e.state]
	if e.state=="ready": draw_circle(p,r+7+sin(clock*3)*1.5,Color(GOLD,.25))
	if e.id==selected: draw_circle(p,r+8,Color(PURPLE,.35))
	if e.key:
		# Keystones are diamonds.
		var pts:=PackedVector2Array([p+Vector2(0,-r-4),p+Vector2(r+4,0),p+Vector2(0,r+4),p+Vector2(-r-4,0)])
		draw_colored_polygon(pts,fill)
		draw_polyline(pts+PackedVector2Array([pts[0]]),ring,3,true)
	else:
		draw_circle(p,r,fill)
		if e.state=="studying":
			# A dashed ring that slowly turns while the page is studied.
			for k in range(12):
				var a0:=clock*.8+k*TAU/12
				draw_arc(p,r,a0,a0+TAU/24,6,ring,3,true)
		else: draw_arc(p,r,0,TAU,40,ring,3,true)
	var tex:Texture2D=icons.get(e.id)
	if tex:
		var side:=r*1.25
		draw_texture_rect(tex,Rect2(p-Vector2(side,side)/2,Vector2(side,side)),false,Color(1,1,1,.45) if e.state=="locked" else Color.WHITE)
	if e.ranks>1 or e.rank>0:
		var label:="%d/%d" % [e.rank,e.ranks]
		var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+12
		var st:=StyleBoxFlat.new()
		st.bg_color=CREAM
		st.border_color=WOOD
		st.set_border_width_all(2)
		st.set_corner_radius_all(9)
		var box:=Rect2(p+Vector2(-w/2,r-6),Vector2(w,18))
		draw_style_box(st,box)
		draw_string(font,box.position+Vector2(6,14),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
