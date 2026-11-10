import os
import x.json2
import term

#include <unistd.h>

// ==================== 颜色控制 ====================

fn C.isatty(fd int) int

fn colors_enabled() bool {
    if os.getenv('NO_COLOR') != '' {
        return false
    }
    if C.isatty(1) == 0 {
        return false
    }
    return true
}

const use_color = colors_enabled()

fn c_bold(s string) string {
    return if use_color { term.bold(s) } else { s }
}

fn c_cyan_bold(s string) string {
    return if use_color { term.bold(term.cyan(s)) } else { s }
}

fn c_bright_white_bold(s string) string {
    return if use_color { term.bold(term.bright_white(s)) } else { s }
}

fn c_green(s string) string {
    return if use_color { term.green(s) } else { s }
}

fn c_yellow(s string) string {
    return if use_color { term.yellow(s) } else { s }
}

fn c_magenta(s string) string {
    return if use_color { term.magenta(s) } else { s }
}

fn c_dim(s string) string {
    return if use_color { term.dim(s) } else { s }
}

// ==================== 数据结构 ====================

struct PkgManager {
    name        string
    cmd         string
    search_tpl  string
    info_tpl    string
    info_parser string = ''
}

// ==================== 包管理器定义 ====================

const managers = [
    PkgManager{
        name: 'pacman'
        cmd: 'pacman'
        search_tpl: 'pacman -Ss {q}'
        info_tpl: 'pacman -Si {q}'
    },
    PkgManager{
        name: 'apt'
        cmd: 'apt'
        search_tpl: 'apt search {q}'
        info_tpl: 'apt show {q}'
    },
    PkgManager{
        name: 'vcpkg'
        cmd: 'vcpkg'
        search_tpl: 'vcpkg search {q}'
        info_tpl: 'vcpkg x-package-info {q} --x-json'
        info_parser: 'vcpkg'
    },
    PkgManager{
        name: 'brew'
        cmd: 'brew'
        search_tpl: 'brew search {q}'
        info_tpl: 'brew info {q}'
    },
    PkgManager{
        name: 'port'
        cmd: 'port'
        search_tpl: 'port search {q}'
        info_tpl: 'port info {q}'
    },
    PkgManager{
        name: 'rpm'
        cmd: 'rpm'
        search_tpl: 'rpm -qa | grep -i {q}'
        info_tpl: 'rpm -qi {q}'
    },
    PkgManager{
        name: 'apk'
        cmd: 'apk'
        search_tpl: 'apk search -v {q}'
        info_tpl: 'apk info -a {q}'
    },
    PkgManager{
        name: 'pkg (Termux)'
        cmd: 'pkg'
        search_tpl: 'pkg search {q}'
        info_tpl: 'pkg show {q}'
    },
    PkgManager{
        name: 'pm (Android)'
        cmd: 'pm'
        search_tpl: 'pm list packages -f | grep -i {q}'
        info_tpl: 'pm dump {q}'
    },
]

// ==================== 通用工具 ====================

fn command_exists(cmd string) bool {
    os.find_abs_path_of_executable(cmd) or { return false }
    return true
}

fn escape_shell(s string) string {
    return "'" + s.replace("'", "'\\''") + "'"
}

fn build_command(tpl string, query string) string {
    return tpl.replace('{q}', escape_shell(query))
}

fn run_command(cmd_str string) string {
    res := os.execute(cmd_str)
    output := res.output.trim_space()
    if res.exit_code != 0 && output.len == 0 {
        return '  (exit code ${res.exit_code})'
    }
    return output
}

fn print_header(mgr_name string, subcmd string, cmd_str string) {
    println('')
    println('========== [${mgr_name}] ${subcmd} ==========')
    println('\$ ${cmd_str}')
    println('---------------------------------------------')
}

// ==================== 通用输出着色 ====================

fn has_ansi(s string) bool {
    return s.contains('\x1b[')
}

fn is_field_key(s string) bool {
    if s.len == 0 || s.len > 30 {
        return false
    }
    if !s[0].is_letter() {
        return false
    }
    for c in s {
        if !(c.is_letter() || c.is_digit() || c == ` ` || c == `-` || c == `_` || c == `.`) {
            return false
        }
    }
    if s.trim_space().len == 0 {
        return false
    }
    return true
}

