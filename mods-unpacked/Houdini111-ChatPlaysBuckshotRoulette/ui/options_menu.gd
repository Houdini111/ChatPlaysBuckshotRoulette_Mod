class_name ChatPlaysOptionsMenu extends Node

const LOGNAME = "ChatPlaysBuckshotRoulette:options_menu"

const ChatPlaysModMain = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/mod_main.gd")
const TwitchBot = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/twitch/TwitchBot.gd")

var mod_main
var bot: TwitchBot
var menu_scene_root: Node
var menu_root: Node
var main_options_select: Node
var sub_options_select: Node
var menu_manager: MenuManager
var chat_plays_menu_node: Node

var finished_init := false
const CHAT_PLAYS_MENU_NAME = "Chat Plays"

var cursor_manager: CursorManager
var press_snd: AudioStreamPlayer2D
var hover_snd: AudioStreamPlayer2D
var menuTheme = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/themes/menuTheme.tres")

const CHAT_PLAYS_OPTIONS_MENU_SCENE = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/ui/chat_plays_options_menu.tscn") 

var uiCancelEventHolder: Array[InputEvent] = []
var backspaceTextEvent: InputEventKey = InputEventKey.new()
var deleteTextEvent: InputEventKey = InputEventKey.new()
var caretLeftTextEvent: InputEventKey = InputEventKey.new()
var caretRightTextEvent: InputEventKey = InputEventKey.new()
var selectAllTextEvent: InputEventWithModifiers = InputEventKey.new()
var copyTextEvent: InputEventWithModifiers = InputEventKey.new()
var pasteTextEvent: InputEventWithModifiers = InputEventKey.new()

var channelNameField: LineEdit
var botBeginAuthButton: Button
var botIsAuthorizedCheckbox: CheckBox
var defaultNameField: LineEdit
var actionVotePeriodField: SpinBox
var instructionsCooldownField: SpinBox
var user_code_panel: Panel
var user_code_label: Label

var config: ModConfig

func _init(_mod_main: ChatPlaysModMain, _bot: TwitchBot):
	self.mod_main = _mod_main
	self.bot = _bot
	
	self.bot.ListenToAuthStatus(BotAuthStatusChanged)
	
	backspaceTextEvent.keycode = Key.KEY_BACKSPACE
	deleteTextEvent.keycode = Key.KEY_DELETE
	caretLeftTextEvent.keycode = Key.KEY_LEFT
	caretRightTextEvent.keycode = Key.KEY_RIGHT
	selectAllTextEvent.keycode = Key.KEY_A
	selectAllTextEvent.ctrl_pressed = true
	copyTextEvent.keycode = Key.KEY_C
	copyTextEvent.ctrl_pressed = true
	pasteTextEvent.keycode = Key.KEY_V
	pasteTextEvent.ctrl_pressed = true
	
	Engine.register_singleton("ChatPlaysOptionsMenu", self)

func MakeMenuModifications(current_scene: Node) -> void:
	ModLoaderLog.info("Starting to make menu modifications", LOGNAME)
	if (current_scene == null || current_scene.name != "menu"):
		ModLoaderLog.info("No tree found or scene was not menu. Cancelling modifications.", LOGNAME)
		return
	menu_scene_root = current_scene
	menu_root = current_scene.find_child("menu ui");
	if (menu_root != null):
		main_options_select = menu_root.find_child("main screen")
		sub_options_select = menu_root.find_child("sub options select");

	ModLoaderLog.debug("menu_root found: %s. main_options_select found: %s  sub_options_select found: %s" % [menu_root != null, main_options_select != null, sub_options_select != null], LOGNAME)
	# Ready to begin instantiation
	if main_options_select != null && sub_options_select != null:
		do_options_menu_init(current_scene)
			
func ShowUserCodePopup(user_code: String) -> void:
	user_code_label.text = user_code
	user_code_panel.visible = true
	
func HideUserCodePopup() -> void:
	user_code_panel.visible = false

