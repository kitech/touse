#include <iostream>
#include <iomanip>
#include <chrono>
#include "misskey.hpp"

using namespace misskey;

void print_json_pretty(const std::string& json) {
    int indent = 0;
    bool in_string = false;
    for (size_t i = 0; i < json.length(); i++) {
        char c = json[i];
        
        if (c == '\\' && in_string) {
            std::cout << c << json[++i];
            continue;
        }
        
        if (c == '"') {
            in_string = !in_string;
            std::cout << c;
            continue;
        }
        
        if (in_string) {
            std::cout << c;
            continue;
        }
        
        switch (c) {
            case '{':
            case '[':
                std::cout << c << "\n" << std::string(++indent * 2, ' ');
                break;
            case '}':
            case ']':
                std::cout << "\n" << std::string(--indent * 2, ' ') << c;
                break;
            case ',':
                std::cout << c << "\n" << std::string(indent * 2, ' ');
                break;
            default:
                std::cout << c;
        }
    }
    std::cout << "\n";
}

int main(int argc, char* argv[]) {
    std::string host = "localhost:3000";
    std::string token = "test_token_12345";
    
    if (argc >= 2) host = argv[1];
    if (argc >= 3) token = argv[2];
    
    std::cout << "===========================================\n";
    std::cout << "  Misskey C++ API Test\n";
    std::cout << "===========================================\n";
    std::cout << "Host: " << host << "\n";
    std::cout << "Token: " << token << "\n\n";
    
    try {
        MisskeyApi client(host);
        client.set_token(token);
        client.set_debug(false);
        
        std::cout << "--- Testing APIs ---\n\n";
        
        std::cout << "=== meta ===\n";
        try {
            auto result = client.meta();
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== notes_timeline ===\n";
        try {
            auto result = client.notes_timeline(3, true);
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== i_notifications ===\n";
        try {
            auto result = client.i_notifications(5);
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive ===\n";
        try {
            auto result = client.drive();
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_files ===\n";
        try {
            auto result = client.drive_files(5, 0);
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_files_show ===\n";
        try {
            auto result = client.drive_files_show("test_file_id_123", std::nullopt);
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_files_upload_from_url ===\n";
        try {
            auto result = client.drive_files_upload_from_url(
                "https://example.com/test.png", 
                std::nullopt, 
                false, 
                std::nullopt
            );
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== drive_folders ===\n";
        try {
            auto result = client.drive_folders(5, std::nullopt);
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n=== translate ===\n";
        try {
            auto result = client.translate("Hello", std::nullopt, "ja");
            print_json_pretty(result);
        } catch (const MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << "\n";
        }
        
        std::cout << "\n===========================================\n";
        std::cout << "  Done\n";
        std::cout << "===========================================\n";
        
    } catch (const std::exception& e) {
        std::cerr << "Fatal error: " << e.what() << "\n";
        return 1;
    }
    
    return 0;
}
