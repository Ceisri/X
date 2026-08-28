extends TextureRect

onready var player = $"../../../../.."
onready var grid_container = $"../.."
var savedTexture: Texture
var savedQuantity: int


func saveData():
	var parentName = get_parent().get_name()

	var folderPath = "user://Characters/" + player.entity_name + "/" + grid_container.name + "/"
	var savePath = folderPath + parentName + "_saved_texture_data.txt"

	var dir = Directory.new()
	if !dir.dir_exists(folderPath):
		dir.make_dir_recursive(folderPath)

	var file = File.new()
	if file.open(savePath, File.WRITE) != OK:
		return

	var holder = get_parent().get_node("TextureButton")

	savedTexture = texture
	savedQuantity = holder.quantity

	if savedTexture != null:
		file.store_line(savedTexture.resource_path)
	else:
		file.store_line("")

	file.store_line(str(savedQuantity))
	file.close()


