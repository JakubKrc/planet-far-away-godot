extends AudioStreamPlayer

# Routed through the music bus so the settings slider affects it without
# touching Master, which would drag sound effects along too.
func _ready():
	bus = "music"

func playMusic(music: AudioStream, volume = 0):
	if stream == music:
		return
		
	stream = music
	volume_db = volume
	play(0.0)