func do_options_menu_init(current_scene: Node) -> void:
	ModLoaderLog.info("Doing options menu init", LOGNAME)
	locate_sounds()
	locate_managers()
	inject_main_menu_options()
	inject_chat_plays_option()
	create_chat_plays_menu(current_scene)
	
	# TODO: Limit default name field to alpha characters

	load_config_into_field()

	ModLoaderLog.info("Options menu modifications complete", LOGNAME)
	chat_plays_menu_node.visible = false
	finished_init = true

func locate_sounds() -> void:
	ModLoaderLog.info("Locating sounds", LOGNAME)
	press_snd = menu_scene_root.find_child("speaker_press") as AudioStreamPlayer2D
	hover_snd = menu_scene_root.find_child("speaker_hover") as AudioStreamPlayer2D

func locate_managers() -> void:
	ModLoaderLog.info("Locating managers", LOGNAME)
	menu_manager = menu_scene_root.find_child("menu manager") as MenuManager;
	cursor_manager = menu_scene_root.find_child("cursor manager") as CursorManager;

func inject_main_menu_options() -> void:
	ModLoaderLog.info("Modifying main menu to include Chat Plays options", LOGNAME)
	var start_visual_node := main_options_select.find_child("button_start") as Label
	var multiplayer_visual_node := main_options_select.find_child("button_multiplayer") as Label
	var options_visual_node := main_options_select.find_child("button_options") as Label
	var credits_visual_node := main_options_select.find_child("button_credits") as Label
	var exit_visual_node := main_options_select.find_child("button_exit") as Label
	
	var visual_nodes = [start_visual_node, multiplayer_visual_node, options_visual_node, credits_visual_node, exit_visual_node]
	var nodes_found = visual_nodes.map(func(node): return node != null)
	if nodes_found.any(func(found): return !found):
		ModLoaderLog.error("Failed to find main menu options, %s" % JSON.stringify(nodes_found), LOGNAME)
		return
		
	var start_true_button := main_options_select.find_child("true button_start") as Button
	var multiplayer_true_button := main_options_select.find_child("true button_multiplayer") as Button
	var options_true_button := main_options_select.find_child("true button_options") as Button
	var credits_true_button := main_options_select.find_child("true button_credits") as Button
	var exit_true_button := main_options_select.find_child("true button_exit") as Button
	
	var true_buttons = [start_true_button, multiplayer_true_button, options_true_button, credits_true_button, exit_true_button]
	var buttons_found = true_buttons.map(func(node): return node != null)
	if buttons_found.any(func(found): return !found):
		ModLoaderLog.error("Failed to find main menu buttons, %s" % JSON.stringify(buttons_found), LOGNAME)
		return
		
	var start_button_class = start_true_button.get_child(0) as ButtonClass
	var multiplayer_button_class = multiplayer_true_button.get_child(0) as ButtonClass
	var options_button_class = options_true_button.get_child(0) as ButtonClass
	var credits_button_class = credits_true_button.get_child(0) as ButtonClass
	var exit_button_class = exit_true_button.get_child(0) as ButtonClass
		
	
	start_visual_node.set_text("START VANILLA")
	var start_size = start_true_button.get_size()
	# I wish there was a more programatic way of setting these but I can't find a good one
	#   So these were found with pure trial and error
	var new_width = start_size.x * 1.7
	var horizonal_shift = (new_width - start_size.x) * 4.5
	start_true_button.set_size(Vector2(new_width, start_size.y))
	var start_pos := start_visual_node.get_position()
	var start_btn_pos := start_true_button.get_position()
	start_btn_pos = Vector2(start_btn_pos.x - horizonal_shift, start_btn_pos.y)
	start_true_button.set_position(start_btn_pos)
	
	var chat_vs_dealer_visual_node = start_visual_node.duplicate() as Label
	chat_vs_dealer_visual_node.name = "button_chat vs dealer"
	chat_vs_dealer_visual_node.set_text("CHAT VS DEALER")
	main_options_select.add_child(chat_vs_dealer_visual_node)
	var chat_vs_dealer_true_button := start_true_button.duplicate() as Button
	main_options_select.add_child(chat_vs_dealer_true_button)
	chat_vs_dealer_true_button.name = "true button_chat vs dealer"
	var chat_vs_dealer_button_class := chat_vs_dealer_true_button.get_child(0) as ButtonClass
	chat_vs_dealer_button_class.name = "button class_chat vs dealer"
	chat_vs_dealer_button_class.ui = chat_vs_dealer_visual_node
	chat_vs_dealer_button_class.alias = "chat vs dealer"
	
	var streamer_vs_chat_visual_node = start_visual_node.duplicate() as Label
	streamer_vs_chat_visual_node.name = "button_streamer vs chat"
	streamer_vs_chat_visual_node.set_text("STREAMER VS CHAT")
	main_options_select.add_child(streamer_vs_chat_visual_node)
	var streamer_vs_chat_true_button := start_true_button.duplicate() as Button
	streamer_vs_chat_true_button.name = "true button_streamer vs chat"
	main_options_select.add_child(streamer_vs_chat_true_button)
	var streamer_vs_chat_button_class := streamer_vs_chat_true_button.get_child(0) as ButtonClass
	streamer_vs_chat_button_class.name = "button class_streamer vs chat"
	streamer_vs_chat_button_class.ui = streamer_vs_chat_visual_node
	streamer_vs_chat_button_class.alias = "streamer vs chat"
	
	
	var next_position := multiplayer_visual_node.get_position()
	var y_diff := next_position.y - start_pos.y
	
	
	var exit_pos := exit_visual_node.get_position()
	exit_visual_node.set_position(Vector2(exit_pos.x, exit_pos.y + y_diff))
	var credits_pos := credits_visual_node.get_position()
	credits_visual_node.set_position(Vector2(credits_pos.x, credits_pos.y + y_diff))
	var options_pos := options_visual_node.get_position()
	options_visual_node.set_position(Vector2(options_pos.x, options_pos.y + y_diff))
	var multiplayer_pos := multiplayer_visual_node.get_position()
	multiplayer_visual_node.set_position(Vector2(multiplayer_pos.x, multiplayer_pos.y + y_diff))
	streamer_vs_chat_visual_node.set_position(Vector2(start_pos.x, start_pos.y + y_diff))
	chat_vs_dealer_visual_node.set_position(Vector2(start_pos.x, start_pos.y))
	start_visual_node.set_position(Vector2(start_pos.x, start_pos.y - y_diff))
	
	var exit_btn_pos := exit_true_button.get_position()
	exit_true_button.set_position(Vector2(exit_btn_pos.x, exit_btn_pos.y + y_diff))
	var credits_btn_pos := credits_true_button.get_position()
	credits_true_button.set_position(Vector2(credits_btn_pos.x, credits_btn_pos.y + y_diff))
	var options_btn_pos := options_true_button.get_position()
	options_true_button.set_position(Vector2(options_btn_pos.x, options_btn_pos.y + y_diff))
	var multiplayer_btn_pos := multiplayer_true_button.get_position()
	multiplayer_true_button.set_position(Vector2(multiplayer_btn_pos.x, multiplayer_btn_pos.y + y_diff))
	streamer_vs_chat_true_button.set_position(Vector2(start_btn_pos.x, start_btn_pos.y + y_diff))
	chat_vs_dealer_true_button.set_position(Vector2(start_btn_pos.x, start_btn_pos.y))
	start_true_button.set_position(Vector2(start_btn_pos.x, start_btn_pos.y - y_diff))
	
	# Again, I wish there was a better way of settings these but I just had to use trial and error
	var chat_vs_dealer_size = chat_vs_dealer_true_button.get_size()
	chat_vs_dealer_size = Vector2(chat_vs_dealer_size.x * 1.1, chat_vs_dealer_size.y)
	chat_vs_dealer_true_button.set_size(chat_vs_dealer_size)
	var chat_vs_dealer_pos = chat_vs_dealer_true_button.get_position()
	chat_vs_dealer_pos = Vector2(chat_vs_dealer_pos.x - 10, chat_vs_dealer_pos.y)
	chat_vs_dealer_true_button.set_position(chat_vs_dealer_pos)
	var streamer_vs_chat_size = streamer_vs_chat_true_button.get_size()
	streamer_vs_chat_size = Vector2(streamer_vs_chat_size.x * 1.2, streamer_vs_chat_size.y)
	streamer_vs_chat_true_button.set_size(streamer_vs_chat_size)
	var streamer_vs_chat_pos = streamer_vs_chat_true_button.get_position()
	streamer_vs_chat_pos = Vector2(streamer_vs_chat_pos.x - 20, streamer_vs_chat_pos.y)
	streamer_vs_chat_true_button.set_position(streamer_vs_chat_pos)
	
	
	start_true_button.focus_neighbor_bottom = chat_vs_dealer_true_button.get_path()
	chat_vs_dealer_true_button.focus_neighbor_top = start_true_button.get_path()
	chat_vs_dealer_true_button.focus_neighbor_bottom = streamer_vs_chat_true_button.get_path()
	streamer_vs_chat_true_button.focus_neighbor_top = chat_vs_dealer_true_button.get_path()
	streamer_vs_chat_true_button.focus_neighbor_bottom = multiplayer_true_button.get_path()
	
	start_button_class.connect("is_pressed", _StartVanilla)
	chat_vs_dealer_button_class.connect("is_pressed", _StartChatVsDealer)
	streamer_vs_chat_button_class.connect("is_pressed", _StartStreamerVsChat)
	
	menu_manager.buttons.append(chat_vs_dealer_true_button)
	menu_manager.buttons.append(streamer_vs_chat_true_button)
	
	ModLoaderLog.info("Finished injecting new main menu options", LOGNAME)
	
	
