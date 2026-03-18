#ifndef MISSKEY_API_HPP
#define MISSKEY_API_HPP

#include <string>
#include <optional>
#include <vector>
#include <stdexcept>
#include <cstdint>

extern "C" {
#include "misskey_client.h"
}

namespace misskey {

struct DriveFile {
    std::string id;
    std::string name;
    std::string type;
    int64_t size;
    std::string url;
    std::string thumbnail_url;
    std::string md5;
    std::string created_at;
};

struct DriveFolder {
    std::string id;
    std::string name;
    std::string parent_id;
    std::string created_at;
    int folders_count;
    int files_count;
};

struct DriveInfo {
    int64_t capacity;
    int64_t usage;
};

struct Note {
    std::string id;
    std::string text;
    std::string created_at;
    std::string user_id;
    std::string user_name;
    std::string user_username;
};

struct Notification {
    std::string id;
    std::string type;
    std::string created_at;
    std::string user_id;
    std::string user_name;
    std::string user_username;
};

struct TranslateResult {
    std::string text;
    std::string source_lang;
    std::string target_lang;
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
    MisskeyClient* client_;
    std::string last_response_;

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

    std::string meta(bool detail = false) {
        char* resp = nullptr;
        int err = misskey_meta(client_, &resp);
        if (err != 0) {
            check_error(err, "meta");
        }
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string notes_timeline(int limit = 10, bool local = false) {
        char* resp = nullptr;
        int err = misskey_notes_timeline(client_, limit, local ? 1 : 0, &resp);
        check_error(err, "notes_timeline");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string notes_create(const std::string& text,
                            const std::optional<std::string>& reply_id = std::nullopt,
                            const std::optional<std::string>& renote_id = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_notes_create(client_, text.c_str(),
            reply_id ? reply_id->c_str() : nullptr,
            renote_id ? renote_id->c_str() : nullptr,
            &resp);
        check_error(err, "notes_create");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string i_notifications(int limit = 10) {
        char* resp = nullptr;
        int err = misskey_i_notifications(client_, limit, &resp);
        check_error(err, "i_notifications");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive() {
        char* resp = nullptr;
        int err = misskey_drive(client_, &resp);
        check_error(err, "drive");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    DriveInfo drive_info() {
        char* resp = nullptr;
        int err = misskey_drive(client_, &resp);
        check_error(err, "drive");
        
        DriveInfo info{};
        if (resp) {
            last_response_ = resp;
            misskey_free_string(client_, resp);
        }
        return info;
    }

    std::string drive_files(int limit = 10, int folder_id = 0) {
        char* resp = nullptr;
        int err = misskey_drive_files(client_, limit, folder_id, &resp);
        check_error(err, "drive_files");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_create(const std::string& file_path,
                                  const std::optional<std::string>& folder_id = std::nullopt,
                                  const std::optional<std::string>& name = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_files_create(client_, file_path.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            name ? name->c_str() : nullptr,
            &resp);
        check_error(err, "drive_files_create");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_delete(const std::string& file_id) {
        char* resp = nullptr;
        int err = misskey_drive_files_delete(client_, file_id.c_str(), &resp);
        check_error(err, "drive_files_delete");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_update(const std::string& file_id,
                                 const std::optional<std::string>& folder_id = std::nullopt,
                                 const std::optional<std::string>& name = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_files_update(client_, file_id.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            name ? name->c_str() : nullptr,
            &resp);
        check_error(err, "drive_files_update");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_find(const std::string& hash) {
        char* resp = nullptr;
        int err = misskey_drive_files_find(client_, hash.c_str(), &resp);
        check_error(err, "drive_files_find");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_show(const std::optional<std::string>& file_id = std::nullopt,
                               const std::optional<std::string>& url = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_files_show(client_,
            file_id ? file_id->c_str() : nullptr,
            url ? url->c_str() : nullptr,
            &resp);
        check_error(err, "drive_files_show");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_files_upload_from_url(const std::string& url,
                                           const std::optional<std::string>& folder_id = std::nullopt,
                                           bool is_sensitive = false,
                                           const std::optional<std::string>& comment = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_files_upload_from_url(client_, url.c_str(),
            folder_id ? folder_id->c_str() : nullptr,
            is_sensitive ? 1 : 0,
            comment ? comment->c_str() : nullptr,
            &resp);
        check_error(err, "drive_files_upload_from_url");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
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

    std::string drive_folders(int limit = 10, 
                              const std::optional<std::string>& folder_id = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_folders(client_, limit,
            folder_id ? folder_id->c_str() : nullptr,
            &resp);
        check_error(err, "drive_folders");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_folders_create(const std::string& name,
                                    const std::optional<std::string>& parent_id = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_folders_create(client_, name.c_str(),
            parent_id ? parent_id->c_str() : nullptr,
            &resp);
        check_error(err, "drive_folders_create");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_folders_delete(const std::string& folder_id) {
        char* resp = nullptr;
        int err = misskey_drive_folders_delete(client_, folder_id.c_str(), &resp);
        check_error(err, "drive_folders_delete");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string drive_folders_update(const std::string& folder_id,
                                    const std::optional<std::string>& name = std::nullopt,
                                    const std::optional<std::string>& parent_id = std::nullopt) {
        char* resp = nullptr;
        int err = misskey_drive_folders_update(client_, folder_id.c_str(),
            name ? name->c_str() : nullptr,
            parent_id ? parent_id->c_str() : nullptr,
            &resp);
        check_error(err, "drive_folders_update");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    std::string translate(const std::string& text,
                        const std::optional<std::string>& source_lang = std::nullopt,
                        const std::string& target_lang = "en") {
        char* resp = nullptr;
        int err = misskey_translate(client_, text.c_str(),
            source_lang ? source_lang->c_str() : nullptr,
            target_lang.c_str(),
            &resp);
        check_error(err, "translate");
        std::string result(resp ? resp : "");
        if (resp) {
            misskey_free_string(client_, resp);
        }
        return result;
    }

    const std::string& last_response() const { return last_response_; }
};

}

#endif
