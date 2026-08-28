extends FileDialog

func _ready():
	filters = PoolStringArray([
		"*.png ; PNG Images",
		"*.jpg ; JPG Images",
		"*.jpeg ; JPEG Images",
		"*.gif ; GIF Images",
		"*.bmp ; BMP Images",
		"*.webp ; WebP Images",
		"*.tga ; TGA Images",
		"*.tif ; TIFF Images",
		"*.tiff ; TIFF Images"
	])
