extends SceneTree
func _initialize():run.call_deferred()
func run():
	var memory=load("res://scripts/login_memory.gd")
	var config={"server_url":"https://test.invalid","login_cache":"user://isolated-login-memory-test.json"}
	var password:="Test-only-password-123"
	assert(memory.save(config,"test-user",password,true))
	var saved:Dictionary=memory.read(config)
	assert(saved.password==password and saved.username=="test-user" and saved.remember)
	assert(not FileAccess.get_file_as_string(memory.path(config)).contains(password))
	config.server_url="https://other.invalid"
	assert(memory.read(config).is_empty())
	config.server_url="https://test.invalid"
	assert(memory.save(config,"test-user","",false))
	saved=memory.read(config)
	assert(saved.username=="test-user" and saved.password.is_empty() and not saved.remember)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(memory.path(config)))
	print("LOGIN_MEMORY_PASS encrypted roundtrip, endpoint isolation, unchecked clears password")
	quit()
