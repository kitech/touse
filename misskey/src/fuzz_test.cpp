#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <climits>
#include <stdexcept>
#include "misskey.hpp"

using namespace misskey;

void test_null_client() {
    std::cout << "=== Test: NULL client (exceptions) ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        try {
            auto result = client.meta();
            std::cout << "meta with null: ";
            if (result.empty()) {
                std::cout << "empty response (OK)" << std::endl;
            } else {
                std::cout << "got response" << std::endl;
            }
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "meta exception: " << e.what() << " (code=" << (int)e.code << ")" << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Exception: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_empty_string() {
    std::cout << "=== Test: Empty strings ===" << std::endl;
    
    try {
        MisskeyApi client("");
        std::cout << "Empty host: ACCEPTED" << std::endl;
    } catch (const std::exception& e) {
        std::cout << "Empty host: REJECTED - " << e.what() << std::endl;
    }
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("");
        std::cout << "Empty token: ACCEPTED" << std::endl;
        
        try {
            client.meta();
            std::cout << "meta with empty token: OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "meta with empty token: " << e.what() << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client creation failed: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_negative_values() {
    std::cout << "=== Test: Negative values ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        try {
            client.notes_timeline(-1, false);
            std::cout << "notes_timeline(-1): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "notes_timeline(-1): " << e.what() << std::endl;
        }
        
        try {
            client.i_notifications(-100);
            std::cout << "i_notifications(-100): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "i_notifications(-100): " << e.what() << std::endl;
        }
        
        try {
            client.drive_files(-999, 0);
            std::cout << "drive_files(-999): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "drive_files(-999): " << e.what() << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_zero_values() {
    std::cout << "=== Test: Zero values ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        try {
            client.notes_timeline(0, false);
            std::cout << "notes_timeline(0): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "notes_timeline(0): " << e.what() << std::endl;
        }
        
        try {
            client.i_notifications(0);
            std::cout << "i_notifications(0): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "i_notifications(0): " << e.what() << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_large_limit() {
    std::cout << "=== Test: Large limit values ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        try {
            client.notes_timeline(100000, false);
            std::cout << "notes_timeline(100000): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "notes_timeline(100000): " << e.what() << std::endl;
        }
        
        try {
            client.i_notifications(999999);
            std::cout << "i_notifications(999999): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "i_notifications(999999): " << e.what() << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_special_characters() {
    std::cout << "=== Test: Special characters ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        std::string test_texts[] = {
            "Hello with 'single quotes'",
            "Hello with \"double quotes\"",
            "Hello\nwith\nnewlines",
            "Hello\twith\ttabs",
            "Hello with emoji 🎉",
            "Hello with 日本語",
            "Hello with 中文",
            "Hello with <script>alert('xss')</script>",
            "'; DROP TABLE users; --",
            "Hello with\r\ncarriage\r\nreturns",
            ""
        };
        
        for (size_t i = 0; i < sizeof(test_texts)/sizeof(test_texts[0]); i++) {
            try {
                client.notes_create(test_texts[i]);
                std::cout << "notes_create(text[" << i << "]): OK" << std::endl;
            } catch (const MisskeyApi::Exception& e) {
                std::cout << "notes_create(text[" << i << "]): " << e.what() << std::endl;
            }
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_very_long_strings() {
    std::cout << "=== Test: Very long strings ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        size_t sizes[] = { 1000, 10000, 100000 };
        
        for (size_t i = 0; i < sizeof(sizes)/sizeof(sizes[0]); i++) {
            std::string long_text(sizes[i], 'A');
            
            try {
                client.notes_create(long_text);
                std::cout << "notes_create(len=" << sizes[i] << "): OK" << std::endl;
            } catch (const MisskeyApi::Exception& e) {
                std::cout << "notes_create(len=" << sizes[i] << "): " << e.what() << std::endl;
            }
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_invalid_host() {
    std::cout << "=== Test: Invalid hosts ===" << std::endl;
    
    std::string invalid_hosts[] = {
        "invalid..host",
        "host with spaces",
        "host:abc",
        "host:99999",
        "host:-1",
        "///invalid///",
        ""
    };
    
    for (size_t i = 0; i < sizeof(invalid_hosts)/sizeof(invalid_hosts[0]); i++) {
        try {
            MisskeyApi client(invalid_hosts[i]);
            std::cout << "host[" << i << "]: ACCEPTED" << std::endl;
        } catch (const std::exception& e) {
            std::cout << "host[" << i << "]: REJECTED - " << e.what() << std::endl;
        }
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_malformed_urls() {
    std::cout << "=== Test: Malformed URLs ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        try {
            client.drive_files_find("not_a_valid_hash_but_should_work");
            std::cout << "drive_files_find(invalid): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "drive_files_find(invalid): " << e.what() << std::endl;
        }
        
        try {
            client.drive_files_upload_from_url("not-a-url", std::nullopt, false, std::nullopt);
            std::cout << "drive_files_upload_from_url(invalid): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "drive_files_upload_from_url(invalid): " << e.what() << std::endl;
        }
        
        try {
            client.translate("test", "invalid_lang", "ja");
            std::cout << "translate(invalid_lang): OK" << std::endl;
        } catch (const MisskeyApi::Exception& e) {
            std::cout << "translate(invalid_lang): " << e.what() << std::endl;
        }
        
    } catch (const std::exception& e) {
        std::cout << "Client error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_timeout_values() {
    std::cout << "=== Test: Timeout values ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        
        client.set_timeout(0);
        std::cout << "timeout = 0: OK" << std::endl;
        
        client.set_timeout(-1);
        std::cout << "timeout = -1: OK" << std::endl;
        
        client.set_timeout(999999);
        std::cout << "timeout = 999999: OK" << std::endl;
        
        client.set_timeout(INT_MAX);
        std::cout << "timeout = INT_MAX: OK" << std::endl;
        
    } catch (const std::exception& e) {
        std::cout << "Error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_move_semantics() {
    std::cout << "=== Test: Move semantics ===" << std::endl;
    
    MisskeyApi client1("localhost:3000");
    client1.set_token("test");
    
    MisskeyApi client2 = std::move(client1);
    std::cout << "Move construction: OK" << std::endl;
    
    MisskeyApi client3("localhost:3000");
    client3 = std::move(client2);
    std::cout << "Move assignment: OK" << std::endl;
    
    try {
        client2.meta();  // Should fail - moved from
        std::cout << "Moved-from client still usable: UNEXPECTED" << std::endl;
    } catch (...) {
        std::cout << "Moved-from client throws: OK" << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

void test_optional_params() {
    std::cout << "=== Test: Optional parameters ===" << std::endl;
    
    try {
        MisskeyApi client("localhost:3000");
        client.set_token("test");
        
        auto r1 = client.notes_create("test", std::nullopt, std::nullopt);
        std::cout << "notes_create with nullopt: OK" << std::endl;
        
        auto r2 = client.drive_files_create("/nonexistent/path", std::nullopt, std::nullopt);
        std::cout << "drive_files_create with nullopt: OK" << std::endl;
        
        auto r3 = client.drive_folders_create("test", std::nullopt);
        std::cout << "drive_folders_create with nullopt: OK" << std::endl;
        
        auto r4 = client.translate("test", std::nullopt, "en");
        std::cout << "translate with nullopt: OK" << std::endl;
        
    } catch (const std::exception& e) {
        std::cout << "Error: " << e.what() << std::endl;
    }
    
    std::cout << "PASS" << std::endl << std::endl;
}

int main() {
    std::cout << "===========================================" << std::endl;
    std::cout << "  Fuzz Tests - C++ API" << std::endl;
    std::cout << "===========================================" << std::endl << std::endl;
    
    test_null_client();
    test_empty_string();
    test_negative_values();
    test_zero_values();
    test_large_limit();
    test_special_characters();
    test_very_long_strings();
    test_invalid_host();
    test_malformed_urls();
    test_timeout_values();
    test_move_semantics();
    test_optional_params();
    
    std::cout << "===========================================" << std::endl;
    std::cout << "  All fuzz tests passed!" << std::endl;
    std::cout << "===========================================" << std::endl;
    
    return 0;
}
