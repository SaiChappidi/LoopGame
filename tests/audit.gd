extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var store = LocalStore.new("res://../../work/audit-state.json")
	for m in store.catalog: print(m.id+" "+JSON.stringify(CompatibilityAudit.inspect(m)))
	await process_frame
	quit()
