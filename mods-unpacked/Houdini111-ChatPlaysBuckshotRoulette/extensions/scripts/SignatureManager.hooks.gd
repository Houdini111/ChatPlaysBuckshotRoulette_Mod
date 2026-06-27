class_name SignatureManagerHook extends Object

const HOOK_TARGET = "res://scripts/SignatureManager.gd"

const Scripter = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/Scripter.gd")

var scripter: Scripter

var enabled := false

func _init(_scripter: Scripter):
	self.scripter = _scripter
	ModLoaderMod.add_hook(AwaitPickup, HOOK_TARGET, "AwaitPickup")
	ModLoaderMod.add_hook(Input_Enter, HOOK_TARGET, "Input_Enter")

func AwaitPickup(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		scripter.PickupWaiverAndEnterName()
	
func Input_Enter(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		# TODO: Check to make sure name accepted. Don't want to fetch dealer name several times.
		scripter.WaiverNameEntered()
