class_name PlatformRepository
extends RefCounted
## Synchronous local-facing contract. A network adapter should hydrate/cache state
## before enabling the shell, and queue commands for asynchronous synchronization.
var data: Dictionary
var catalog: Array = []
var errors: Array = []
var progression: PlayerProgression

func save() -> void: push_error("Repository.save must be implemented")
func game(_id: String) -> Dictionary: return {}
func toggle(_bucket: String, _id: String) -> bool: return false
func opened(_id: String) -> void: pass
func unlock(_id: String) -> void: pass
func record(_event: String, _id: String = "", _payload: Dictionary = {}) -> void: pass
func recommendations() -> Array: return []
func leaderboard(_id: String) -> Array: return []
func save_draft(_index: int, _draft: Dictionary) -> void: pass
func available(_id: String) -> bool: return true
func eligible_catalog() -> Array: return catalog
func feed_order(_mode: String) -> Array: return []
func analytics(_id: String) -> Dictionary: return {}
func quality(_developer: String) -> Dictionary: return {}
