extends Control

# Buttons
@onready var RESPAWN = $MarginContainer/Panel/MarginContainer/VBoxContainer/buttons/Respawn
@onready var QUIT = $MarginContainer/Panel/MarginContainer/VBoxContainer/buttons/Quit

# settings
@onready var sensitivity_slider: HSlider = $MarginContainer/Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2/SensitivitySlider
@onready var master_slider: HSlider =$MarginContainer/Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2/Master
@onready var sfx_slider: HSlider = $MarginContainer/Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2/SFX
@onready var background_slider: HSlider = $MarginContainer/Panel/MarginContainer/VBoxContainer/VBoxContainer/HBoxContainer2/BackgroundSlider

var bus_master = AudioServer.get_bus_index("Master")
var bus_sfx = AudioServer.get_bus_index("SFX")
var bus_background = AudioServer.get_bus_index("Background")	

var volume_master_value
var volume_sfx_value
var volume_background_value

@export var player: CharacterBody3D

func _input(_event:InputEvent):
	if _event.is_action_pressed("ui_cancel"):
		toggleMenu()

func _ready():
	visible = false
	# TODO: DO THIS PROGRAMMATICALLY, USING AN ARRAY or ENUM THIS IS MADDENING the 2nd time aroudn
	# TODO: DO THIS PROGRAMMATICALLY, USING AN ARRAY or ENUM THIS IS MADDENING the 2nd time aroudn
	# TODO: DO THIS PROGRAMMATICALLY, USING AN ARRAY or ENUM THIS IS MADDENING the 2nd time aroudn
	# TODO: DO THIS PROGRAMMATICALLY, USING AN ARRAY, EXPORT whatever or ENUM THIS IS MADDENING the 2nd time aroudn	
	volume_master_value = db_to_linear(AudioServer.get_bus_volume_db(bus_master))
	volume_sfx_value = db_to_linear(AudioServer.get_bus_volume_db(bus_sfx))
	volume_background_value = db_to_linear(AudioServer.get_bus_volume_db(bus_background))
	
	# sliders
	master_slider.max_value = volume_master_value * 2
	sfx_slider.max_value = volume_sfx_value * 2
	background_slider.max_value = volume_background_value * 2

	# values
	master_slider.value = volume_master_value 
	sfx_slider.value = volume_sfx_value
	background_slider.value = volume_background_value

	if player:
		sensitivity_slider.max_value = player.mouse_sensitivity * 2
		sensitivity_slider.value = player.mouse_sensitivity

# TODO: refactor & use the emit on the signal exclusively. 
func toggleMenu():
	if self.visible == false: 
		self.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		player.current_state = player.state.STATIC
		player.menu_open.emit(true)
	else:
		self.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player.current_state = player.state.FREE
		player.menu_open.emit(false)

func _on_respawn_pressed():
	#SWITCH.disabled = true
	#RESPAWN.disabled = true
	#$TeamTimer.start()
	#toggleMenu()
	await get_tree().create_timer(0.2).timeout
	#player.die()

func _on_quit_pressed():
	get_tree().quit()	



func _on_sensitivity_slider_value_changed(value):
	player.mouse_sensitivity = value
	player.joystick_sensitivity = value

func _on_master_value_changed(value):
	AudioServer.set_bus_volume_db(bus_master, linear_to_db(value))

func _on_sfx_value_changed(value):
	AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(value))

func _on_background_value_changed(value):
	AudioServer.set_bus_volume_db(bus_background, linear_to_db(value))