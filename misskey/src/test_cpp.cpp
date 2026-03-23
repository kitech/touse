#include <iostream>
#include <iomanip>
#include <chrono>
#include "misskey.hpp"

using namespace misskey;

void print_note(const Note& note) {
    std::cout << "  Note ID: " << note.id << "\n";
    std::cout << "  Text: " << note.text << "\n";
    std::cout << "  User: " << note.user.name << " (@" << note.user.username << ")\n";
    std::cout << "  Created: " << note.created_at << "\n";
}

void print_notes(const std::vector<Note>& notes) {
    for (const auto& note : notes) {
        print_note(note);
        std::cout << "\n";
    }
}

void print_notification(const Notification& n) {
    std::cout << "  Notification ID: " << n.id << "\n";
    std::cout << "  Type: " << n.type << "\n";
    std::cout << "  From: " << n.user_name << "\n";
    std::cout << "  Created: " << n.created_at << "\n";
}

void print_drive_file(const DriveFile& f) {
    std::cout << "  File ID: " << f.id << "\n";
    std::cout << "  Name: " << f.name << "\n";
    std::cout << "  Size: " << f.size << " bytes\n";
    std::cout << "  Type: " << f.type << "\n";
}

void print_drive_folder(const DriveFolder& f) {
    std::cout << "  Folder ID: " << f.id << "\n";
    std::cout << "  Name: " << f.name << "\n";
    std::cout << "  Folders: " << f.folders_count << ", Files: " << f.files_count << "\n";
}

void print_clip(const Clip& c) {
    std::cout << "  Clip ID: " << c.id << "\n";
    std::cout << "  Name: " << c.name << "\n";
    std::cout << "  Public: " << (c.is_public ? "Yes" : "No") << "\n";
    std::cout << "  Notes: " << c.notes_count << "\n";
}

int main(int argc, char* argv[]) {
    std::string host = "localhost:3000";
    std::string token = "test_token_12345";
    
    if (argc >= 2) host = argv[1];
    if (argc >= 3) token = argv[2];
    
    std::cout << "===========================================\n";
    std::cout << "  Misskey C++ API Test (Structured)\n";
    std::cout << "===========================================\n";
    std::cout << "Host: " << host << "\n";
    std::cout << "Token: " << token << "\n\n";
    
    try {
        MisskeyApi client(host);
        client.set_token(token);
        client.set_debug(false);
        
        std::cout << "--- Testing Structured APIs ---\n\n";
        
        std::cout << "=== meta ===\n";
        try {
            auto result = client.meta();
            std::cout << "  Name: " << result.name << "\n";
            std::cout << "  Version: " << result.version << "\n";
            std::cout << "  Max note length: " << result.max_note_text_length << "\n";
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== notes_timeline ===\n";
        try {
            auto result = client.notes_timeline(3, true);
            print_notes(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== notes_create ===\n";
        try {
            auto result = client.notes_create("Hello from C++ structured API!");
            std::cout << "Created note ID: " << result.id << "\n";
            client.notes_delete(result.id);
            std::cout << "Deleted note: " << result.id << "\n";
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== i_notifications ===\n";
        try {
            auto result = client.i_notifications(5);
            for (const auto& n : result) {
                print_notification(n);
                std::cout << "\n";
            }
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive ===\n";
        try {
            auto result = client.drive();
            std::cout << "  Capacity: " << result.capacity << " bytes\n";
            std::cout << "  Usage: " << result.usage << " bytes\n";
            std::cout << "  Over quota: " << (result.is_over_quota ? "Yes" : "No") << "\n";
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_files ===\n";
        try {
            auto result = client.drive_files(5);
            for (const auto& f : result) {
                print_drive_file(f);
                std::cout << "\n";
            }
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_folders ===\n";
        try {
            auto result = client.drive_folders(5);
            for (const auto& f : result) {
                print_drive_folder(f);
                std::cout << "\n";
            }
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== translate ===\n";
        try {
            auto note = client.notes_create("Hello world!");
            auto result = client.translate(note.id, "ja");
            std::cout << "  Source: " << result.source_lang << "\n";
            std::cout << "  Target: " << result.target_lang << "\n";
            std::cout << "  Translated: " << result.text << "\n";
            client.notes_delete(note.id);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== clips_list ===\n";
        try {
            auto result = client.clips_list();
            for (const auto& c : result) {
                print_clip(c);
                std::cout << "\n";
            }
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "===========================================\n";
        std::cout << "  Done\n";
        std::cout << "===========================================\n";
        
    } catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << "\n";
        return 1;
    }
    
    return 0;
}