fn is_pkg_token(s string) bool {
    if s.len == 0 || s.len > 100 {
        return false
    }
    if !(s[0].is_letter() || s[0].is_digit()) {
        return false
    }
    if s.contains('...') || s.contains(':') {
        return false
    }
    for c in s {
        if !(c.is_letter() || c.is_digit() || c == `-` || c == `_` || c == `+` || c == `.` || c == `/` || c == `@`) {
            return false
        }
    }
    return true
}

// 返回第一个冒号的下标，跳过 "://"；找不到返回 -1
fn find_kv_colon(line string) int {
    for i := 0; i < line.len; i++ {
        if line[i] == `:` {
            if i + 2 < line.len && line[i + 1] == `/` && line[i + 2] == `/` {
                continue
            }
            return i
        }
    }
    return -1
}

fn colorize_line(line string, action string) string {
    if line.len == 0 || has_ansi(line) {
        return line
    }
    if line.trim_space().len == 0 {
        return line
    }

    idx := find_kv_colon(line)
    if idx >= 0 {
        before := line[..idx]
        rest := line[idx..]
        ws_prefix := before[..before.len - before.trim_left(' ').len]
        key_part := before[ws_prefix.len..].trim_right(' ')
        trailing := before[ws_prefix.len + key_part.len..]
        if key_part.len > 0 && is_field_key(key_part) {
            return ws_prefix + c_cyan_bold(key_part) + trailing + rest
        }
    }

    if action == 'search' {
        trimmed := line.trim_space()
        leading := line[..line.len - line.trim_left(' ').len]
        sp := trimmed.index(' ') or { -1 }
        if sp > 0 {
            first := trimmed[..sp]
            if is_pkg_token(first) {
                return leading + c_bright_white_bold(first) + trimmed[sp..]
            }
        } else {
            if is_pkg_token(trimmed) {
                return leading + c_bright_white_bold(trimmed)
            }
        }
    }

    return line
}

fn colorize_output(text string, action string) string {
    if !use_color {
        return text
    }
    mut lines := []string{}
    for line in text.split('\n') {
        lines << colorize_line(line, action)
    }
    return lines.join('\n')
}

// ==================== vcpkg JSON 解析 & 扁平格式化 ====================

fn extract_json(text string) string {
    t := text.trim_space()
    for i, c in t {
        if c == `[` || c == `{` {
            return t[i..]
        }
    }
    return t
}

fn pretty_key(k string) string {
    known := {
        'name':             'Name'
        'version':          'Version'
        'port-version':     'Port Version'
        'description':      'Description'
        'homepage':         'Homepage'
        'license':          'License'
        'supports':         'Supports'
        'dependencies':     'Dependencies'
        'default-features': 'Default Features'
        'features':         'Features'
        'type':             'Type'
    }
    if v := known[k] {
        return v
    }
    return k.replace('-', ' ')
}

fn format_value(v json2.Any) string {
    if v is string {
        return v
    }
    if v is []json2.Any {
        mut parts := []string{}
        for item in v {
            if item is string {
                parts << item
            } else {
                mp := item.as_map()
                if n := mp['name'] {
                    mut s := n.str()
                    if feats := mp['features'] {
                        farr := feats.arr()
                        if farr.len > 0 {
                            mut fparts := []string{}
                            for x in farr {
                                fparts << x.str()
                            }
                            s += '[' + fparts.join(',') + ']'
                        }
                    }
                    if h := mp['host'] {
                        if h.bool() {
                            s += ' ' + c_yellow('[host]')
                        }
                    }
                    parts << s
                } else {
                    parts << item.str()
                }
            }
        }
        return parts.join('  ')
    }
    if v is map[string]json2.Any {
        mp := v.clone()
        mut keys := []string{}
        for k, _ in mp {
            keys << k
        }
        keys.sort()
        return keys.join(', ')
    }
    return v.str()
}

