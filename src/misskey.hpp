#ifndef MISSKEY_API_HPP
#define MISSKEY_API_HPP

#include <string>
#include <vector>
#include <optional>
#include <stdexcept>
#include <cstdint>

extern "C" {
#include "misskey_client.h"
}

namespace misskey {

struct User {
    std::string id;
    std::string name;
    std::string username;
    std::string host;
    std::string avatar_url;
    std::string avatar_blurhash;
    bool is_bot = false;
    bool is_cat = false;
    
    User() = default;
    User(const MisskeyUser& u) {
        id = u.id;
        name = u.name;
        username = u.username;
        host = u.host;
        avatar_url = u.avatar_url;
        avatar_blurhash = u.avatar_blurhash;
        is_bot = u.is_bot != 0;
        is_cat = u.is_cat != 0;
    }
};

struct Note {
    std::string id;
    std::string created_at;
    std::string text;
    std::string cw;
    std::string user_id;
    std::string reply_id;
    std::string renote_id;
    std::string channel_id;
    std::string uri;
    std::string url;
    bool local_only = false;
    int reactions_count = 0;
    int replies_count = 0;
    int renote_count = 0;
    std::string reaction_emojis;
    User user;
    
    Note() = default;
    Note(const MisskeyNote& n) {
        id = n.id;
        created_at = n.created_at;
        text = n.text;
        cw = n.cw;
        user_id = n.user_id;
        reply_id = n.reply_id;
        renote_id = n.renote_id;
        channel_id = n.channel_id;
        uri = n.uri;
        url = n.url;
        local_only = n.local_only != 0;
        reactions_count = n.reactions_count;
        replies_count = n.replies_count;
        renote_count = n.renote_count;
        reaction_emojis = n.reaction_emojis;
        user = User(n.user);
    }
};

struct Notification {
    std::string id;
    std::string created_at;
    std::string type;
    std::string user_id;
    std::string user_name;
    std::string note_id;
    std::string reaction;
    std::string message;
    User user;
    
    Notification() = default;
    Notification(const MisskeyNotification& n) {
        id = n.id;
        created_at = n.created_at;
        type = n.type;
        user_id = n.user_id;
        user_name = n.user_name;
        note_id = n.note_id;
        reaction = n.reaction;
        message = n.message;
        user = User(n.user);
    }
};

struct DriveFile {
    std::string id;
    std::string created_at;
    std::string name;
    std::string type;
    std::string md5;
    size_t size = 0;
    std::string url;
    std::string thumbnail_url;
    std::string folder_id;
    std::string user_id;
    bool is_sensitive = false;
    
    DriveFile() = default;
    DriveFile(const MisskeyDriveFile& f) {
        id = f.id;
        created_at = f.created_at;
        name = f.name;
        type = f.type;
        md5 = f.md5;
        size = f.size;
        url = f.url;
        thumbnail_url = f.thumbnail_url;
        folder_id = f.folder_id;
        user_id = f.user_id;
        is_sensitive = f.is_sensitive != 0;
    }
};

struct DriveFolder {
    std::string id;
    std::string created_at;
    std::string name;
    std::string parent_id;
    int folders_count = 0;
    int files_count = 0;
    
    DriveFolder() = default;
    DriveFolder(const MisskeyDriveFolder& f) {
        id = f.id;
        created_at = f.created_at;
        name = f.name;
        parent_id = f.parent_id;
        folders_count = f.folders_count;
        files_count = f.files_count;
    }
};

struct DriveInfo {
    int capacity = 0;
    int usage = 0;
    bool is_over_quota = false;
    int inc_capacity = 0;
    
    DriveInfo() = default;
    DriveInfo(const MisskeyDriveInfo& d) {
        capacity = d.capacity;
        usage = d.usage;
        is_over_quota = d.drive_usage_over_quota != 0;
        inc_capacity = d.inc_capacity;
    }
};

struct TranslateResult {
    std::string text;
    std::string source_lang;
    std::string target_lang;
    
    TranslateResult() = default;
    TranslateResult(const MisskeyTranslateResult& r) {
        text = r.text;
        source_lang = r.source_lang;
        target_lang = r.target_lang;
    }
};

struct Clip {
    std::string id;
    std::string created_at;
    std::string name;
    std::string description;
    bool is_public = false;
    int notes_count = 0;
    
