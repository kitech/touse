module main

import os
import misskey

fn truncate(s string, max_len int) string {
	if s.len <= max_len {
		return s
	}
	return s[..max_len] + '...'
}

fn main() {
	host := os.args[1] or { 'localhost:3000' }
	token := os.args[2] or { '' }
	
	println('===========================================')
	println('  Misskey V Client Test')
	println('===========================================')
	println('Host: ${host}')
	println('Token: ${if token.len > 0 { "set" } else { "not set" }}')
	println('')
	
	mut client := misskey.new(host) or {
		println('Failed to create client: ${err}')
		return
	}
	defer {
		client.free()
	}
	
	if token.len > 0 {
		client.set_token(token)
	}
	client.set_debug(false)
	
	println('--- Testing APIs ---')
	
	// meta (struct API)
	println('\n=== meta ===')
	meta := client.meta() or {
		println('Error: ${err}')
		return
	}
	println('  Name: ${meta.name}')
	println('  Version: ${meta.version}')
	println('  URI: ${meta.uri}')
	
	// notes_timeline (struct API)
	println('\n=== notes/timeline (include_local_renotes, limit=3) ===')
	notes := client.notes_timeline(3, true) or {
		println('Error: ${err}')
		return
	}
	println('  Got ${notes.len} notes')
	for i, note in notes {
		text := if note.text.len > 50 { note.text[..50] + '...' } else { note.text }
		println('  [$i] ${text}')
	}
	
	// notes_local_timeline (struct API) - only local posts
	println('\n=== notes/local-timeline (limit=3) ===')
	local_notes := client.notes_local_timeline(3) or {
		println('Error: ${err}')
		return
	}
	println('  Got ${local_notes.len} local notes')
	for i, note in local_notes {
		text := if note.text.len > 50 { note.text[..50] + '...' } else { note.text }
		println('  [$i] ${text} (renote=${note.is_renote})')
	}
	
	// notes_local_timeline_full with options
	println('\n=== notes/local-timeline full (with_files, limit=3) ===')
	full_opts := misskey.TimelineOptions{
		limit: 3
		with_files: true
		with_replies: false
		with_renotes: true
	}
	full_notes := client.notes_local_timeline_full(full_opts) or {
		println('Error: ${err}')
		return
	}
	println('  Got ${full_notes.len} notes')
	for i, note in full_notes {
		text := if note.text.len > 50 { note.text[..50] + '...' } else { note.text }
		println('  [$i] ${text}')
	}
	
	// notes_global_timeline (struct API)
	println('\n=== notes/global-timeline (limit=3) ===')
	global_notes := client.notes_global_timeline(3) or {
		println('Error: ${err}')
		return
	}
	println('  Got ${global_notes.len} global notes')
	for i, note in global_notes {
		text := if note.text.len > 50 { note.text[..50] + '...' } else { note.text }
		println('  [$i] ${text}')
	}
	
	// i/notifications (struct API)
	println('\n=== i/notifications (limit=3) ===')
	notifs := client.i_notifications(3) or {
		println('Error: ${err}')
		return
	}
	println('  Got ${notifs.len} notifications')
	for notif in notifs {
		println('  - ${notif.type_}: ${notif.message}')
	}
	
	// drive (struct API)
	println('\n=== drive ===')
	drive_info := client.drive() or {
		println('Error: ${err}')
		return
	}
	println('  Capacity: ${drive_info.capacity}')
	println('  Usage: ${drive_info.usage}')
	println('  Over quota: ${drive_info.is_over_quota}')
	
	// drive_files (struct API)
	println('\n=== drive/files (limit=3) ===')
	files := client.drive_files(3, '') or {
		println('Error: ${err}')
		return
	}
	println('  Got ${files.len} files')
	
	// drive_folders (struct API)
	println('\n=== drive/folders (limit=3) ===')
	folders := client.drive_folders(3, '') or {
		println('Error: ${err}')
		return
	}
	println('  Got ${folders.len} folders')
	
	// clips_list (struct API)
	println('\n=== clips/list ===')
	clips := client.clips_list() or {
		println('Error: ${err}')
		return
	}
	println('  Got ${clips.len} clips')
	for clip in clips {
		println('  - ${clip.name} (public: ${clip.is_public})')
	}
	
	// i (using do_request for raw JSON)
	println('\n=== i (raw) ===')
	result := client.do_request('i', '{}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 300))
	
	// notes/create (raw, if token set)
	if token.len > 0 {
		println('\n=== notes/create ===')
		create_result := client.notes_create_raw('Hello from Misskey V binding!', '', '') or {
			println('Error: ${err}')
			return
		}
		println(truncate(create_result, 300))
	}
	
	// announcements (using do_request)
	println('\n=== announcements ===')
	result = client.do_request('announcements', '{"limit":3}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 300))
	
	// stats (using do_request)
	println('\n=== stats ===')
	result = client.do_request('stats', '{}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 300))
	
	// notes/global-timeline
	println('\n=== notes/global-timeline (limit=2) ===')
	result = client.do_request('notes/global-timeline', '{"limit":2}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 300))
	
	// i/favorites
	println('\n=== i/favorites (limit=3) ===')
	result = client.do_request('i/favorites', '{"limit":3}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 300))
	
	// antenna/list
	println('\n=== antenna/list ===')
	result = client.do_request('antenna/list', '{}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 200))
	
	// channel/list
	println('\n=== channel/list ===')
	result = client.do_request('channel/list', '{}') or {
		println('Error: ${err}')
		return
	}
	println(truncate(result, 200))
	
	println('')
	println('===========================================')
	println('  Done')
	println('===========================================')
}
