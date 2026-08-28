"""every non native function must not contain underscores,
variables can always contain underscores, it doesnt matter
except for Input.is_action...... most things dont need to be called every single frame
at most every if Engine.get_physics_frames() % 2 == 0:  and even then, cache everything so 
functions avoid being called twice if nothing changed at all, make everything strictly statically typed never
variable name:= but always varibable:type = and avoid errors in operands between max() mix() % with ints and floats
this is supposed to be an mmorpg with a dedicated server, a client is never a server, it can also be played offline 
and the game shall offer both and be playable in both ways """
