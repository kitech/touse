module github

#flag -I@DIR/ -fPIC -lcurl
#flag @DIR/github.o
#include <curl/curl.h>
#include "@DIR/github.h"

fn C.curl_easy_setopt(curl voidptr, option int, ...) int
fn C.curl_easy_perform(curl voidptr) int
fn C.curl_easy_strerror(code int) &char

// 初始化
fn C.gh_client_init(token &char) int
fn C.gh_client_set_user_agent(ua &char)
fn C.gh_client_set_verbose(verbose int)
fn C.gh_client_free()
fn C.gh_client_response_free(res &Response)

// Release
fn C.gh_client_repo_releases_list(owner &char, repo &char, opts &ReqListOpts) &Response
fn C.gh_client_repo_releases_latest(owner &char, repo &char) &Response
fn C.gh_client_repo_release_by_tag(owner &char, repo &char, tag &char) &Response
fn C.gh_client_repo_release_by_id(owner &char, repo &char, id u32) &Response
fn C.gh_client_repo_release_create(owner &char, repo &char, data &char) &Response
fn C.gh_client_repo_release_update(owner &char, repo &char, id u32, data &char) &Response
fn C.gh_client_repo_release_delete(owner &char, repo &char, id u32) &Response
fn C.gh_client_repo_release_gen_notes(owner &char, repo &char, data &char) &Response

// Asset
fn C.gh_client_repo_release_assets_list(owner &char, repo &char, id u32, opts &ReqListOpts) &Response
fn C.gh_client_repo_release_asset_get(owner &char, repo &char, id u32) &Response


pub struct RateLimitData {
    limit      u64
    remaining  u64
    reset      u64
    used       u64
    resource   string
}

pub struct ReqListOpts {
    per_page  u32
    page_url  string
}

pub struct ReqListCursorOpts {
    page_url string
    first   u32
    last    u32
    after   string
    before  string
    cursor  string
}

pub struct CommitsListOpts {
    sha      string
    path     string
    author   string
    committer string
    since    string
    until    string
    per_page u32
    page_url string
}

pub struct PullReqOpts {
    state    u32
    order   u32
    per_page u32
    page_url string
}

pub struct IssuesReqOpts {
    state    u32
    order   u32
    filter  u32
    sort    u32
    per_page u32
    assignee string
    creator  string
    mention  string
    labels  string
    page_url string
    since   string
    collab  bool
    orgs    bool
    owned   bool
    pulls   bool
}

pub enum ItemListState {
    opened = 0
    closed = 1
    merged = 2
    all = 3
}

pub enum ItemListOrder {
    desc = 0
    asc = 1
}

pub enum IssueFilters {
    assigned = 0
    created = 1
    mentioned = 2
    subscribed = 4
    repos = 5
    all = 6
}

pub enum IssueSortOptions {
    created = 0
    updated = 1
    comments = 2
}

pub struct Response {
    pub:
    resp      &char
    err_msg   &char
    size      usize
    resp_code u16
    url      &char
    first_link &char
    next_link  &char
    prev_link  &char
    last_link  &char
    rate_limit &RateLimitData
}

// GitHub API Release 相关结构体

// Simple User (用于author和uploader)
pub struct User {
pub:
    login        string
    id           int
    node_id      string
    avatar_url   string
    html_url     string
}

// Release Asset
pub struct ReleaseAsset {
pub:
    url                  string
    browser_download_url string
    id                   int
    node_id              string
    name                 string
    label                string
    state                string
    content_type         string
    size                 int
    digest              string
    download_count       int
    created_at           string
    updated_at           string
    uploader           User
}

// Release
pub struct Release {
pub:
    url              string
    html_url         string
    assets_url       string
    upload_url       string
    tarball_url     string
    zipball_url     string
    id               int
    node_id          string
    tag_name         string
    target_commitish string
    name            string
    body            string
    draft            bool
    prerelease       bool
    created_at      string
    published_at    string
    author          User
    assets         []ReleaseAsset
}

fn cstring_to_string(cstr &char) string {
    if isnil(cstr) {
        return ''
    }
    return unsafe { tos_clone(&u8(cstr)) }
}

fn (r Response) str() string {
    return cstring_to_string(r.resp)
}

fn (r Response) get_url() string {
    return cstring_to_string(r.url)
}

// 去掉curl返回的&前缀
pub fn strip_prefix(json_str string) string {
    if json_str.len > 0 && json_str[0] == `&` {
        return json_str[1..]
    }
    return json_str
}
