
# Invoked only by the emulator fixture, after the production APK has been exported.
func run_upgrade_probe():
	await get_tree().create_timer(1).timeout
	hud.stack.get_node("업데이트").pressed.emit()
	for i in 180:
		await get_tree().create_timer(1).timeout
		match updates.stage:
			Updater.Stage.AVAILABLE:
				print("UPGRADE_PROBE release ",updates.target)
				hud.stack.get_node("내려받기").pressed.emit()
			Updater.Stage.READY:
				print("UPGRADE_PROBE opening Android installer")
				hud.stack.get_node("업데이트_설치").pressed.emit()
				return
			Updater.Stage.FAILED,Updater.Stage.CURRENT:
				printerr("UPGRADE_PROBE failed: ",updates.message)
				return
