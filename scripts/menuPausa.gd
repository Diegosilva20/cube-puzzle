extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$PanelContainer/VBoxContainer/resume.mouse_filter = Button.MOUSE_FILTER_IGNORE
	$PanelContainer/VBoxContainer/pausemenu.mouse_filter = Button.MOUSE_FILTER_IGNORE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	testEsc()

func testEsc():
	if Input.is_action_just_pressed("esc") and !get_tree().paused:
		pause()
	elif Input.is_action_just_pressed("esc") and get_tree().paused:
		resume()

func resume():
	$PanelContainer/VBoxContainer/resume.mouse_filter = Button.MOUSE_FILTER_IGNORE
	$PanelContainer/VBoxContainer/pausemenu.mouse_filter = Button.MOUSE_FILTER_IGNORE
	get_tree().paused = false;
	$AnimationPlayer.play_backwards("new_animation")
	
func pause():
	$PanelContainer/VBoxContainer/resume.mouse_filter = Button.MOUSE_FILTER_STOP
	$PanelContainer/VBoxContainer/pausemenu.mouse_filter = Button.MOUSE_FILTER_STOP
	get_tree().paused = true;
	$AnimationPlayer.play("new_animation")
	

func _on_resume_pressed() -> void:
	resume()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	$PanelContainer/VBoxContainer/resume.mouse_filter = Button.MOUSE_FILTER_IGNORE
	$PanelContainer/VBoxContainer/pausemenu.mouse_filter = Button.MOUSE_FILTER_IGNORE
	get_tree().change_scene_to_file("res://cenas/ui/TelaInicial.tscn")