    Clip() = default;
    Clip(const MisskeyClip& c) {
        id = c.id;
        created_at = c.created_at;
        name = c.name;
        description = c.description;
        is_public = c.is_public != 0;
        notes_count = c.notes_count;
    }
};

struct Meta {
    std::string name;
    std::string version;
    std::string uri;
    std::string description;
    std::string maintainer_name;
    std::string maintainer_email;
    std::vector<std::string> langs;
    std::string mascot_image_url;
    std::string banner_url;
    int max_note_text_length = 3000;
    bool enable_emoji_reactions = true;
    int drive_capacity = 0;
    
    Meta() = default;
    Meta(const MisskeyMeta& m) {
        name = m.name;
        version = m.version;
        uri = m.uri;
        description = m.description;
        maintainer_name = m.maintainer_name;
        maintainer_email = m.maintainer_email;
        enable_emoji_reactions = m.enable_emoji_reactions != 0;
        max_note_text_length = m.max_note_text_length;
        drive_capacity = m.drive_capacity;
    }
};

class MisskeyApi {
public:
    enum class Error {
        ok = 0,
        invalid_param = 1,
        network = 2,
        http = 3,
        json = 4,
        auth = 5,
        alloc = 6,
        unknown = 7
    };

    struct Exception : public std::runtime_error {
        Error code;
        Exception(Error c, const std::string& msg) 
            : std::runtime_error(msg), code(c) {}
    };

    struct DownloadOptions {
        std::string url;
        std::string output_path;
        int64_t resume_from = 0;
        bool follow_redirects = true;
    };

private:
    MisskeyClient* client_ = nullptr;

    static std::string error_to_string(Error err) {
        switch (err) {
            case Error::ok: return "OK";
            case Error::invalid_param: return "Invalid parameter";
            case Error::network: return "Network error";
            case Error::http: return "HTTP error";
            case Error::json: return "JSON parse error";
            case Error::auth: return "Authentication error";
            case Error::alloc: return "Memory allocation error";
            case Error::unknown: return "Unknown error";
            default: return "Unknown";
        }
    }

    void check_error(int err, const std::string& context) {
        if (err != 0) {
            throw Exception(static_cast<Error>(err), 
                context + ": " + error_to_string(static_cast<Error>(err)));
        }
    }

public:
    explicit MisskeyApi(const std::string& host) {
        client_ = misskey_client_new(host.c_str());
        if (!client_) {
            throw std::runtime_error("Failed to create client");
        }
    }

    ~MisskeyApi() {
        if (client_) {
            misskey_client_free(client_);
            client_ = nullptr;
        }
    }

    MisskeyApi(const MisskeyApi&) = delete;
    MisskeyApi& operator=(const MisskeyApi&) = delete;

    MisskeyApi(MisskeyApi&& other) noexcept : client_(other.client_) {
        other.client_ = nullptr;
    }

    MisskeyApi& operator=(MisskeyApi&& other) noexcept {
        if (this != &other) {
            if (client_) {
                misskey_client_free(client_);
            }
            client_ = other.client_;
            other.client_ = nullptr;
        }
        return *this;
    }

    void set_token(const std::string& token) {
        misskey_client_set_token(client_, token.c_str());
    }

    void set_timeout(int seconds) {
        misskey_client_set_timeout(client_, seconds);
    }

    void set_debug(bool enable) {
        misskey_request_set_debug(client_, enable ? 1 : 0);
    }

    std::string get_last_error() {
        long http_code = 0;
        char* error_detail = nullptr;
        misskey_client_get_last_error(client_, &http_code, &error_detail);
        std::string result;
        if (http_code > 0) {
            result = "HTTP " + std::to_string(http_code);
        }
        if (error_detail && error_detail[0]) {
            if (!result.empty()) result += " - ";
            result += error_detail;
        }
        return result;
    }

    Meta meta() {
        MisskeyMeta m;
        misskey_meta_init(&m);
        int err = misskey_meta(client_, &m);
        check_error(err, "meta");
        return Meta(m);
    }

