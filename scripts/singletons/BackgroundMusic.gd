extends AudioStreamPlayer

# Singleton for background music
@export var music_map: Dictionary = {
	# Example: "key": preload("res://path/to/music.ogg")
	#"main_menu": preload("res://music/main_menu.ogg"),
	#"level_1": preload("res://music/level_1.ogg"),
	#"boss_battle": preload("res://music/boss_battle.ogg")
}

func _ready():
	# Play the default music (optional)
	if music_map.has("main_menu"):
		change_music("main_menu")

# Function to change the background music by key
func change_music(key: String):
	if not music_map.has(key):
		print("Error: Music key not found - ", key)
		return

	var new_music = music_map[key]
	if stream == new_music:
		return  # Don't restart the same music

	stream = new_music
	stream.loop = true  # Ensure the new music loops
	play()

# Function to stop the background music
func stop_music():
	stop()

# Function to add a new music track to the map
func add_music(key: String, music: AudioStream):
	music_map[key] = music

# Function to remove a music track from the map
func remove_music(key: String):
	if music_map.has(key):
		music_map.erase(key)
	else:
		print("Error: Music key not found - ", key)

# Examples to use this singleton
## Play the "main_menu" music
#BackgroundMusic.change_music("main_menu")
#
## Play the "level_1" music
#BackgroundMusic.change_music("level_1")
#
## Play the "boss_battle" music
#BackgroundMusic.change_music("boss_battle")
