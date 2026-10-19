extends RefCounted
static var textures: Dictionary={}
static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var image := Image.load_from_file(path)
		if image==null:return null
		textures[path]=ImageTexture.create_from_image(image)
	return textures[path]
