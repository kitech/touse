#include "identicon.h"
#include <stdio.h>

int main(int argc, char** argv) {
    const char *user = "octocat";
    if (argc > 1) { user = argv[1]; }

    if (identicon_generate(user, "octocat.png") == 0) {
        printf("生成成功: octocat.png\n");
    } else {
        printf("生成失败\n");
    }
    return 0;
}
