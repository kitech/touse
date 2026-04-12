import github
import os
import json

fn get_github_token() string {
    return os.getenv('GITHUB_TOKEN')
}

fn test_list_releases() {
    token := get_github_token()
    if token.len == 0 {
        println('GITHUB_TOKEN not set')
        return
    }
    
    C.gh_client_init(&char(token.str))
    
    // 只列出最新的release
    opts := unsafe { nil }
    res := C.gh_client_repo_releases_list(&char('kitech'.str), &char('aonix'.str), opts)
    if isnil(res) {
        println('res is nil')
        C.gh_client_free()
        return
    }
    
    json_str := github.strip_prefix(res.str())
    releases := json.decode([]github.Release, json_str) or { return }
    
    if releases.len > 0 {
        r := releases[0]
        println('Latest: ${r.tag_name} (id: ${r.id})')
        if r.assets.len > 0 {
            for asset in r.assets {
                println('  - ${asset.name} (id: ${asset.id}, size: ${asset.size})')
            }
        }
    }
    
    C.gh_client_response_free(res)
    C.gh_client_free()
}

fn test_2() {
    println('=== test_2 starting ===')
    token := get_github_token()
    if token.len == 0 {
        println('GITHUB_TOKEN not set')
        return
    }
    
    C.gh_client_init(&char(token.str))
    
    // v99 release id = 308035376 (不带模板参数)
    upload_url := 'https://uploads.github.com/repos/kitech/aonix/releases/308035376/assets'
    name := 'test_upload_v3.txt'
    label := 'Test-file'
    file_path := './README.md'
    
    res := C.gh_client_repo_release_asset_upload(&char(upload_url.str), &char(name.str), &char(label.str), &char(file_path.str))
    if isnil(res) {
        println('upload res is nil')
        C.gh_client_free()
        return
    }
    
    println('Upload resp_code: ${res.resp_code}')
    if !isnil(res.err_msg) {
        println('err_msg: ${unsafe { tos_clone(&u8(res.err_msg)) }}')
    }
    if res.resp_code == 201 {
        println('upload success!')
    } else {
        println('upload failed')
    }
    
    C.gh_client_response_free(res)
    C.gh_client_free()
}