    std::vector<Note> notes_timeline(int limit = 10, bool local = false) {
        MisskeyNote* notes = nullptr;
        int count = 0;
        int err = misskey_notes_timeline(client_, limit, local ? 1 : 0, &notes, &count);
        check_error(err, "notes_timeline");
        
        std::vector<Note> result;
        for (int i = 0; i < count; i++) {
            result.push_back(Note(notes[i]));
        }
        misskey_free_notes(client_, notes, count);
        return result;
    }

    Note notes_create(const std::string& text,
                     const std::optional<std::string>& reply_id = std::nullopt,
                     const std::optional<std::string>& renote_id = std::nullopt) {
        MisskeyNote note;
        misskey_note_init(&note);
        int err = misskey_notes_create(client_, text.c_str(),
            reply_id ? reply_id->c_str() : nullptr,
            renote_id ? renote_id->c_str() : nullptr,
            &note);
        check_error(err, "notes_create");
        return Note(note);
    }

    Note notes_show(const std::string& note_id) {
        MisskeyNote note;
        misskey_note_init(&note);
        int err = misskey_notes_show(client_, note_id.c_str(), &note);
        check_error(err, "notes_show");
        return Note(note);
    }

    void notes_delete(const std::string& note_id) {
        char deleted_id[32] = {0};
        int err = misskey_notes_delete(client_, note_id.c_str(), deleted_id);
        check_error(err, "notes_delete");
    }

    std::vector<Note> notes(const std::optional<std::string>& text = std::nullopt,
                           const std::optional<std::string>& reply_id = std::nullopt,
                           const std::optional<std::string>& renote_id = std::nullopt,
                           const std::optional<std::string>& channel_id = std::nullopt,
                           int limit = 10, int offset = 0,
                           const std::optional<std::string>& user_id = std::nullopt,
                           bool local_only = false, bool reply = false,
                           bool renote = false, bool with_files = false,
                           const std::optional<std::string>& since_id = std::nullopt,
                           const std::optional<std::string>& until_id = std::nullopt) {
        MisskeyNote* notes = nullptr;
        int count = 0;
        int err = misskey_notes(client_,
            text ? text->c_str() : nullptr,
            reply_id ? reply_id->c_str() : nullptr,
            renote_id ? renote_id->c_str() : nullptr,
            channel_id ? channel_id->c_str() : nullptr,
            limit, offset,
            user_id ? user_id->c_str() : nullptr,
            local_only ? 1 : 0, reply ? 1 : 0, renote ? 1 : 0, with_files ? 1 : 0,
            since_id ? since_id->c_str() : nullptr,
            until_id ? until_id->c_str() : nullptr,
            &notes, &count);
        check_error(err, "notes");
        
        std::vector<Note> result;
        for (int i = 0; i < count; i++) {
            result.push_back(Note(notes[i]));
        }
        misskey_free_notes(client_, notes, count);
        return result;
    }

    std::vector<Notification> i_notifications(int limit = 10) {
        MisskeyNotification* notifications = nullptr;
        int count = 0;
        int err = misskey_i_notifications(client_, limit, &notifications, &count);
        check_error(err, "i_notifications");
        
        std::vector<Notification> result;
        for (int i = 0; i < count; i++) {
            result.push_back(Notification(notifications[i]));
        }
        misskey_free_notifications(client_, notifications, count);
        return result;
    }

    DriveInfo drive() {
        MisskeyDriveInfo info;
        misskey_drive_info_init(&info);
        int err = misskey_drive(client_, &info);
        check_error(err, "drive");
        return DriveInfo(info);
    }

    std::vector<DriveFile> drive_files(int limit = 10, const std::optional<std::string>& folder_id = std::nullopt) {
        MisskeyDriveFile* files = nullptr;
        int count = 0;
        int err = misskey_drive_files(client_, limit, folder_id ? folder_id->c_str() : nullptr, &files, &count);
        check_error(err, "drive_files");
        
        std::vector<DriveFile> result;
        for (int i = 0; i < count; i++) {
            result.push_back(DriveFile(files[i]));
        }
        misskey_free_drive_files(client_, files, count);
        return result;
    }

