extends Node

# Singleton for sound effects
@export var sound_map: Dictionary = {
	# Example: "key": preload("res://path/to/sound.ogg")
	#"jump": preload("res://sounds/jump.ogg"),
	#"shoot": preload("res://sounds/shoot.ogg"),
	#"explosion": preload("res://sounds/explosion.ogg")
}

# Function to play a sound effect by key
func play_sound(key: String):
	if not sound_map.has(key):
		print("Error: Sound key not found - ", key)
		return

	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = sound_map[key]
	audio_player.finished.connect(audio_player.queue_free)  # Free the player after playing
	add_child(audio_player)
	audio_player.play()

# Function to add a new sound effect to the map
func add_sound(key: String, sound: AudioStream):
	sound_map[key] = sound

# Function to remove a sound effect from the map, kinda useless since you can just go into the hash
func remove_sound(key: String):
	if sound_map.has(key):
		sound_map.erase(key)
	else:
		print("Error: Sound key not found - ", key)
		
# Examples using this code in anywhere in the code!
# Play the "jump" sound effect
# SoundEffects.play_sound("jump")
