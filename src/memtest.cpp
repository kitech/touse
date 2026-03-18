#include <iostream>
#include "misskey.hpp"

#define ITERATIONS 100

int main() {
    std::cout << "Testing C++ memory leaks with " << ITERATIONS << " iterations..." << std::endl;
    
    misskey::MisskeyApi client("localhost:3000");
    client.set_token("test_token_12345");
    
    for (int i = 0; i < ITERATIONS; i++) {
        try {
            auto result1 = client.meta();
            auto result2 = client.drive();
            auto result3 = client.i_notifications(5);
        } catch (const misskey::MisskeyApi::Exception& e) {
            std::cerr << "Error: " << e.what() << std::endl;
        }
        
        if (i % 10 == 0) {
            std::cout << "Progress: " << i << "/" << ITERATIONS << std::endl;
        }
    }
    
    std::cout << "Done! Ran " << ITERATIONS << " iterations." << std::endl;
    return 0;
}
