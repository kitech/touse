#!/usr/bin/env python3
"""
Misskey API Mock Server for testing the C client
Requires: pip install flask
"""

from flask import Flask, request, jsonify
import json
import random
import string
from datetime import datetime

app = Flask(__name__)

TOKEN = "test_token_12345"
HOST_INFO = {
    "maintainerName": "Mock Server",
    "version": "2024.0.0-mock",
    "name": "Misskey Mock",
    "uri": "http://localhost:3000",
    "description": "Mock server for testing the C client",
    "langs": ["en", "ja", "zh"],
    "maxNoteTextLength": 3000,
    "federation": "all",
}

def gen_id():
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=16))

def check_auth():
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        token = auth_header[7:]
        return token == TOKEN
    return False

@app.route('/api/meta', methods=['POST'])
def api_meta():
    detail = request.get_json().get('detail', True) if request.get_json() else True
    return jsonify(HOST_INFO)

@app.route('/api/notes/timeline', methods=['POST'])
def api_timeline():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    limit = min(data.get('limit', 10), 5)
    notes = [{
        "id": gen_id(),
        "text": f"Mock note #{i+1}",
        "createdAt": datetime.now().isoformat(),
        "user": {"id": gen_id(), "name": "MockUser", "username": "mock"}
    } for i in range(limit)]
    return jsonify(notes)

@app.route('/api/notes/create', methods=['POST'])
def api_create_note():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    return jsonify({
        "createdNote": {
            "id": gen_id(),
            "text": data.get('text', ''),
            "createdAt": datetime.now().isoformat(),
        }
    })

@app.route('/api/i/notifications', methods=['POST'])
def api_notifications():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    limit = min(data.get('limit', 10), 5)
    notifications = [{
        "id": gen_id(),
        "type": random.choice(["follow", "reply", "renote"]),
        "createdAt": datetime.now().isoformat(),
        "user": {"id": gen_id(), "name": f"User{i}", "username": f"user{i}"}
    } for i in range(limit)]
    return jsonify(notifications)

@app.route('/api/notes', methods=['POST'])
def api_notes():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    limit = min(data.get('limit', 10), 5)
    notes = [{
        "id": gen_id(),
        "text": data.get('text', f"Note #{i+1}"),
        "createdAt": datetime.now().isoformat(),
        "userId": gen_id(),
        "user": {"id": gen_id(), "name": "MockUser", "username": "mock"}
    } for i in range(limit)]
    return jsonify(notes)

@app.route('/api/notes/show', methods=['POST'])
def api_notes_show():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    note_id = data.get('noteId', gen_id())
    return jsonify({
        "id": note_id,
        "text": "This is a mock note",
        "createdAt": datetime.now().isoformat(),
        "userId": gen_id(),
        "user": {"id": gen_id(), "name": "MockUser", "username": "mock"},
        "cw": None,
        "visibility": "public",
        "reactions": {},
        "renoteCount": 0,
        "repliesCount": 0
    })

@app.route('/api/notes/delete', methods=['POST'])
def api_notes_delete():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    note_id = data.get('noteId')
    if not note_id:
        return jsonify({"error": "noteId is required"}), 400
    return jsonify({"deleted": True, "noteId": note_id})

@app.route('/api/clips/list', methods=['POST'])
def api_clips_list():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify([{
        "id": gen_id(),
        "name": f"Clip {i+1}",
        "description": f"Description for clip {i+1}",
        "isPublic": random.choice([True, False]),
        "createdAt": datetime.now().isoformat(),
    } for i in range(3)])

@app.route('/api/clips/show', methods=['POST'])
def api_clips_show():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId', gen_id())
    return jsonify({
        "id": clip_id,
        "name": "Mock Clip",
        "description": "This is a mock clip",
        "isPublic": True,
        "createdAt": datetime.now().isoformat(),
        "notesCount": 5
    })

@app.route('/api/clips/create', methods=['POST'])
def api_clips_create():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    name = data.get('name')
    if not name:
        return jsonify({"error": "name is required"}), 400
    return jsonify({
        "id": gen_id(),
        "name": name,
        "description": data.get('description', ''),
        "isPublic": data.get('isPublic', False),
        "createdAt": datetime.now().isoformat(),
    })

@app.route('/api/clips/update', methods=['POST'])
def api_clips_update():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId', gen_id())
    return jsonify({
        "id": clip_id,
        "name": data.get('name', 'Updated Clip'),
        "description": data.get('description', ''),
        "isPublic": data.get('isPublic', False),
        "updatedAt": datetime.now().isoformat(),
    })

@app.route('/api/clips/delete', methods=['POST'])
def api_clips_delete():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId')
    if not clip_id:
        return jsonify({"error": "clipId is required"}), 400
    return jsonify({"deleted": True, "clipId": clip_id})

@app.route('/api/clips/add-note', methods=['POST'])
def api_clips_add_note():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId')
    note_id = data.get('noteId')
    if not clip_id or not note_id:
        return jsonify({"error": "clipId and noteId are required"}), 400
    return jsonify({"added": True, "clipId": clip_id, "noteId": note_id})

@app.route('/api/clips/remove-note', methods=['POST'])
def api_clips_remove_note():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId')
    note_id = data.get('noteId')
    if not clip_id or not note_id:
        return jsonify({"error": "clipId and noteId are required"}), 400
    return jsonify({"removed": True, "clipId": clip_id, "noteId": note_id})

