class_name PlatformServices
extends RefCounted
## Future network integrations. Explicitly unavailable results prevent fake success.
## Monetary values use integer minor units and an explicit currency, never floats.
signal notification_received(notification: Dictionary)
signal sync_finished(result: Dictionary)

func authentication() -> Dictionary:
	return {"provider":"device-local","user_id":"local-player","authenticated_online":false}

func sync_cloud_saves(_envelopes: Array) -> Dictionary:
	return {"ok":false,"reason":"cloud_saves_not_connected","conflicts":[],"acknowledged_revisions":[]}

func fetch_availability_policy() -> Dictionary:
	return {"ok":false,"reason":"signed_policy_service_not_connected","verified":false}

func scan_submission(_manifest: Dictionary) -> Dictionary:
	return {"ok":false,"reason":"isolated_scanning_not_connected","publish_allowed":false}

func request_purchase(game_id: String, product_id: String) -> Dictionary:
	return {"ok":false,"reason":"payments_not_connected","game_id":game_id,"product_id":product_id}

func request_rewarded_ad(game_id: String) -> Dictionary:
	return {"ok":false,"reason":"ads_not_connected","game_id":game_id,"reward_granted":false}

func create_challenge(game_id: String, score: int) -> Dictionary:
	return {"id":"local-"+str(Time.get_ticks_usec()),"game_id":game_id,"target_score":score,"status":"local_draft","recipient_id":null}

func revenue_account(developer_id: String) -> Dictionary:
	return {"developer_id":developer_id,"currency":"USD","qualified_plays":0,"play_seconds":0,"ad_revenue_minor":0,"purchase_revenue_minor":0,"share_basis_points":0,"balance_minor":0,"payouts":[],"connected":false}

func sync_events(_batch: Array) -> Dictionary:
	var result = {"ok":false,"reason":"offline_local_edition","acknowledged_ids":[]}
	sync_finished.emit(result)
	return result

func developer_identity(id: String) -> Dictionary:
	return {"developer_id":id,"verification":"unverified","suspended":false,"payout_account_connected":false}

func make_notification(kind: String, game_id: String, text: String) -> Dictionary:
	return {"id":str(Time.get_ticks_usec()),"kind":kind,"game_id":game_id,"text":text,"read":false,"delivery":"in_app_local"}