func inject_chat_plays_option() -> void:
	ModLoaderLog.info("Modifying options menu to include Chat Plays choice", LOGNAME)
	var controller_option_visual_node = sub_options_select.find_child("button_controller") as Label
	var controller_true_button_node = sub_options_select.find_child("true button_controller") as Button
	var return_visual_node = sub_options_select.find_child("button_return") as Label
	var return_true_button_node = sub_options_select.find_child("true button_exit sub options") as Button

	if (controller_option_visual_node == null || controller_true_button_node == null):
		ModLoaderLog.error("Failed to find options select value for Controller to modify and duplicate", LOGNAME)
		return
	if (return_visual_node == null || return_true_button_node == null):
		ModLoaderLog.error("Failed to find options select value for Return to modify", LOGNAME)
		return
	ModLoaderLog.info("Successfully found options menu nodes. Beginning modifications.", LOGNAME)

	var chatplays_option_visual_node = controller_option_visual_node.duplicate() as Label
	chatplays_option_visual_node.name = "button_chat plays"
	sub_options_select.add_child(chatplays_option_visual_node)
	var chatplays_true_button_node = controller_true_button_node.duplicate() as Button
	chatplays_true_button_node.name = "true button_chat plays"
	sub_options_select.add_child(chatplays_true_button_node)
	var chatplays_button_class_node = chatplays_true_button_node.get_child(0) as ButtonClass
	chatplays_button_class_node.name = "button class_chat plays"
	chatplays_button_class_node.ui = chatplays_option_visual_node

	chatplays_option_visual_node.set_text("CHAT PLAYS")

	# Insert into options list
	controller_true_button_node.focus_neighbor_bottom = chatplays_true_button_node.get_path()
	chatplays_true_button_node.focus_neighbor_top = controller_true_button_node.get_path()
	chatplays_true_button_node.focus_neighbor_bottom = return_true_button_node.get_path()
	return_true_button_node.focus_neighbor_top = chatplays_true_button_node.get_path()

	# Calculate new menu option positions
	var controller_position = controller_option_visual_node.get_position()
	var controller_button_position = controller_true_button_node.get_position()
	var return_position = return_visual_node.get_position()
	var return_button_position = return_true_button_node.get_position()
	var y_offset = return_position.y - controller_position.y
	var return_new_position = Vector2(return_position.x, return_position.y + y_offset)
	var return_button_new_position = Vector2(return_button_position.x, return_button_position.y + y_offset)
	# Size could have needed to change, and position to match, but "Chat Plays" is the same width as "Controller". Convienient!
	var chatplays_visual_position = Vector2(controller_button_position.x, return_button_position.y)

	# Use new menu option positions
	return_visual_node.set_position(return_new_position)
	return_true_button_node.set_position(return_button_new_position)
	chatplays_option_visual_node.set_position(return_position)
	chatplays_true_button_node.set_position(chatplays_visual_position)

	# Add button to list so its emit can be handled
	menu_manager.buttons.append(chatplays_button_class_node)
	chatplays_button_class_node.connect("is_pressed", open_chat_plays_settings_menu)
	ModLoaderLog.info("Finished injecting new option menu option", LOGNAME)

