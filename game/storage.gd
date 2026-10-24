extends RefCounted
var path := "user://little_lux.json"
var error := ""
var locked := false

func save(model, now: float = -1.0) -> bool:
	if locked: return false
	if now < 0: now = Time.get_unix_time_from_system()
	model.s.timestamp = maxf(now,model.s.timestamp)
	var text := JSON.stringify(model.s)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		error = "Cannot write save"
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var check = JSON.parse_string(FileAccess.get_file_as_string(path+".tmp"))
	if not model.valid(check):
		error = "Save verification failed"
		return false
	if FileAccess.file_exists(path):
		var previous = parse(FileAccess.get_file_as_string(path))
		if model.valid(previous):
			DirAccess.copy_absolute(path,path+".bak")
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		error = "Could not finalize save"
		return false
	model.dirty = false
	return true

func load_into(model, now: float = -1.0) -> bool:
	if now < 0: now = Time.get_unix_time_from_system()
	var exists := false
	for suffix in ["", ".tmp", ".bak"]:
		if not FileAccess.file_exists(path+suffix): continue
		exists = true
		var v = parse(FileAccess.get_file_as_string(path+suffix))
		if v is Dictionary and v.get("version",0) > 1:
			locked = true
			error = "Save belongs to a newer version. Reset required."
			return false
		if model.valid(v):
			model.s = v
			model.offline(now)
			# Persist before showing a welcome-back report; dismiss never credits money.
			save(model,now)
			return true
	if exists:
		locked = true
		error = "Save could not be recovered. Reset required."
	return false

func reset(model):
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	locked = false
	error = ""
	model.fresh()
	save(model)

func parse(text: String):
	var parser:=JSON.new()
	return parser.data if parser.parse(text)==OK else null
