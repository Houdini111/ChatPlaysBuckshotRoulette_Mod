class_name CameraManagerHook extends Object

const HOOK_TARGET = "res://scripts/CameraManager.gd"

const LOGNAME = "ChatPlaysBuckshotRoulette:CameraManagerHook"

var enabled := false
var dealer_turn := false

const dealer_turn_socket_translation: Dictionary = {
	"home": "ChatDealerViewHome",
	"enemy": "ChatDealerViewEnemy",
	"health counter": "ChatDealerHealthCounter",
	"grow barrel": "ChatDealerGrowBarrel"
}

func _init():
	ModLoaderMod.add_hook(BeginLerp, HOOK_TARGET, "BeginLerp")
	ModLoaderMod.add_hook(LerpMovement, HOOK_TARGET, "LerpMovement")
	
func BeginLerp(chain: ModLoaderHookChain, lerpName : String):
	if !enabled || !dealer_turn:
		ModLoaderLog.debug("CameraManager hook disabled (enabled: %s) or not dealer_turn (dealer_turn: %s). Leaving lerp ('%s') alone" % [enabled, dealer_turn, lerpName], LOGNAME)
		await chain.execute_next_async([lerpName])
		return
	
	if lerpName == "ChatDealerViewHome":
		pass
	
	if dealer_turn_socket_translation.has(lerpName):
		var newName = dealer_turn_socket_translation[lerpName]
		ModLoaderLog.debug("CameraManager requested to move to hook '%s' replacing with '%s'" % [lerpName, newName], LOGNAME)
		await chain.execute_next_async([newName])
	else:
		ModLoaderLog.debug("CameraHook did not have a translation for '%s'. Using as is" % lerpName, LOGNAME)
		await chain.execute_next_async([lerpName])
	
func LerpMovement(chain: ModLoaderHookChain):
	await chain.execute_next_async()
	if enabled:
		# There's a bug in the game which doesn't affect the game but does affect me
		# The camera never realize it's reached its destination.
		# This is a patch to do that missing check
		var man := chain.reference_object as CameraManager
		if man.elapsed >= man.dur:
			man.moving = false