func create_chat_plays_menu(current_scene: Node) -> void:
	ModLoaderLog.info("Adding Chat Plays configuration menu", LOGNAME)
	chat_plays_menu_node = CHAT_PLAYS_OPTIONS_MENU_SCENE.instantiate()
	menu_root.add_child(chat_plays_menu_node)

	chat_plays_menu_node.theme = menuTheme
	var menu_layout_root = chat_plays_menu_node.find_child("layout_root") as Container
	for input_field in menu_layout_root.find_children("", "LineEdit"):
		var cast_input_field = input_field as LineEdit
		assign_sounds(cast_input_field)

	var bottom_buttons = chat_plays_menu_node.find_child("Bottom Buttons") as VBoxContainer
	for bottom_button in bottom_buttons.get_children():
		if (bottom_button is Control):
			assign_sounds(bottom_button)

	findFields(chat_plays_menu_node, menu_layout_root)

	botBeginAuthButton.connect("pressed", BotBeginAuth)
	ModLoaderLog.info("Successfully added Chat Plays configuration menu", LOGNAME)

func assign_sounds(input_field: Control) -> void:
	input_field.connect("focus_entered", play_hover_sound)
#	input_field.connect("focus_exited", OnExit)
	input_field.connect("mouse_entered", play_hover_sound)
