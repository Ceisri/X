extends TextureRect

onready var player = $"../../../../.."

var savedTexture: Texture
var savedQuantity: int

func _ready():
	loadData()


func saveData():
	var parentName = get_parent().get_name()
	var folderPath = "user://Characters/" + player.entity_name + "/"
	var savePath = folderPath + parentName + "_saved_texture_data.txt"

	var dir = Directory.new()
	if !dir.dir_exists(folderPath):
		dir.make_dir_recursive(folderPath)

	var file = File.new()
	if file.open(savePath, File.WRITE) != OK:
		return

	savedTexture = texture
	savedQuantity = get_parent().quantity

	if savedTexture != null:
		file.store_line(savedTexture.get_path())
	else:
		file.store_line("")

	file.store_line(str(savedQuantity))
	file.close()

	print(savePath)


func loadData():
	var parentName = get_parent().get_name()
	var savePath = "user://Characters/" + player.entity_name + "/" + parentName + "_saved_texture_data.txt"

	var file = File.new()

	if !file.file_exists(savePath):
		return

	if file.open(savePath, File.READ) != OK:
		return

	var path = file.get_line()
	var quantity_str = file.get_line()

	file.close()

	print(savePath)

	if path != "":
		var loadedTexture = load(path)
		if loadedTexture != null:
			texture = loadedTexture
			get_parent().quantity = int(quantity_str)