    DriveFile drive_files_create(const std::string& file_path,
                                const std::optional<std::string>& folder_id = std::nullopt,
                                const std::optional<std::string>& name = std::nullopt) {
        MisskeyDriveFile file;
        misskey_drive_file_init(&file);
        int err = misskey_drive_files_create(client_, file_path.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            name ? name->c_str() : nullptr,
            &file);
        check_error(err, "drive_files_create");
        return DriveFile(file);
    }

    void drive_files_delete(const std::string& file_id) {
        char deleted_id[32] = {0};
        int err = misskey_drive_files_delete(client_, file_id.c_str(), deleted_id);
        check_error(err, "drive_files_delete");
    }

    DriveFile drive_files_update(const std::string& file_id,
                                const std::optional<std::string>& folder_id = std::nullopt,
                                const std::optional<std::string>& name = std::nullopt) {
        MisskeyDriveFile file;
        misskey_drive_file_init(&file);
        int err = misskey_drive_files_update(client_, file_id.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            name ? name->c_str() : nullptr,
            &file);
        check_error(err, "drive_files_update");
        return DriveFile(file);
    }

    std::vector<DriveFile> drive_files_find(const std::string& hash) {
        MisskeyDriveFile* files = nullptr;
        int count = 0;
        int err = misskey_drive_files_find(client_, hash.c_str(), &files, &count);
        check_error(err, "drive_files_find");
        
        std::vector<DriveFile> result;
        for (int i = 0; i < count; i++) {
            result.push_back(DriveFile(files[i]));
        }
        misskey_free_drive_files(client_, files, count);
        return result;
    }

    DriveFile drive_files_show(const std::optional<std::string>& file_id = std::nullopt,
                              const std::optional<std::string>& url = std::nullopt) {
        MisskeyDriveFile file;
        misskey_drive_file_init(&file);
        int err = misskey_drive_files_show(client_,
            file_id ? file_id->c_str() : nullptr,
            url ? url->c_str() : nullptr,
            &file);
        check_error(err, "drive_files_show");
        return DriveFile(file);
    }

    DriveFile drive_files_upload_from_url(const std::string& url,
                                         const std::optional<std::string>& folder_id = std::nullopt,
                                         bool is_sensitive = false,
                                         const std::optional<std::string>& comment = std::nullopt) {
        MisskeyDriveFile file;
        misskey_drive_file_init(&file);
        int err = misskey_drive_files_upload_from_url(client_, url.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            is_sensitive ? 1 : 0,
            comment ? comment->c_str() : nullptr,
            &file);
        check_error(err, "drive_files_upload_from_url");
        return DriveFile(file);
    }

    int drive_files_download(const DownloadOptions& opts) {
        MisskeyDownloadOptions c_opts{};
        c_opts.url = opts.url.empty() ? nullptr : opts.url.c_str();
        c_opts.output_path = opts.output_path.empty() ? nullptr : opts.output_path.c_str();
        c_opts.write_cb = nullptr;
        c_opts.write_userdata = nullptr;
        c_opts.resume_from = static_cast<long>(opts.resume_from);
        c_opts.follow_redirects = opts.follow_redirects ? 1 : 0;

        long http_code = 0;
        int err = misskey_drive_files_download(client_, nullptr, &c_opts, &http_code, nullptr);
        check_error(err, "drive_files_download");
        return static_cast<int>(http_code);
    }

    std::vector<DriveFolder> drive_folders(int limit = 10,
                                           const std::optional<std::string>& folder_id = std::nullopt) {
        MisskeyDriveFolder* folders = nullptr;
        int count = 0;
        int err = misskey_drive_folders(client_, limit,
            folder_id ? folder_id->c_str() : nullptr,
            &folders, &count);
        check_error(err, "drive_folders");
        
        std::vector<DriveFolder> result;
        for (int i = 0; i < count; i++) {
            result.push_back(DriveFolder(folders[i]));
        }
        misskey_free_drive_folders(client_, folders, count);
        return result;
    }

