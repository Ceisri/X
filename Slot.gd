extends TextureRect

onready var player = $"../../../../.."
onready var grid_container = $"../.."
var savedTexture: Texture
var savedQuantity: int

func _ready():
	loadData()


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



func loadData():
	var parentName = get_parent().get_name()

	var savePath = "user://Characters/" + player.entity_name + "/" + grid_container.name + "/" + parentName + "_saved_texture_data.txt"

	var file = File.new()

	if !file.file_exists(savePath):
		return

	if file.open(savePath, File.READ) != OK:
		return

	var path = file.get_line()
	var quantity_str = file.get_line()

	file.close()

	var holder = get_parent().get_node("TextureButton")

	if path == "":
		texture = null
		holder.quantity = 0
		return

	var loadedTexture = load(path)

	if loadedTexture != null:
		texture = loadedTexture
		holder.quantity = int(quantity_str)
	else:
		texture = null
		holder.quantity = 0
