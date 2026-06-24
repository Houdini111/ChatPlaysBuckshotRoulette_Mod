class_name SignatureManagerHook extends Object

const HOOK_TARGET = "res://scripts/SignatureManager.gd"

const Scripter = preload("res://mods-unpacked/Houdini111-ChatPlaysBuckshotRoulette/Scripter.gd")

var scripter: Scripter

func _init(_scripter: Scripter):
	ModLoaderMod.add_hook(AwaitPickup, HOOK_TARGET, "AwaitPickup")
	self.scripter = _scripter

func AwaitPickup(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	scripter.PickupWaiverAndEnterName()
