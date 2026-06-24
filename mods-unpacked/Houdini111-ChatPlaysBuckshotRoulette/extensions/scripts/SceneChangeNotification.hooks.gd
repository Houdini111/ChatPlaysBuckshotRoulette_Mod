class_name SceneChangeHook extends Object

const HOOK_TARGET = "res://scripts/SceneChangeNotification.gd"

var mod_main

func _init(_mod_main):
	self.mod_main = _mod_main
	await ModLoaderMod.add_hook(MyReady, HOOK_TARGET, "_ready")

func MyReady(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	var parent_obj = chain.reference_object as Node
	while (parent_obj.get_parent() != null && parent_obj.get_parent().get_class() != "Window"):
		parent_obj = parent_obj.get_parent()
	mod_main.HandleSceneChange(parent_obj.name, parent_obj)