#	input_field.connect("mouse_exited", OnExit)
	if input_field.has_signal("pressed"):
		input_field.connect("pressed", play_press_sound)

func findFields(chat_plays_menu_node: Node, menu_layout_root: Container) -> void:
	ModLoaderLog.info("Finding Chat Plays config menu's control elements", LOGNAME)
	channelNameField = menu_layout_root.find_child("ChannelName") as LineEdit
	botBeginAuthButton = menu_layout_root.find_child("BeginBotAuthButton") as Button
	botIsAuthorizedCheckbox = menu_layout_root.find_child("BotAuthorizedCheckbox") as CheckBox
	defaultNameField = menu_layout_root.find_child("DefaultName") as LineEdit
	actionVotePeriodField = menu_layout_root.find_child("ActionVotePeriod") as SpinBox
	instructionsCooldownField = menu_layout_root.find_child("InstructionsCooldown") as SpinBox
	user_code_panel = chat_plays_menu_node.find_child("User Code Panel") as Panel
	user_code_label = chat_plays_menu_node.find_child("User Code Label") as Label
	ModLoaderLog.info("Finished finding Chat Plays config menu's control elements", LOGNAME)

func load_config_into_field() -> void:
	ModLoaderLog.info("Loading config data into Chat Plays config", LOGNAME)
	var mod_data = ModLoaderMod.get_mod_data(mod_main.MOD_ID)
	config = mod_data.current_config

	channelNameField.text = config.data['channel']
	botIsAuthorizedCheckbox.set_pressed_no_signal(bot.IsAuthorized())
	defaultNameField.text = config.data['defaultName']
	actionVotePeriodField.value = config.data['actionVotePeriod']
	instructionsCooldownField.value = config.data['instructionsCooldown']
	ModLoaderLog.info("Done loading config data into Chat Plays config", LOGNAME)

func open_chat_plays_settings_menu() -> void:
	ModLoaderLog.info("Opening Chat Plays menu", LOGNAME)
	menu_manager.lastScreen = menu_manager.currentScreen
	menu_manager.currentScreen = CHAT_PLAYS_MENU_NAME
	menu_manager.title.visible = false
	menu_manager.parent_suboptions.visible = false
	chat_plays_menu_node.visible = true