    DriveFolder drive_folders_create(const std::string& name,
                                    const std::optional<std::string>& parent_id = std::nullopt) {
        MisskeyDriveFolder folder;
        misskey_drive_folder_init(&folder);
        int err = misskey_drive_folders_create(client_, name.c_str(),
            parent_id ? parent_id->c_str() : nullptr,
            &folder);
        check_error(err, "drive_folders_create");
        return DriveFolder(folder);
    }

    void drive_folders_delete(const std::string& folder_id) {
        char deleted_id[32] = {0};
        int err = misskey_drive_folders_delete(client_, folder_id.c_str(), deleted_id);
        check_error(err, "drive_folders_delete");
    }

    DriveFolder drive_folders_update(const std::string& folder_id,
                                    const std::optional<std::string>& name = std::nullopt,
                                    const std::optional<std::string>& parent_id = std::nullopt) {
        MisskeyDriveFolder folder;
        misskey_drive_folder_init(&folder);
        int err = misskey_drive_folders_update(client_, folder_id.c_str(),
            name ? name->c_str() : nullptr,
            parent_id ? parent_id->c_str() : nullptr,
            &folder);
        check_error(err, "drive_folders_update");
        return DriveFolder(folder);
    }

    TranslateResult translate(const std::string& note_id,
                            const std::string& target_lang) {
        MisskeyTranslateResult result;
        misskey_translate_result_init(&result);
        int err = misskey_translate(client_, note_id.c_str(), target_lang.c_str(), &result);
        check_error(err, "translate");
        return TranslateResult(result);
    }

    std::vector<Clip> clips_list() {
        MisskeyClip* clips = nullptr;
        int count = 0;
        int err = misskey_clips_list(client_, &clips, &count);
        check_error(err, "clips_list");
        
        std::vector<Clip> result;
        for (int i = 0; i < count; i++) {
            result.push_back(Clip(clips[i]));
        }
        misskey_free_clips(client_, clips, count);
        return result;
    }

    Clip clips_show(const std::string& clip_id) {
        MisskeyClip clip;
        misskey_clip_init(&clip);
        int err = misskey_clips_show(client_, clip_id.c_str(), &clip);
        check_error(err, "clips_show");
        return Clip(clip);
    }

    Clip clips_create(const std::string& name,
                     const std::optional<std::string>& description = std::nullopt,
                     bool is_public = false) {
        MisskeyClip clip;
        misskey_clip_init(&clip);
        int err = misskey_clips_create(client_, name.c_str(),
            description ? description->c_str() : nullptr,
            is_public ? 1 : 0,
            &clip);
        check_error(err, "clips_create");
        return Clip(clip);
    }

    Clip clips_update(const std::string& clip_id,
                     const std::optional<std::string>& name = std::nullopt,
                     const std::optional<std::string>& description = std::nullopt,
                     bool is_public = false) {
        MisskeyClip clip;
        misskey_clip_init(&clip);
        int err = misskey_clips_update(client_, clip_id.c_str(),
            name ? name->c_str() : nullptr,
            description ? description->c_str() : nullptr,
            is_public ? 1 : 0,
            &clip);
        check_error(err, "clips_update");
        return Clip(clip);
    }

    void clips_delete(const std::string& clip_id) {
        char deleted_id[32] = {0};
        int err = misskey_clips_delete(client_, clip_id.c_str(), deleted_id);
        check_error(err, "clips_delete");
    }

    std::vector<Note> clips_notes(const std::string& clip_id, int limit = 10) {
        MisskeyNote* notes = nullptr;
        int count = 0;
        int err = misskey_clips_notes(client_, clip_id.c_str(), limit, &notes, &count);
        check_error(err, "clips_notes");
        
        std::vector<Note> result;
        for (int i = 0; i < count; i++) {
            result.push_back(Note(notes[i]));
        }
        misskey_free_notes(client_, notes, count);
        return result;
    }

    void clips_add_note(const std::string& clip_id, const std::string& note_id) {
        int err = misskey_clips_add_note(client_, clip_id.c_str(), note_id.c_str());
        check_error(err, "clips_add_note");
    }

    void clips_remove_note(const std::string& clip_id, const std::string& note_id) {
        int err = misskey_clips_remove_note(client_, clip_id.c_str(), note_id.c_str());
        check_error(err, "clips_remove_note");
    }
};

}

#endif
