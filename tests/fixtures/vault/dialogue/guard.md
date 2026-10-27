#in_game

## start
Guard: Stay away from [[Old Tower|the tower]]. Ask me about the **captain** or the [[Secret Note]].

- Tell me about the tower. -> tower
	- reveals: Tower Key
- Give me a potion. -> end
	- gives: test_potion x2
	- sets_flag: guard_gave_potions, met_guard
- Bye.
	- ends_memory: yes

## tower
Guard: The [[Guard Captain]] guards it.
It is very old.

Nobody goes there. Like everything in [[World|this world]].
