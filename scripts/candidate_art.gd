extends RefCounted
static var textures: Dictionary={}
static func texture(path: String) -> Texture2D:
	if not textures.has(path):
		if path.get_extension().to_lower() in ["res","tres"]:
			var resource=load(path)
			if not resource is Texture2D:return null
			textures[path]=resource
		else:
			var image := Image.load_from_file(path)
			if image==null:return null
			textures[path]=ImageTexture.create_from_image(image)
	return textures[path]
