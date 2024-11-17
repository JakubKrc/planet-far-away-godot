extends Node

enum GameState {MAIN_MENU, PLAYING, PAUSE_MENU, GAME_OVER}

enum States {
	IDLE,
	MOVING,
	JUMPING,
	FALLING,
	SHOOTING,
	CHASING
}

const states_names = ['IDLE','MOVING','JUMPING','FALLING','SHOOTING','CHASING']

var main
var game_state = GameState.MAIN_MENU;
var main_menu
var pause_menu
var death_menu
