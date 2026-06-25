extends Node


func _physics_process(delta):
	var velocity = rootMotion(delta)
	if velocity != Vector3.ZERO:
		move_and_slide(velocity)
	
func rootMotion(delta)->Vector3:
	var motion = animation_tree.get_root_motion_transform().origin
	motion.y = 0.0
	if motion.length_squared() < 0.000001:return Vector3.ZERO
	motion = global_transform.basis.xform(motion)
	return motion * 0.01 / delta
