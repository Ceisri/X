# ============================================================
# FreezeWatchdog.gd — NEW FILE. Add as an Autoload (singleton) named
# "FreezeWatchdog", ORDER: put it FIRST in the autoload list so it always
# gets its process tick.
#
# This does NOT guess. It measures REAL wall-clock time between frames
# (not script/physics ms, which is why the Godot profiler shows nothing —
# a stall in synchronous disk I/O, a mutex wait, or a driver/vsync stall
# all block the single main thread but are invisible to the profiler's
# script/physics buckets). The instant a frame takes way longer than it
# should, this dumps every queue/counter in the project that could
# possibly be the cause, with a timestamp, so we get an actual answer
# instead of another guess.
# ============================================================
extends Node

export var freeze_threshold_ms := 200.0  # anything above this = a "freeze" worth reporting

var _last_ticks_usec := 0
var _last_physics_ticks_usec := 0

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	set_physics_process(true)
	_last_ticks_usec = OS.get_ticks_usec()
	_last_physics_ticks_usec = OS.get_ticks_usec()
	print("[FreezeWatchdog] armed, threshold=", freeze_threshold_ms, "ms")

func _process(_delta) -> void:
	var now := OS.get_ticks_usec()
	var elapsed_ms := (now - _last_ticks_usec) / 1000.0
	_last_ticks_usec = now
	if elapsed_ms >= freeze_threshold_ms:
		_report("PROCESS", elapsed_ms)

func _physics_process(_delta) -> void:
	var now := OS.get_ticks_usec()
	var elapsed_ms := (now - _last_physics_ticks_usec) / 1000.0
	_last_physics_ticks_usec = now
	if elapsed_ms >= freeze_threshold_ms:
		_report("PHYSICS", elapsed_ms)

func _report(kind:String, elapsed_ms:float) -> void:
	print("=====================================================")
	print("[FreezeWatchdog] ", kind, " frame took ", stepify(elapsed_ms,0.1), " ms  (real wall-clock gap)")
	print("  time: ", OS.get_datetime())
	print("  Engine.get_frames_drawn()=", Engine.get_frames_drawn(), "  get_physics_frames()=", Engine.get_physics_frames())
	print("  FPS monitor=", Engine.get_frames_per_second())

	# ---- World.gd background file-write thread queue ----
	for world in get_tree().get_nodes_in_group("World"):
		if !is_instance_valid(world):
			continue
		if "pendingFileWrites" in world:
			print("  World[", world.world_id, "].pendingFileWrites.size()=", world.pendingFileWrites.size())
		if "_autosave_running" in world:
			print("  World[", world.world_id, "]._autosave_running=", world._autosave_running)
		if "cached_saveable_nodes" in world:
			print("  World[", world.world_id, "].cached_saveable_nodes.size()=", world.cached_saveable_nodes.size())
		if "_pending_save_queue" in world:
			print("  World[", world.world_id, "]._pending_save_queue.size()=", world._pending_save_queue.size())
		if "collidable_shapes" in world:
			print("  World[", world.world_id, "].collidable_shapes.size()=", world.collidable_shapes.size())
		if "_entity_cache" in world:
			print("  World[", world.world_id, "]._entity_cache.size()=", world._entity_cache.size())

	# ---- Global.gd suspects ----
	if is_instance_valid(Global):
		print("  Global._all_mob_list_cache.size()=", Global._all_mob_list_cache.size())
		print("  Global._active_mob_dict.size()=", Global._active_mob_dict.size())
		print("  Global._grid world count=", Global._grid.size())
		print("  Global._entry.size()=", Global._entry.size())
		print("  Global._mob_skeleton_cache.size()=", Global._mob_skeleton_cache.size())
		print("  Global._mob_lod_cache.size()=", Global._mob_lod_cache.size())
		print("  Global._impostor_multimeshes.size()=", Global._impostor_multimeshes.size())
		print("  Global._catchup_queues.size()=", Global._catchup_queues.size())
		print("  Global._skill_tree_data_cache.size()=", Global._skill_tree_data_cache.size())
		print("  Global._dirty_skill_tree_saves.size()=", Global._dirty_skill_tree_saves.size())
		print("  Global._texture_load_cache.size()=", Global._texture_load_cache.size())
		print("  Global._button_list_cache_valid=", Global._button_list_cache_valid)

	# ---- PerformanceMetrics suspects (per local player) ----
	for node in get_tree().get_nodes_in_group("Player"):
		if !is_instance_valid(node):
			continue
		var pm = node.get_node_or_null("PerformanceMetrics")
		if is_instance_valid(pm):
			print("  PerformanceMetrics.entityCache.size()=", pm.entityCache.size())
			print("  PerformanceMetrics.relevanceBatches=", pm.relevanceBatches, " mobRescanInterval=", pm.mobRescanInterval)
			print("  PerformanceMetrics._radius_cache_queue.size()=", pm._radius_cache_queue.size())
			print("  PerformanceMetrics.rescanFrame=", pm.rescanFrame, " (now=", Engine.get_physics_frames(), ")")

	# ---- node / object counts, to correlate with a leak spike ----
	print("  Performance OBJECT_COUNT=", Performance.get_monitor(Performance.OBJECT_COUNT))
	print("  Performance OBJECT_NODE_COUNT=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("  Performance OBJECT_RESOURCE_COUNT=", Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("  Performance RENDER_VIDEO_MEM_USED=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	print("=====================================================")
