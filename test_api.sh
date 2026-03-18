#!/bin/bash
# Misskey Client API 一行测试脚本

HOST=${1:-localhost:3000}
TOKEN=${2:-test_token_12345}

# 根据host决定协议
if [[ "$HOST" == "localhost"* ]] || [[ "$HOST" == "127.0.0.1"* ]]; then
    SCHEME="http"
else
    SCHEME="https"
fi

echo "=========================================="
echo "  Misskey API 一行测试"
echo "=========================================="
echo "Host: $HOST"
echo "Scheme: $SCHEME"
echo "Token: $TOKEN"
echo "=========================================="

# 辅助函数
test_api() {
    local name=$1
    local url=$2
    local data=$3
    echo ""
    echo ">>> $name"
    echo "curl -s -X POST '$SCHEME://$HOST/api/$url' -H 'Content-Type: application/json' -H 'Authorization: Bearer $TOKEN' -d '$data'"
    echo "---"
    curl -s -X POST "$SCHEME://$HOST/api/$url" \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $TOKEN" \
        -d "$data" 2>/dev/null | head -c 300
    echo ""
}

test_api_no_auth() {
    local name=$1
    local url=$2
    local data=$3
    echo ""
    echo ">>> $name (no auth)"
    echo "curl -s -X POST '$SCHEME://$HOST/api/$url' -H 'Content-Type: application/json' -d '$data'"
    echo "---"
    curl -s -X POST "$SCHEME://$HOST/api/$url" \
        -H 'Content-Type: application/json' \
        -d "$data" 2>/dev/null | head -c 300
    echo ""
}

echo ""
echo "=========================================="
echo "  基础 API"
echo "=========================================="
test_api_no_auth "获取服务器信息" "meta" '{"detail":false}'

echo ""
echo "=========================================="
echo "  笔记 API"
echo "=========================================="
test_api "获取时间线" "notes/timeline" '{"limit":3}'
test_api "发布笔记" "notes/create" '{"text":"Test note from shell"}'
test_api "翻译" "notes/translate" '{"text":"Hello","targetLang":"ja"}'

echo ""
echo "=========================================="
echo "  通知 API"
echo "=========================================="
test_api "获取通知" "i/notifications" '{"limit":5}'

echo ""
echo "=========================================="
echo "  网盘 API"
echo "=========================================="
test_api "网盘容量" "drive" '{}'
test_api "文件列表" "drive/files" '{"limit":5}'
test_api "删除文件" "drive/files/delete" '{"fileId":"test123"}'
test_api "更新文件" "drive/files/update" '{"fileId":"test123","name":"newname.txt"}'
test_api "查找文件" "drive/files/find" '{"hash":"abc123"}'
test_api "文件属性" "drive/files/show" '{"fileId":"test_file_id_123"}'
test_api "URL上传" "drive/files/upload-from-url" '{"url":"https://example.com/test.png"}'

echo ""
echo "=========================================="
echo "  网盘-文件夹 API"
echo "=========================================="
test_api "文件夹列表" "drive/folders" '{"limit":5}'
test_api "创建文件夹" "drive/folders/create" '{"name":"TestFolder"}'
test_api "删除文件夹" "drive/folders/delete" '{"folderId":"test123"}'
test_api "更新文件夹" "drive/folders/update" '{"folderId":"test123","name":"NewName"}'

echo ""
echo "=========================================="
echo "  测试完成"
echo "=========================================="
