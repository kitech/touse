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
    C.gh_client_set_verbose(0)
    
    opts := unsafe { nil }
    res := C.gh_client_repo_releases_list(&char('vlang'.str), &char('v'.str), opts)
    if isnil(res) {
        println('res is nil')
        C.gh_client_free()
        return
    }
    
    json_str := github.strip_prefix(res.str())
    releases := json.decode([]github.Release, json_str)!
    
    println('Latest 3 releases:')
    println('')
    
    for i := 0; i < 3; i++ {
        if i >= releases.len {
            break
        }
        r := releases[i]
        println('${i + 1}. ${r.tag_name}')
        println('   Date: ${r.published_at}')
        if r.assets.len > 0 {
            println('   Files:')
            for asset in r.assets {
                size_kb := f64(asset.size) / 1024.0
                println('     - ${asset.name} (${size_kb:.1f} KB)')
                println('       ${asset.browser_download_url}')
            }
        }
        println('')
    }
    
    C.gh_client_response_free(res)
    C.gh_client_free()
}

fn test_1() {
    test_list_releases()
}