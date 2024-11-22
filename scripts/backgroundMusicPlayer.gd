extends AudioStreamPlayer


func playMusic(music: AudioStream, volume = 0):
	if stream == music:
		return
		
	stream = music
	volume_db = volume
	play(0.0)
	
	print(music)
