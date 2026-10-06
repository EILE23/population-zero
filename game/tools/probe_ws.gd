extends SceneTree
## 실시간 방 통신 점검(헤드리스): 사이트의 방(wss://population.town/ws/poz/town)에 구경꾼으로 붙어 init 을 받나 — PozNet 이 쓰는 같은 WebSocketPeer·같은 형식
func _init() -> void:
	var ws := WebSocketPeer.new()
	print("WS connect=", ws.connect_to_url("wss://population.town/ws/poz/town"))
	for i in 600:
		await process_frame
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			print("WS got t=", (m as Dictionary).get("t", "?"), " users=", ((m as Dictionary).get("users", []) as Array).size(), " me=", (m as Dictionary).get("me", "?"))
			break
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED: print("WS closed code=", ws.get_close_code()); break
	ws.close()
	quit()