fn format_field(key string, value json2.Any) string {
    val_str := format_value(value)
    if val_str.len == 0 {
        return ''
    }
    pretty := pretty_key(key)
    mut padded := pretty
    for padded.len < 16 {
        padded += ' '
    }

    colored_key := c_cyan_bold(padded)

    colored_val := match key {
        'name' { c_bright_white_bold(val_str) }
        'version' { c_bright_white_bold(val_str) }
        'dependencies' { c_green(val_str) }
        'features' { c_magenta(val_str) }
        'default-features' { c_magenta(val_str) }
        'port-version' { if val_str == '0' { c_dim(val_str) } else { val_str } }
        else { val_str }
    }

    return '${colored_key}: ${colored_val}'
}

fn format_vcpkg_port(p map[string]json2.Any) string {
    priority := [
        'name', 'version', 'port-version', 'description', 'homepage',
        'license', 'supports', 'dependencies', 'default-features',
        'features', 'type',
    ]

    mut lines := []string{}
    mut shown := map[string]bool{}

    for key in priority {
        if v := p[key] {
            line := format_field(key, v)
            if line.len > 0 {
                lines << line
            }
            shown[key] = true
        }
    }

    mut extras := []string{}
    for k, _ in p {
        if k !in shown {
            extras << k
        }
    }
    extras.sort()
    for k in extras {
        if v := p[k] {
            line := format_field(k, v)
            if line.len > 0 {
                lines << line
            }
        }
    }

    if lines.len == 0 {
        return '(无有效字段)'
    }
    return lines.join('\n')
}

fn parse_vcpkg_json(text string) string {
    t := extract_json(text)
    if t.len == 0 {
        return '(无数据)'
    }

    mut out := []string{}

    if t[0] == `[` {
        ports := json2.decode[[]map[string]json2.Any](t) or { return text }
        if ports.len == 0 {
            return '(无匹配端口)'
        }
        for i, p in ports {
            if i > 0 { out << '' }
            out << format_vcpkg_port(p)
        }
    } else if t[0] == `{` {
        top := json2.decode[map[string]json2.Any](t) or { return text }

        if results_any := top['results'] {
            results := results_any.as_map()
            if results.len > 0 {
                mut names := []string{}
                for k, _ in results {
                    names << k
                }
                names.sort()
                for i, name in names {
                    if i > 0 { out << '' }
                    port_any := results[name]
                    port := port_any.as_map()
                    out << format_vcpkg_port(port)
                }
                return out.join('\n')
            }
            return '(results 为空)'
        }

        out << format_vcpkg_port(top)
    } else {
        return text
    }

    return out.join('\n')
}

fn handle_vcpkg_info(query string) string {
    safe := escape_shell(query)
    info_cmd := 'vcpkg x-package-info ${safe} --x-json'
    info_res := os.execute(info_cmd)

    mut out := []string{}
    out << '\$ ${info_cmd}'
    out << '---------------------------------------------'

    info_text := info_res.output.trim_space()
    if info_text.len == 0 {
        out << '(包信息无输出)'
    } else {
        out << parse_vcpkg_json(info_text)
    }

    return out.join('\n')
}

// ==================== 主逻辑 ====================

fn main() {
    if os.args.len < 3 {
        eprintln('用法: zpkg <search|info> <包名或关键词>')
        eprintln('示例: zpkg search curl')
        eprintln('      zpkg info curl')
        exit(1)
    }

    action := os.args[1].to_lower()
    query := os.args[2]

    if action !in ['search', 'info'] {
        eprintln('错误: 子命令必须是 search 或 info，收到: ${action}')
        exit(1)
    }

    mut executed := 0
    mut skipped := 0

    for mgr in managers {
        if !command_exists(mgr.cmd) {
            skipped++
            continue
        }
        executed++

        if mgr.info_parser == 'vcpkg' && action == 'info' {
            println('')
            println('========== [${mgr.name}] ${action} ==========')
            println(handle_vcpkg_info(query))
        } else {
            tpl := if action == 'search' { mgr.search_tpl } else { mgr.info_tpl }
            cmd_str := build_command(tpl, query)
            print_header(mgr.name, action, cmd_str)
            output := run_command(cmd_str)
            if output.len > 0 {
                println(colorize_output(output, action))
            } else {
                println('  (无输出)')
            }
        }
    }

    println('')
    println('--- 汇总: 执行 ${executed} 个包管理器, 跳过 ${skipped} 个 (未安装) ---')
}