@app.route('/api/clips/notes', methods=['POST'])
def api_clips_notes():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    clip_id = data.get('clipId')
    if not clip_id:
        return jsonify({"error": "clipId is required"}), 400
    limit = min(data.get('limit', 10), 5)
    return jsonify([{
        "id": gen_id(),
        "text": f"Note in clip #{i+1}",
        "createdAt": datetime.now().isoformat(),
        "user": {"id": gen_id(), "name": "MockUser", "username": "mock"}
    } for i in range(limit)])

@app.route('/api/drive', methods=['POST'])
def api_drive():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify({
        "capacity": 5368709120,
        "usage": 1073741824,
    })

@app.route('/api/drive/files', methods=['POST'])
def api_drive_files():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    limit = min(data.get('limit', 10), 5)
    files = [{
        "id": gen_id(),
        "name": f"file{i}.txt",
        "type": "text/plain",
        "size": random.randint(100, 10000),
        "createdAt": datetime.now().isoformat(),
    } for i in range(limit)]
    return jsonify(files)

@app.route('/api/drive/files/create', methods=['POST'])
def api_drive_files_create():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify({
        "id": gen_id(),
        "name": "uploaded_file.txt",
        "type": "text/plain",
        "size": 1024,
        "createdAt": datetime.now().isoformat(),
    })

@app.route('/api/drive/files/delete', methods=['POST'])
def api_drive_files_delete():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify({"deleted": True})

@app.route('/api/drive/files/update', methods=['POST'])
def api_drive_files_update():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    return jsonify({
        "id": data.get('fileId', gen_id()),
        "name": data.get('name', 'updated.txt'),
        "updatedAt": datetime.now().isoformat(),
    })

@app.route('/api/drive/files/find', methods=['POST'])
def api_drive_files_find():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify([])

@app.route('/api/drive/files/show', methods=['POST'])
def api_drive_files_show():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    file_id = data.get('fileId')
    url = data.get('url')
    if not file_id and not url:
        return jsonify({"error": "fileId or url required"}), 400
    return jsonify({
        "id": file_id or gen_id(),
        "name": "file_details.txt",
        "type": "text/plain",
        "size": 2048,
        "url": url or "https://example.com/files/" + gen_id(),
        "createdAt": datetime.now().isoformat(),
        "md5": ''.join(random.choices(string.hexdigits.lower(), k=32)),
    })

@app.route('/api/drive/files/upload-from-url', methods=['POST'])
def api_drive_files_upload_from_url():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    url = data.get('url')
    if not url:
        return jsonify({"error": "url required"}), 400
    return jsonify({
        "id": gen_id(),
        "name": url.split('/')[-1] or "downloaded_file.txt",
        "type": "application/octet-stream",
        "size": random.randint(1000, 100000),
        "url": url,
        "createdAt": datetime.now().isoformat(),
    })

@app.route('/api/drive/folders', methods=['POST'])
def api_drive_folders():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    limit = min(data.get('limit', 10), 5)
    folders = [{
        "id": gen_id(),
        "name": f"Folder {i+1}",
        "createdAt": datetime.now().isoformat(),
    } for i in range(limit)]
    return jsonify(folders)

@app.route('/api/drive/folders/create', methods=['POST'])
def api_drive_folders_create():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    return jsonify({
        "id": gen_id(),
        "name": data.get('name', 'New Folder'),
        "createdAt": datetime.now().isoformat(),
    })

@app.route('/api/drive/folders/delete', methods=['POST'])
def api_drive_folders_delete():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    return jsonify({"deleted": True})

@app.route('/api/drive/folders/update', methods=['POST'])
def api_drive_folders_update():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    return jsonify({
        "id": data.get('folderId', gen_id()),
        "name": data.get('name', 'Updated Folder'),
        "updatedAt": datetime.now().isoformat(),
    })

@app.route('/api/notes/translate', methods=['POST'])
def api_translate():
    if not check_auth():
        return jsonify({"error": "Authentication failed"}), 401
    data = request.get_json() or {}
    text = data.get('text', '')
    target_lang = data.get('targetLang', 'en')
    return jsonify({
        "text": f"[Translated to {target_lang}]: {text}",
        "sourceLang": "auto",
        "targetLang": target_lang,
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "token": TOKEN})

if __name__ == '__main__':
    print("=" * 50)
    print("  Misskey Mock Server")
    print("=" * 50)
    print(f"  Token: {TOKEN}")
    print(f"  URL: http://localhost:3000")
    print("=" * 50)
    print()
    print("Test client with:")
    print(f"  ./misskey_example localhost:3000 {TOKEN}")
    print()
    print("Endpoints supported:")
    print("  /api/meta")
    print("  /api/notes/timeline")
    print("  /api/notes/create")
    print("  /api/i/notifications")
    print("  /api/drive")
    print("  /api/drive/files")
    print("  /api/drive/files/create")
    print("  /api/drive/files/delete")
    print("  /api/drive/files/update")
    print("  /api/drive/files/find")
    print("  /api/drive/files/show")
    print("  /api/drive/files/upload-from-url")
    print("  /api/drive/folders")
    print("  /api/drive/folders/create")
    print("  /api/drive/folders/delete")
    print("  /api/drive/folders/update")
    print("  /api/notes/translate")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=3000, debug=False)