#	# TODO: Ensure only one connection
	var return_btn = chat_plays_menu_node.find_child("Return") as Button
	return_btn.pressed.connect(close_chat_plays_settings_menu)
	var save_btn = chat_plays_menu_node.find_child("Save") as Button
	save_btn.pressed.connect(save_settings)

	remap_inputs()

	var focus = chat_plays_menu_node.find_child("ChannelName", true) as LineEdit
	if (menu_manager.cursor.controller_active): focus.grab_focus()
	menu_manager.controller.previousFocus = focus

func close_chat_plays_settings_menu() -> void:
	ModLoaderLog.info("Closing Chat Plays menu", LOGNAME)
	chat_plays_menu_node.visible = false

	restore_inputs()

	menu_manager.Show("sub options")

func remap_inputs() -> void:
	# Disable ui_cancel events in this menu. Require the use of the actual UI.
	uiCancelEventHolder = InputMap.action_get_events("ui_cancel")
	InputMap.action_erase_events("ui_cancel")

	#Add normal text editor input maps
	InputMap.action_add_event("ui_text_backspace", backspaceTextEvent)
	InputMap.action_add_event("ui_text_delete", deleteTextEvent)
	InputMap.action_add_event("ui_text_caret_left", caretLeftTextEvent)
	InputMap.action_add_event("ui_text_caret_right", caretRightTextEvent)
	InputMap.action_add_event("ui_text_select_all", selectAllTextEvent)
	InputMap.action_add_event("ui_copy", copyTextEvent)
	InputMap.action_add_event("ui_paste", pasteTextEvent)

func restore_inputs() -> void:
	# Add ui_cancel back
	for cancelEvent in uiCancelEventHolder:
		InputMap.action_add_event("ui_cancel", cancelEvent)
	uiCancelEventHolder = []

	#Remove normal text editor input maps
	InputMap.action_erase_event("ui_text_backspace", backspaceTextEvent)
	InputMap.action_erase_event("ui_text_delete", deleteTextEvent)
	InputMap.action_erase_event("ui_text_caret_left", caretLeftTextEvent)
	InputMap.action_erase_event("ui_text_caret_right", caretRightTextEvent)
	InputMap.action_erase_event("ui_text_select_all", selectAllTextEvent)
	InputMap.action_erase_event("ui_copy", copyTextEvent)
	InputMap.action_erase_event("ui_paste", pasteTextEvent)

func play_hover_sound() -> void:
	hover_snd.play()

func play_press_sound() -> void:
	press_snd.play()

func BotAuthStatusChanged(authorized: bool) -> void:
	if is_instance_valid(botIsAuthorizedCheckbox):
		botIsAuthorizedCheckbox.set_pressed_no_signal(authorized)

func BotBeginAuth():
	bot.StartAuthFlow()

func save_settings() -> void:
	var config_data = {
		"channel": channelNameField.text,
		"defaultName": defaultNameField.text,
		"actionVotePeriod": actionVotePeriodField.value,
		"instructionsCooldown": instructionsCooldownField.value
	}
	if (ModLoaderConfig.has_config(mod_main.MOD_ID, "user")):
		var mod_data = ModLoaderMod.get_mod_data(mod_main.MOD_ID)
		var mod_config = mod_data.current_config
		mod_config.data = config_data
		ModLoaderConfig.update_config(mod_config)
	else:
		ModLoaderConfig.create_config(mod_main.MOD_ID, "user", config_data)
		var new_config = ModLoaderConfig.get_config(mod_main.MOD_ID, "user")
		ModLoaderConfig.set_current_config(new_config)
		
	# TODO: Send notification that save was successful

func _StartVanilla() -> void:
	mod_main.game_mode = ChatPlaysModMain.GAME_MODE.VANILLA

func _StartChatVsDealer() -> void:
	mod_main.game_mode = ChatPlaysModMain.GAME_MODE.CHAT_VS_DEALER
	menu_manager.Start()

func _StartStreamerVsChat() -> void:
	mod_main.game_mode = ChatPlaysModMain.GAME_MODE.STREAMER_VS_CHAT
	menu_manager.Start()
