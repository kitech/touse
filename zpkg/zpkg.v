import os
import x.json2
import term
import flag
import time

#include <unistd.h>

// ==================== 颜色控制 ====================

fn C.isatty(fd int) int

fn colors_enabled() bool {
	if os.getenv('NO_COLOR') != '' { return false }
	if C.isatty(1) == 0 { return false }
	return true
}

const use_color = colors_enabled()

fn c_cyan_bold(s string) string { return if use_color { term.bold(term.cyan(s)) } else { s } }
fn c_bright_white_bold(s string) string { return if use_color { term.bold(term.bright_white(s)) } else { s } }
fn c_green(s string) string { return if use_color { term.green(s) } else { s } }
fn c_yellow(s string) string { return if use_color { term.yellow(s) } else { s } }
fn c_magenta(s string) string { return if use_color { term.magenta(s) } else { s } }
fn c_dim(s string) string { return if use_color { term.dim(s) } else { s } }

// ==================== 数据结构 ====================

struct PkgManager {
	name       string
	cmd        string
	search_tpl string
	info_tpl   string
	list_cmd   string
	installed_cmd string
	fetch_tpl  string
	fetch_recursive_tpl string = ''
	files_tpl  string = ''
	info_parser string = ''
	has_native_installed_mark bool = false
}

struct ListConfig {
mut:
	sort string = 'natural'
	max  int    = 10
}

struct FetchConfig {
mut:
	recursive bool = false
}

struct PkgEntry {
	name string
mut:
	version      string = '-'
	size         i64 = 0
	size_str     string = '-'
	install_date string = '-'
	update_date  string = '-'
	install_ts   i64 = 0
	update_ts    i64 = 0
}

struct SearchAnnotation {
mut:
	text            string
	installed_count int
}

struct BrewInfo {
mut:
	version string
	desc    string
}

struct UpableEntry {
	name    string
mut:
	old_ver string = '-'
	new_ver string = '-'
}

struct UpableConfig {
mut:
	max int = 10
}

// ==================== 包管理器定义 ====================

const managers = [
	PkgManager{
		name: 'pacman'
		cmd: 'pacman'
		search_tpl: 'pacman -Ss {q}'
		info_tpl: 'pacman -Si {q}'
		list_cmd: 'pacman -Q'
		installed_cmd: 'pacman -Qq'
		fetch_tpl: 'pacman -Sw {q}'
		fetch_recursive_tpl: 'pacman -Sw --recursive {q}'
		files_tpl: 'pacman -Ql {q}'
		has_native_installed_mark: true
	},
	PkgManager{
		name: 'apt'
		cmd: 'apt'
		search_tpl: 'apt search {q}'
		info_tpl: 'apt show {q}'
		list_cmd: r'dpkg-query -W -f="${Package}\n"'
		installed_cmd: r'dpkg-query -W -f="${Package}\n"'
		fetch_tpl: 'apt download {q}'
		fetch_recursive_tpl: 'apt-get install --download-only -y {q}'
		files_tpl: 'dpkg -L {q}'
		has_native_installed_mark: true
	},
	PkgManager{
		name: 'vcpkg'
		cmd: 'vcpkg'
		search_tpl: 'vcpkg search {q}'
		info_tpl: 'vcpkg x-package-info {q} --x-json'
		list_cmd: 'vcpkg list'
		installed_cmd: 'vcpkg list'
		fetch_tpl: 'vcpkg install --only-downloads {q}'
		fetch_recursive_tpl: 'vcpkg install --only-downloads {q}'
		files_tpl: ''
		info_parser: 'vcpkg'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'brew'
		cmd: 'brew'
		search_tpl: 'brew search {q}'
		info_tpl: 'brew info {q}'
		list_cmd: 'brew list'
		installed_cmd: 'brew list -1'
		fetch_tpl: 'brew fetch {q}'
		fetch_recursive_tpl: 'brew fetch --deps {q}'
		files_tpl: 'brew list {q}'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'port'
		cmd: 'port'
		search_tpl: 'port search {q}'
		info_tpl: 'port info {q}'
		list_cmd: 'port installed'
		installed_cmd: 'port installed'
		fetch_tpl: 'port fetch {q}'
		fetch_recursive_tpl: 'port fetch rdepof:{q} {q}'
		files_tpl: 'port contents {q}'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'rpm'
		cmd: 'rpm'
		search_tpl: 'rpm -qa | grep -i {q}'
		info_tpl: 'rpm -qi {q}'
		list_cmd: 'rpm -qa'
		installed_cmd: 'rpm -qa'
		fetch_tpl: 'yumdownloader {q}'
		fetch_recursive_tpl: 'yumdownloader --resolve {q}'
		files_tpl: 'rpm -ql {q}'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'apk'
		cmd: 'apk'
		search_tpl: 'apk search -v {q}'
		info_tpl: 'apk info -a {q}'
		list_cmd: 'apk info'
		installed_cmd: 'apk info'
		fetch_tpl: 'apk fetch {q}'
		fetch_recursive_tpl: ''
		files_tpl: 'apk info -L {q}'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'pkg (Termux)'
		cmd: 'pkg'
		search_tpl: 'pkg search {q}'
		info_tpl: 'pkg show {q}'
		list_cmd: 'pkg list-installed | cut -d/ -f1'
		installed_cmd: 'pkg list-installed | cut -d/ -f1'
		fetch_tpl: 'apt download {q}'
		fetch_recursive_tpl: 'apt-get install --download-only -y {q}'
		files_tpl: 'pkg files {q}'
		has_native_installed_mark: false
	},
	PkgManager{
		name: 'pm (Android)'
		cmd: 'pm'
		search_tpl: 'pm list packages -f | grep -i {q}'
		info_tpl: 'pm dump {q}'
		list_cmd: 'pm list packages | sed s/package://'
		installed_cmd: 'pm list packages | sed s/package://'
		fetch_tpl: ''
		fetch_recursive_tpl: ''
		files_tpl: ''
		has_native_installed_mark: false
	},
]

// ==================== Linux 发行版检测 ====================

fn detect_distro() string {
	if !os.exists('/etc/os-release') { return '' }
	content := os.read_file('/etc/os-release') or { return '' }
	mut id := ''
	mut id_like := ''
	for line in content.split_into_lines() {
		t := line.trim_space()
		if t.starts_with('ID_LIKE=') {
			id_like = t.all_after('ID_LIKE=').trim('"').to_lower()
		} else if t.starts_with('ID=') {
			id = t.all_after('ID=').trim('"').to_lower()
		}
	}
	if id_like.len > 0 {
		if id_like.contains('debian') || id_like.contains('ubuntu') { return 'debian' }
		if id_like.contains('rhel') || id_like.contains('fedora') || id_like.contains('centos') { return 'rhel' }
		if id_like.contains('arch') { return 'arch' }
		if id_like.contains('suse') || id_like.contains('opensuse') { return 'suse' }
	}
	return id
}

// ==================== 按操作系统/发行版排序（高频在后） ====================

fn get_ordered_managers() []PkgManager {
	mut ordered := managers.clone()
	os_name := os.user_os()

	// priority 数组按“高频 → 低频”书写
	priority := if os_name == 'linux' {
		distro := detect_distro()
		match distro {
			'ubuntu', 'debian', 'linuxmint', 'pop', 'elementary', 'zorin', 'kali', 'deepin', 'raspbian' {
				['apt', 'rpm', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
			'fedora', 'rhel', 'centos', 'rocky', 'alma', 'ol', 'amzn' {
				['rpm', 'apt', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
			'arch', 'manjaro', 'endeavouros', 'garuda', 'artix' {
				['pacman', 'apt', 'rpm', 'apk', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
			'opensuse', 'suse', 'sles', 'opensuse-leap', 'opensuse-tumbleweed' {
				['rpm', 'apt', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
			'alpine' {
				['apk', 'apt', 'rpm', 'pacman', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
			'android' {
				['pkg (Termux)', 'pm (Android)', 'apt', 'rpm', 'pacman', 'apk', 'brew', 'vcpkg', 'port']
			}
			else {
				['apt', 'rpm', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'port']
			}
		}
	} else if os_name == 'macos' {
		['brew', 'port', 'vcpkg', 'apt', 'rpm', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)']
	} else if os_name == 'windows' {
		['vcpkg', 'brew', 'port', 'apt', 'rpm', 'pacman', 'apk', 'pkg (Termux)', 'pm (Android)']
	} else if os_name == 'android' {
		['pkg (Termux)', 'pm (Android)', 'apt', 'brew', 'vcpkg', 'port', 'rpm', 'pacman', 'apk']
	} else {
		['port', 'pkg (Termux)', 'pm (Android)', 'brew', 'vcpkg', 'apt', 'rpm', 'pacman', 'apk']
	}

	mut result := []PkgManager{}
	for name in priority {
		for m in ordered {
			if m.name == name {
				result << m
			}
		}
	}
	for m in ordered {
		if m.name !in priority {
			result << m
		}
	}

	// 反转：低频先显示，高频后显示
	result.reverse_in_place()
	return result
}

// ==================== 通用工具 ====================

fn command_exists(cmd string) bool {
	path := os.find_abs_path_of_executable(cmd) or { return false }

	// macOS 上的 /usr/bin/apt 是 Java Annotation Processing Tool，不是包管理器
	if os.user_os() == 'macos' && cmd == 'apt' && path == '/usr/bin/apt' {
		return false
	}

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

fn human_size(bytes i64) string {
	if bytes <= 0 { return '-' }
	units := ['B', 'KiB', 'MiB', 'GiB', 'TiB']
	mut v := f64(bytes)
	mut idx := 0
	for v >= 1024.0 && idx < units.len - 1 {
		v /= 1024.0
		idx++
	}
	return '${v:.1f} ${units[idx]}'
}

fn natural_cmp(a string, b string) int {
	mut i := 0
	mut j := 0
	for i < a.len && j < b.len {
		if a[i].is_digit() && b[j].is_digit() {
			mut na := ''
			for i < a.len && a[i].is_digit() { na += a[i].ascii_str(); i++ }
			mut nb := ''
			for j < b.len && b[j].is_digit() { nb += b[j].ascii_str(); j++ }
			ia := na.int()
			ib := nb.int()
			if ia != ib { return if ia < ib { -1 } else { 1 } }
		} else {
			if a[i] != b[j] { return if a[i] < b[j] { -1 } else { 1 } }
			i++
			j++
		}
	}
	return a.len - b.len
}

fn sort_natural(mut names []string) {
	names.sort_with_compare(fn (a &string, b &string) int {
		return natural_cmp(*a, *b)
	})
}

fn parse_human_size(s string) i64 {
	parts := s.split(' ')
	if parts.len < 2 { return 0 }
	val := parts[0].f64()
	unit := parts[1].to_lower()
	multiplier := match unit {
		'b', 'bytes' { i64(1) }
		'kib', 'kb' { i64(1024) }
		'mib', 'mb' { i64(1024 * 1024) }
		'gib', 'gb' { i64(1024 * 1024 * 1024) }
		else { i64(1) }
	}
	return i64(val * multiplier)
}

// ==================== 获取已安装包集合 ====================

fn get_installed_set(mgr PkgManager) map[string]bool {
	mut set := map[string]bool{}
	if mgr.installed_cmd.len == 0 { return set }

	raw := os.execute(mgr.installed_cmd).output.trim_space()
	if raw.len == 0 { return set }

	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 { continue }

		name := match mgr.name {
			'pacman', 'apk', 'brew', 'rpm' { t.fields()[0] }
			'apt' { t }
			'vcpkg' {
				parts := t.fields()
				if parts.len > 0 && parts[0].contains(':') { parts[0] } else { t }
			}
			'port' { t.fields()[0] }
			'pkg (Termux)' { t.split('/')[0] }
			'pm (Android)' { t }
			else { t }
		}

		if name.len > 0 {
			set[name] = true
		}
	}

	return set
}

// ==================== brew 搜索富化 ====================

fn enrich_brew_search(output string, limit int) map[string]BrewInfo {
	mut info_map := map[string]BrewInfo{}
	mut names := []string{}
	mut seen := map[string]bool{}

	for line in output.split('\n') {
		trimmed := line.trim_space()
		if trimmed.len == 0 { continue }
		sp := trimmed.index(' ') or { -1 }
		name := if sp > 0 { trimmed[..sp] } else { trimmed }
		if !seen[name] {
			seen[name] = true
			names << name
		}
	}

	actual_limit := if limit > 0 && names.len > limit { limit } else { names.len }

	for i := 0; i < actual_limit; i++ {
		name := names[i]
		cmd := 'brew info --json=v2 ${escape_shell(name)} 2>/dev/null'
		res := os.execute(cmd)
		if res.exit_code != 0 { continue }

		json_str := res.output.trim_space()
		root := json2.decode[map[string]json2.Any](json_str) or { continue }

		mut info := BrewInfo{}
		if formulae := root['formulae'] {
			arr := formulae.arr()
			if arr.len > 0 {
				mp := arr[0].as_map()
				if v := mp['versions'] {
					vmap := v.as_map()
					if stable := vmap['stable'] {
						info.version = stable.str()
					}
				}
				if d := mp['desc'] {
					info.desc = d.str()
				}
			}
		} else if casks := root['casks'] {
			arr := casks.arr()
			if arr.len > 0 {
				mp := arr[0].as_map()
				if v := mp['version'] {
					info.version = v.str()
				}
				if d := mp['desc'] {
					info.desc = d.str()
				}
			}
		}

		info_map[name] = info
	}

	return info_map
}

// ==================== 行尾标注 + 统计已安装 ====================

fn annotate_search_with_installed(output string, mgr PkgManager, query string) SearchAnnotation {
	mut ann := SearchAnnotation{}

	if mgr.has_native_installed_mark {
		for line in output.split('\n') {
			ann.installed_count += line.count('[installed')
		}
		ann.text = colorize_output(output, 'search')
		return ann
	}

	if mgr.name in ['rpm', 'pm (Android)'] {
		mut lines := []string{}
		for line in output.split('\n') {
			if line.trim_space().len > 0 {
				ann.installed_count++
			}
			lines << colorize_line(line, 'search')
		}
		ann.text = lines.join('\n')
		return ann
	}

	mut brew_info := map[string]BrewInfo{}
	if mgr.name == 'brew' {
		brew_info = enrich_brew_search(output, 10)
	}

	installed_set := get_installed_set(mgr)
	mut lines := []string{}
	for line in output.split('\n') {
		trimmed := line.trim_space()
		if trimmed.len == 0 {
			lines << line
			continue
		}

		first_token := ''
		sp := trimmed.index(' ') or { -1 }
		if sp > 0 {
			first_token = trimmed[..sp]
		} else {
			first_token = trimmed
		}

		lookup := first_token
		if mgr.name == 'vcpkg' && lookup.contains(':') {
			lookup = lookup.split(':')[0]
		}

		is_installed := installed_set[lookup] or { installed_set[first_token] or { false } }

		mut colored_line := ''
		if mgr.name == 'brew' {
			info := brew_info[lookup] or { BrewInfo{} }
			mut line_content := first_token
			if info.version.len > 0 {
				line_content += ' (${info.version})'
			}
			if info.desc.len > 0 {
				line_content += ' - ${info.desc}'
			}
			rest := trimmed[first_token.len..]
			colored_line = colorize_line(line_content + rest, 'search')
		} else {
			colored_line = colorize_line(line, 'search')
		}

		if is_installed {
			ann.installed_count++
			marker := if use_color { ' ' + term.green('[installed]') } else { ' [installed]' }
			lines << colored_line + marker
		} else {
			lines << colored_line
		}
	}

	ann.text = lines.join('\n')
	return ann
}

// ==================== 通用输出着色 ====================

fn has_ansi(s string) bool {
	return s.contains('\x1b[')
}

fn is_field_key(s string) bool {
	if s.len == 0 || s.len > 30 { return false }
	if !s[0].is_letter() { return false }
	for c in s {
		if !(c.is_letter() || c.is_digit() || c == ` ` || c == `-` || c == `_` || c == `.`) {
			return false
		}
	}
	if s.trim_space().len == 0 { return false }
	return true
}

fn is_pkg_token(s string) bool {
	if s.len == 0 || s.len > 100 { return false }
	if !(s[0].is_letter() || s[0].is_digit()) { return false }
	if s.contains('...') || s.contains(':') { return false }
	for c in s {
		if !(c.is_letter() || c.is_digit() || c == `-` || c == `_` || c == `+` || c == `.` || c == `/` || c == `@`) {
			return false
		}
	}
	return true
}

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
	if line.len == 0 || has_ansi(line) { return line }
	if line.trim_space().len == 0 { return line }

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
	if !use_color { return text }
	mut lines := []string{}
	for line in text.split('\n') {
		lines << colorize_line(line, action)
	}
	return lines.join('\n')
}

// ==================== 主命令预览 ====================

fn get_list_cmd(mgr PkgManager) string {
	return match mgr.name {
		'pacman' { 'pacman -Qi' }
		'apt' { r"dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}\t${db-fsys:Last-Modified}\n'" }
		'brew' { 'brew info --json=v2 --installed  (fallback: brew list --versions)' }
		'rpm' { r"rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\t%{INSTALLTIME}\n'" }
		'apk' { 'apk query --installed --format json' }
		'vcpkg' { 'vcpkg list' }
		'port' { 'port installed  +  sqlite3 registry.db (SELECT name, date FROM ports)' }
		'pm (Android)' { 'pm list packages  +  pm path <pkg>' }
		'pkg (Termux)' { r"dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}\t${db-fsys:Last-Modified}\n'" }
		else { mgr.list_cmd }
	}
}

// ==================== vcpkg 辅助 ====================

fn get_vcpkg_root() string {
	r := os.getenv('VCPKG_ROOT')
	if r.len > 0 { return r }

	out := os.execute('vcpkg root 2>/dev/null').output.trim_space()
	if out.len > 0 && os.exists('${out}/installed') { return out }

	bin := os.find_abs_path_of_executable('vcpkg') or { '' }
	if bin.len > 0 {
		dir := os.dir(bin)
		candidates := [dir, os.dir(dir)]
		for c in candidates {
			if os.exists('${c}/installed') { return c }
		}
		share := os.dir(dir) + '/share/vcpkg'
		if os.exists('${share}/installed') { return share }
	}
	return ''
}

fn get_vcpkg_cache_size() string {
	mut cache_dir := os.getenv('VCPKG_DEFAULT_BINARY_CACHE')
	if cache_dir.len == 0 {
		xdg := os.getenv('XDG_CACHE_HOME')
		if xdg.len > 0 {
			cache_dir = '${xdg}/vcpkg/archives'
		} else {
			home := os.getenv('HOME')
			if home.len > 0 {
				cache_dir = '${home}/.cache/vcpkg/archives'
			}
		}
	}
	if cache_dir.len == 0 || !os.exists(cache_dir) { return '' }

	cmd := "find ${escape_shell(cache_dir)} -name '*.zip' -type f -printf '%s\\n' 2>/dev/null | awk '{sum+=$1} END {print sum}'"
	out := os.execute(cmd).output.trim_space()
	if out.len == 0 || out == '0' { return '' }
	return human_size(out.i64())
}

// ==================== 各包管理器的 list 实现 ====================

fn list_pacman() []PkgEntry {
	raw := os.execute('pacman -Qi').output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []PkgEntry{}
	mut cur := PkgEntry{ name: '' }
	mut has := false
	for line in raw.split_into_lines() {
		t := line.trim_space()
		colon := t.index(':') or { -1 }
		if colon <= 0 { continue }
		key := t[..colon].trim_space()
		val := t[colon+1..].trim_space()
		if key == 'Name' {
			if has && cur.name.len > 0 { entries << cur }
			cur = PkgEntry{ name: val }
			has = true
		} else if key == 'Version' {
			cur.version = val
		} else if key == 'Installed Size' {
			cur.size_str = val
			cur.size = parse_human_size(val)
		} else if key == 'Install Date' {
			cur.install_date = val
		}
	}
	if has && cur.name.len > 0 { entries << cur }
	return entries
}

fn list_apt() []PkgEntry {
	cmd := r"dpkg-query -W -f='${Package}\t${Version}\t${Installed-Size}\t${db-fsys:Last-Modified}\n'"
	raw := os.execute(cmd).output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		parts := line.split('\t')
		if parts.len < 4 { continue }
		name := parts[0].trim_space()
		if name.len == 0 { continue }
		size_kib := parts[2].trim_space().i64()
		mut e := PkgEntry{
			name: name
			version: parts[1].trim_space()
			size: size_kib * 1024
			size_str: human_size(size_kib * 1024)
		}
		ts := parts[3].trim_space().i64()
		if ts == 0 {
			info_file := '/var/lib/dpkg/info/${name}.list'
			if os.exists(info_file) {
				if st := os.stat(info_file) { ts = st.mtime }
			}
		}
		if ts > 0 {
			e.install_ts = ts
			e.install_date = time.unix(ts).format_ss()
		}
		entries << e
	}
	return entries
}

fn list_rpm() []PkgEntry {
	cmd := r"rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{SIZE}\t%{INSTALLTIME}\n'"
	raw := os.execute(cmd).output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		parts := line.split('\t')
		if parts.len < 4 { continue }
		name := parts[0].trim_space()
		if name.len == 0 { continue }
		size := parts[2].trim_space().i64()
		ts := parts[3].trim_space().i64()
		mut e := PkgEntry{
			name: name
			version: parts[1].trim_space()
			size: size
			size_str: human_size(size)
		}
		if ts > 0 {
			e.install_ts = ts
			e.install_date = time.unix(ts).format_ss()
		}
		entries << e
	}
	return entries
}

fn list_apk() []PkgEntry {
	raw := os.execute('apk query --installed --format json').output.trim_space()
	if raw.len == 0 { return [] }
	parsed := json2.decode[[]map[string]json2.Any](raw) or { return [] }
	mut entries := []PkgEntry{}
	for item in parsed {
		name := if n := item['name'] { n.str() } else { '' }
		if name.len == 0 { continue }
		version := if v := item['version'] { v.str() } else { '-' }
		size := if s := item['installed-size'] { s.i64() } else { 0 }
		e := PkgEntry{
			name: name
			version: version
			size: size
			size_str: human_size(size)
		}
		entries << e
	}
	return entries
}

fn list_brew() []PkgEntry {
	json_raw := os.execute('brew info --json=v2 --installed 2>/dev/null').output.trim_space()
	if json_raw.len > 0 {
		root := json2.decode[map[string]json2.Any](json_raw) or { map[string]json2.Any{} }
		if formulae := root['formulae'] {
			arr := formulae.arr()
			if arr.len > 0 {
				mut entries := []PkgEntry{}
				for item in arr {
					mp := item.as_map()
					name := if n := mp['name'] { n.str() } else { '' }
					if name.len == 0 { continue }
					mut e := PkgEntry{ name: name }
					if installed := mp['installed'] {
						inst_arr := installed.arr()
						if inst_arr.len > 0 {
							inst := inst_arr[0].as_map()
							if ver := inst['version'] { e.version = ver.str() }
							if t := inst['time'] {
								ts := t.i64()
								if ts > 0 {
									e.install_ts = ts
									e.install_date = time.unix(ts).format_ss()
									e.update_date = e.install_date
									e.update_ts = ts
								}
							}
						}
					}
					entries << e
				}
				cellar := os.execute('brew --cellar').output.trim_space()
				if cellar.len == 0 { cellar = '/opt/homebrew/Cellar' }
				mut size_map := map[string]i64{}
				du_cmd := 'du -sk ${cellar}/*/* 2>/dev/null'
				println('\$ ${du_cmd}')
				du_raw := os.execute(du_cmd).output
				for line in du_raw.split_into_lines() {
					fields := line.fields()
					if fields.len < 2 { continue }
					kib := fields[0].i64()
					parts := fields[1].split('/')
					if parts.len >= 2 {
						pkg := parts[parts.len - 2]
						size_map[pkg] = (size_map[pkg] or { i64(0) }) + kib * 1024
					}
				}
				for mut e in entries {
					if s := size_map[e.name] {
						e.size = s
						e.size_str = human_size(s)
					}
				}
				return entries
			}
		}
	}

	raw := os.execute('brew list --versions').output.trim_space()
	if raw.len == 0 { return [] }
	cellar := os.execute('brew --cellar').output.trim_space()
	if cellar.len == 0 { cellar = '/opt/homebrew/Cellar' }

	mut versions := map[string]string{}
	for line in raw.split_into_lines() {
		parts := line.fields()
		if parts.len < 2 { continue }
		name := parts[0]
		versions[name] = if parts.len >= 3 { parts[parts.len - 1] } else { parts[1] }
	}

	mut size_map := map[string]i64{}
	du_cmd := 'du -sk ${cellar}/*/* 2>/dev/null'
	println('\$ ${du_cmd}')
	du_raw := os.execute(du_cmd).output
	for line in du_raw.split_into_lines() {
		fields := line.fields()
		if fields.len < 2 { continue }
		kib := fields[0].i64()
		parts := fields[1].split('/')
		if parts.len >= 2 {
			pkg := parts[parts.len - 2]
			size_map[pkg] = (size_map[pkg] or { i64(0) }) + kib * 1024
		}
	}

	mut time_map := map[string]i64{}
	stat_cmd := 'stat -c "%Y %n" ${cellar}/*/*/INSTALL_RECEIPT.json 2>/dev/null'
	println('\$ ${stat_cmd}')
	stat_raw := os.execute(stat_cmd).output
	for line in stat_raw.split_into_lines() {
		fields := line.fields()
		if fields.len < 2 { continue }
		ts := fields[0].i64()
		parts := fields[1].split('/')
		if parts.len >= 3 {
			pkg := parts[parts.len - 3]
			if ts > (time_map[pkg] or { i64(0) }) { time_map[pkg] = ts }
		}
	}

	mut entries := []PkgEntry{}
	mut names := []string{}
	for n, _ in versions { names << n }
	sort_natural(mut names)
	for name in names {
		mut e := PkgEntry{ name: name }
		e.version = versions[name]
		if s := size_map[name] {
			e.size = s
			e.size_str = human_size(s)
		}
		if ts := time_map[name] {
			e.install_ts = ts
			e.install_date = time.unix(ts).format_ss()
			e.update_date = e.install_date
			e.update_ts = ts
		}
		entries << e
	}
	return entries
}

fn list_vcpkg() []PkgEntry {
	raw := os.execute('vcpkg list').output.trim_space()
	if raw.len == 0 { return [] }

	root := get_vcpkg_root()
	println('  vcpkg root: ${if root.len > 0 { root } else { '(未检测到)' }}')

	cache := get_vcpkg_cache_size()
	if cache.len > 0 { println('  binary cache: ${cache}') }

	mut global_ts := i64(0)
	if root.len > 0 {
		status_file := '${root}/installed/vcpkg/status'
		if os.exists(status_file) {
			if st := os.stat(status_file) { global_ts = st.mtime }
		}
	}

	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		parts := line.fields()
		if parts.len < 2 || !parts[0].contains(':') { continue }
		full := parts[0]
		if full.contains('[') { continue }

		version := parts[1]
		pkg := full.split(':')[0]
		triplet := full.split(':')[1]

		mut e := PkgEntry{ name: full, version: version }

		if root.len > 0 {
			share_dir := '${root}/installed/${triplet}/share/${pkg}'
			if os.exists(share_dir) {
				du := os.execute('du -sk ${escape_shell(share_dir)} 2>/dev/null').output
				ps := du.fields()
				if ps.len >= 1 {
					e.size = ps[0].i64() * 1024
					e.size_str = human_size(e.size)
				}
				if st := os.stat(share_dir) { e.install_ts = st.mtime }
			}

			info_file := '${root}/installed/vcpkg/info/${pkg}_${triplet}.list'
			if os.exists(info_file) {
				if st := os.stat(info_file) { e.install_ts = st.mtime }
			}

			if e.install_ts == 0 { e.install_ts = global_ts }
			if e.install_ts > 0 {
				e.install_date = time.unix(e.install_ts).format_ss()
			}
		}

		entries << e
	}
	return entries
}

fn list_port() []PkgEntry {
	raw := os.execute('port installed').output.trim_space()
	if raw.len == 0 { return [] }

	mut date_map := map[string]i64{}
	reg_db := '/opt/local/var/macports/registry/registry.db'
	if os.exists(reg_db) {
		sql_cmd := "sqlite3 ${escape_shell(reg_db)} \"SELECT name, date FROM ports;\" 2>/dev/null"
		println('\$ sqlite3 ${reg_db} "SELECT name, date FROM ports;"')
		sql_raw := os.execute(sql_cmd).output
		for line in sql_raw.split_into_lines() {
			parts := line.split('|')
			if parts.len >= 2 {
				name := parts[0].trim_space()
				ts := parts[1].trim_space().i64()
				if name.len > 0 && ts > 0 { date_map[name] = ts }
			}
		}
	}

	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 || t.starts_with('The following') || t.starts_with('None of the') { continue }
		parts := t.fields()
		if parts.len < 2 { continue }
		name := parts[0]
		version_raw := parts[1]
		version := if version_raw.starts_with('@') { version_raw[1..] } else { version_raw }

		mut e := PkgEntry{ name: name, version: version }

		if ts := date_map[name] {
			e.install_ts = ts
			e.install_date = time.unix(ts).format_ss()
		}

		sp := os.execute('port space ${escape_shell(name)} 2>/dev/null').output
		for sl in sp.split_into_lines() {
			fields := sl.trim_space().fields()
			for i, p in fields {
				low := p.to_lower()
				if low in ['bytes', 'b', 'kib', 'kb', 'mib', 'mb', 'gib', 'gb'] && i > 0 {
					size_bytes := parse_human_size('${fields[i-1]} ${p}')
					if size_bytes > 0 {
						e.size = size_bytes
						e.size_str = human_size(size_bytes)
						break
					}
				}
			}
		}
		entries << e
	}
	return entries
}

fn list_pm() []PkgEntry {
	raw := os.execute('pm list packages').output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		name := line.replace('package:', '').trim_space()
		if name.len == 0 { continue }
		mut e := PkgEntry{ name: name }

		dump_out := os.execute('pm dump ${escape_shell(name)} 2>/dev/null').output
		for dl in dump_out.split_into_lines() {
			t := dl.trim_space()
			if t.contains('versionName') {
				eq := t.index('=') or { -1 }
				if eq >= 0 { e.version = t[eq+1..].trim_space() }
			} else if t.contains('firstInstallTime') {
				eq := t.index('=') or { -1 }
				if eq >= 0 { e.install_date = t[eq+1..].trim_space() }
			} else if t.contains('lastUpdateTime') {
				eq := t.index('=') or { -1 }
				if eq >= 0 { e.update_date = t[eq+1..].trim_space() }
			}
		}

		path_out := os.execute('pm path ${escape_shell(name)} 2>/dev/null').output.trim_space()
		if path_out.len > 0 {
			apk_path := path_out.replace('package:', '').trim_space()
			if os.exists(apk_path) {
				if st := os.stat(apk_path) {
					e.size = st.size
					e.size_str = human_size(st.size)
				}
			}
		}

		entries << e
	}
	return entries
}

fn list_generic(cmd_str string) []PkgEntry {
	raw := os.execute(cmd_str).output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []PkgEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len > 0 { entries << PkgEntry{ name: t } }
	}
	return entries
}

fn execute_list(mgr PkgManager) []PkgEntry {
	return match mgr.name {
		'pacman' { list_pacman() }
		'apt' { list_apt() }
		'brew' { list_brew() }
		'rpm' { list_rpm() }
		'apk' { list_apk() }
		'vcpkg' { list_vcpkg() }
		'port' { list_port() }
		'pm (Android)' { list_pm() }
		'pkg (Termux)' { list_apt() }
		else { list_generic(mgr.list_cmd) }
	}
}

// ==================== 排序 ====================

fn sort_entries(mut entries []PkgEntry, mode string) {
	if mode == 'natural' {
		mut names := []string{}
		for e in entries { names << e.name }
		sort_natural(mut names)
		mut ordered := []PkgEntry{cap: entries.len}
		for n in names {
			for e in entries {
				if e.name == n { ordered << e; break }
			}
		}
		entries = ordered.clone()
	} else if mode == 'size' {
		entries.sort_with_compare(fn (a &PkgEntry, b &PkgEntry) int {
			if a.size != b.size { return if a.size > b.size { -1 } else { 1 } }
			return natural_cmp(a.name, b.name)
		})
	} else if mode == 'time' {
		entries.sort_with_compare(fn (a &PkgEntry, b &PkgEntry) int {
			if a.install_ts != b.install_ts {
				return if a.install_ts > b.install_ts { -1 } else { 1 }
			}
			return natural_cmp(a.name, b.name)
		})
	}
}

// ==================== 短选项展开 ====================

// 将短选项展开为长选项，供 flag.to_struct(style: .long) 使用
// 支持：-s <val> → --sort=<val>；-m <val> → --max=<val>；-m -1 → --max=-1；-r → --recursive
fn normalize_args(args []string) []string {
	mut result := []string{}
	mut i := 0
	for i < args.len {
		a := args[i]
		match a {
			'-s' {
				if i + 1 < args.len {
					result << '--sort=${args[i + 1]}'
					i += 2
				} else {
					result << '--sort'
					i += 1
				}
			}
			'-m' {
				if i + 1 < args.len {
					// 负数（-1 等）必须用 = 形式，否则 flag 会把它当成独立选项
					result << '--max=${args[i + 1]}'
					i += 2
				} else {
					result << '--max'
					i += 1
				}
			}
			'-r' {
				result << '--recursive'
				i += 1
			}
			else {
				result << a
				i += 1
			}
		}
	}
	return result
}

// ==================== 预处理 --max -1 ====================

fn preprocess_max_arg(args []string) []string {
	mut result := []string{}
	mut i := 0
	for i < args.len {
		a := args[i]
		if a == '--max' && i + 1 < args.len {
			nxt := args[i + 1]
			if nxt.starts_with('-') && nxt.len > 1 && nxt[1].is_digit() {
				result << '${a}=${nxt}'
				i += 2
				continue
			}
		}
		result << a
		i++
	}
	return result
}

// ==================== list 子命令 ====================

fn handle_list(args []string) {
	sanitized := preprocess_max_arg(normalize_args(args))
	mut cfg, no_matches := flag.to_struct[ListConfig](sanitized, skip: 0, style: .long) or {
		eprintln('参数错误: ${err}')
		exit(1)
	}
	if no_matches.len > 0 {
		eprintln('警告: 以下参数未被识别: ${no_matches}')
	}

	valid := ['natural', 'time', 'size']
	if cfg.sort !in valid {
		eprintln('无效的排序方式: ${cfg.sort}，可选: natural, time, size')
		exit(1)
	}
	if cfg.max < -1 {
		eprintln('无效的 max: ${cfg.max}，必须 >= -1')
		exit(1)
	}

	mut total := 0
	mut shown_total := 0

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { continue }

		main_cmd := get_list_cmd(mgr)
		max_label := if cfg.max < 0 { 'all' } else { cfg.max.str() }

		println('')
		println('========== [${mgr.name}] list (sort: ${cfg.sort}, max: ${max_label}) ==========')
		println('\$ ${main_cmd}')
		println('---------------------------------------------')

		mut entries := execute_list(mgr)
		if entries.len == 0 {
			println('  (无结果)')
			continue
		}

		sort_entries(mut entries, cfg.sort)

		total_for_mgr := entries.len
		total += total_for_mgr

		mut shown := entries.clone()
		if cfg.max >= 0 && shown.len > cfg.max {
			shown = shown[..cfg.max]
		}
		shown_total += shown.len

		idx_w := shown.len.str().len
		mut name_w := 4
		mut ver_w := 4
		for e in shown {
			if e.name.len > name_w { name_w = e.name.len }
			if e.version.len > ver_w { ver_w = e.version.len }
		}
		name_w += 2
		ver_w += 2

		for i, e in shown {
			num := '${i + 1}'
			idx := ' '.repeat(idx_w - num.len) + num
			name_pad := e.name + ' '.repeat(name_w - e.name.len)
			ver_pad := e.version + ' '.repeat(ver_w - e.version.len)
			mut line := '${idx}. ${name_pad}${ver_pad}'
			if e.size_str != '-' && e.size_str.len > 0 {
				line += '[${e.size_str}]  '
			}
			if e.install_date != '-' && e.install_date.len > 0 {
				line += '安装: ${e.install_date}  '
			}
			if e.update_date != '-' && e.update_date.len > 0 {
				line += '更新: ${e.update_date}'
			}
			println(line.trim_right(' '))
		}
		if shown.len < total_for_mgr {
			println('  ${c_dim('... (还有 ${total_for_mgr - shown.len} 个，使用 --max=-1 显示全部)')}')
		}
	}

	println('')
	if cfg.max < 0 {
		println('--- 汇总: 共 ${total} 个包 ---')
	} else {
		println('--- 汇总: 共 ${total} 个包，已显示 ${shown_total} 个（--max=${cfg.max}，-1 表示不限制） ---')
	}
}

// ==================== upable 子命令 ====================

// pacman -Qu: "name old_ver -> new_ver"
fn upable_pacman() []UpableEntry {
	raw := os.execute('pacman -Qu 2>/dev/null').output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 { continue }
		idx := t.index(' -> ') or { -1 }
		if idx < 0 { continue }
		left := t[..idx].trim_space()
		right := t[idx + 4..].trim_space()
		lf := left.fields()
		if lf.len < 1 { continue }
		name := lf[0]
		old_v := if lf.len >= 2 { lf[lf.len - 1] } else { '-' }
		entries << UpableEntry{ name: name, old_ver: old_v, new_ver: right }
	}
	return entries
}

// apt list --upgradable: "name/suite new_ver arch [upgradable from: old_ver]"
// pkg (Termux) 底层也是 apt，复用此逻辑
fn upable_apt() []UpableEntry {
	raw := os.execute('apt list --upgradable 2>/dev/null').output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 || t.starts_with('Listing') { continue }
		idx := t.index(' [upgradable from: ') or { -1 }
		head := if idx > 0 { t[..idx].trim_space() } else { t }
		hf := head.fields()
		if hf.len < 2 { continue }
		first := hf[0]
		slash := first.index('/') or { -1 }
		name := if slash > 0 { first[..slash] } else { first }
		new_v := hf[1]
		mut old_v := '-'
		if idx > 0 {
			from_part := t[idx + ' [upgradable from: '.len..]
			old_v = from_part.trim_right(']').trim_space()
		}
		entries << UpableEntry{ name: name, old_ver: old_v, new_ver: new_v }
	}
	return entries
}

// brew outdated --json=v2（结构最稳）；回退到文本 "name (old) < new"
fn upable_brew() []UpableEntry {
	mut entries := []UpableEntry{}
	json_raw := os.execute('brew outdated --json=v2 2>/dev/null').output.trim_space()
	if json_raw.len > 0 {
		root := json2.decode[map[string]json2.Any](json_raw) or { map[string]json2.Any{} }
		if f := root['formulae'] {
			for item in f.arr() {
				mp := item.as_map()
				name := if n := mp['name'] { n.str() } else { '' }
				if name.len == 0 { continue }
				mut old_v := '-'
				if iv := mp['installed_versions'] {
					arr := iv.arr()
					if arr.len > 0 { old_v = arr[0].str() }
				}
				new_v := if cv := mp['current_version'] { cv.str() } else { '-' }
				entries << UpableEntry{ name: name, old_ver: old_v, new_ver: new_v }
			}
		}
		if c := root['casks'] {
			for item in c.arr() {
				mp := item.as_map()
				name := if n := mp['name'] { n.str() } else { '' }
				if name.len == 0 { continue }
				mut old_v := '-'
				if iv := mp['installed_versions'] {
					if iv.arr().len > 0 { old_v = iv.arr()[0].str() }
				}
				new_v := if cv := mp['current_version'] { cv.str() } else { '-' }
				entries << UpableEntry{ name: name + ' [cask]', old_ver: old_v, new_ver: new_v }
			}
		}
		return entries
	}
	raw := os.execute('brew outdated 2>/dev/null').output.trim_space()
	if raw.len == 0 { return [] }
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 { continue }
		sp := t.index(' (') or { -1 }
		lt := t.index(' < ') or { -1 }
		if sp < 0 || lt < 0 { continue }
		name := t[..sp]
		old_part := t[sp + 2..lt].trim_right(')').trim_space()
		new_v := t[lt + 3..].trim_space()
		entries << UpableEntry{ name: name, old_ver: old_part, new_ver: new_v }
	}
	return entries
}

// port outdated: "name old < new"
fn upable_port() []UpableEntry {
	raw := os.execute('port outdated 2>/dev/null').output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 || t.starts_with('The following') || t.starts_with('None of the') { continue }
		lt := t.index(' < ') or { -1 }
		if lt < 0 { continue }
		left := t[..lt].trim_space()
		right := t[lt + 3..].trim_space()
		lf := left.fields()
		if lf.len < 2 { continue }
		name := lf[0]
		old_v := lf[lf.len - 1]
		entries << UpableEntry{ name: name, old_ver: old_v, new_ver: right }
	}
	return entries
}

// apk version -l '<' : "name-version < new_version"
// 版本号以 -<digit> 开头，从左边第一个 "-数字" 处切分 name
fn upable_apk() []UpableEntry {
	raw := os.execute("apk version -l '<' 2>/dev/null").output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 || t.starts_with('Installed') { continue }
		lt := t.index(' < ') or { -1 }
		if lt < 0 { continue }
		left := t[..lt].trim_space()
		right := t[lt + 3..].trim_space()
		rf := right.fields()
		new_v := if rf.len > 0 { rf[0] } else { right }
		mut name := left
		mut old_v := '-'
		for i := 0; i < left.len - 1; i++ {
			if left[i] == `-` && left[i + 1].is_digit() {
				name = left[..i]
				old_v = left[i + 1..]
				break
			}
		}
		entries << UpableEntry{ name: name, old_ver: old_v, new_ver: new_v }
	}
	return entries
}

// rpm：需要 dnf/yum；check-update 退出码 100 表示有更新
fn upable_rpm() []UpableEntry {
	mut tool := ''
	if (os.find_abs_path_of_executable('dnf') or { '' }).len > 0 { tool = 'dnf' }
	else if (os.find_abs_path_of_executable('yum') or { '' }).len > 0 { tool = 'yum' }
	else { return [] }
	res := os.execute('${tool} check-update -q 2>/dev/null')
	if res.exit_code != 100 { return [] }
	raw := res.output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.len == 0 { continue }
		if t.starts_with('Last metadata') || t.starts_with('Obsoleting') || t.starts_with('Security:') { continue }
		f := t.fields()
		if f.len < 2 { continue }
		full := f[0]
		dot := full.last_index('.') or { -1 }
		name := if dot > 0 { full[..dot] } else { full }
		new_v := f[1]
		mut old_v := '-'
		qv := os.execute('rpm -q --qf "%{VERSION}-%{RELEASE}" ${escape_shell(name)} 2>/dev/null').output.trim_space()
		if qv.len > 0 && !qv.starts_with('package') {
			old_v = qv
		}
		entries << UpableEntry{ name: name, old_ver: old_v, new_ver: new_v }
	}
	return entries
}

// vcpkg update：解析 "will be rebuilt or updated" 段
fn upable_vcpkg() []UpableEntry {
	res := os.execute('vcpkg update 2>/dev/null')
	raw := res.output.trim_space()
	if raw.len == 0 { return [] }
	mut entries := []UpableEntry{}
	mut in_updatable := false
	for line in raw.split_into_lines() {
		t := line.trim_space()
		if t.contains('will be rebuilt or updated') {
			in_updatable = true
			continue
		}
		if t.contains('up-to-date') || t.contains('No packages') {
			in_updatable = false
			continue
		}
		if !in_updatable { continue }
		arrow := t.index(' -> ') or { -1 }
		if arrow < 0 { continue }
		left := t[..arrow].trim_space()
		right := t[arrow + 4..].trim_space()
		at := left.index('@') or { -1 }
		if at < 0 { continue }
		name_part := left[..at]
		old_v := left[at + 1..]
		entries << UpableEntry{ name: name_part, old_ver: old_v, new_ver: right }
	}
	return entries
}

fn execute_upable(mgr PkgManager) []UpableEntry {
	return match mgr.name {
		'pacman' { upable_pacman() }
		'apt' { upable_apt() }
		'brew' { upable_brew() }
		'port' { upable_port() }
		'apk' { upable_apk() }
		'rpm' { upable_rpm() }
		'vcpkg' { upable_vcpkg() }
		'pkg (Termux)' { upable_apt() }
		else { [] }
	}
}

fn get_upable_cmd_label(mgr PkgManager) string {
	return match mgr.name {
		'pacman' { 'pacman -Qu' }
		'apt', 'pkg (Termux)' { 'apt list --upgradable' }
		'brew' { 'brew outdated --json=v2' }
		'port' { 'port outdated' }
		'apk' { "apk version -l '<'" }
		'rpm' { 'dnf check-update -q  (或 yum check-update -q)' }
		'vcpkg' { 'vcpkg update' }
		else { '' }
	}
}

fn handle_upable(args []string) {
	sanitized := preprocess_max_arg(normalize_args(args))
	mut cfg, no_matches := flag.to_struct[UpableConfig](sanitized, skip: 0, style: .long) or {
		eprintln('参数错误: ${err}')
		exit(1)
	}
	if no_matches.len > 0 {
		eprintln('警告: 以下参数未被识别: ${no_matches}')
	}
	if cfg.max < -1 {
		eprintln('无效的 max: ${cfg.max}，必须 >= -1')
		exit(1)
	}

	mut total := 0
	mut shown_total := 0

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { continue }

		label := get_upable_cmd_label(mgr)
		if label.len == 0 { continue }

		max_label := if cfg.max < 0 { 'all' } else { cfg.max.str() }

		println('')
		println('========== [${mgr.name}] upable (max: ${max_label}) ==========')
		println('\$ ${label}')
		println('---------------------------------------------')

		mut entries := execute_upable(mgr)
		if entries.len == 0 {
			println('  (无更新)')
			continue
		}

		entries.sort_with_compare(fn (a &UpableEntry, b &UpableEntry) int {
			return natural_cmp(a.name, b.name)
		})

		total_for_mgr := entries.len
		total += total_for_mgr

		mut shown := entries.clone()
		if cfg.max >= 0 && shown.len > cfg.max {
			shown = shown[..cfg.max]
		}
		shown_total += shown.len

		idx_w := shown.len.str().len
		mut name_w := 4
		for e in shown {
			if e.name.len > name_w { name_w = e.name.len }
		}
		name_w += 2

		for i, e in shown {
			num := '${i + 1}'
			idx := ' '.repeat(idx_w - num.len) + num
			name_pad := e.name + ' '.repeat(name_w - e.name.len)
			mut line := '${idx}. ${name_pad}'
			if e.old_ver != '-' && e.old_ver.len > 0 {
				line += '${e.old_ver} -> ${e.new_ver}'
			} else {
				line += '-> ${e.new_ver}'
			}
			println(line)
		}
		if shown.len < total_for_mgr {
			println('  ${c_dim('... (还有 ${total_for_mgr - shown.len} 个，使用 --max=-1 显示全部)')}')
		}
	}

	println('')
	if cfg.max < 0 {
		println('--- 汇总: 共 ${total} 个可更新包 ---')
	} else {
		println('--- 汇总: 共 ${total} 个可更新包，已显示 ${shown_total} 个（--max=${cfg.max}，-1 表示不限制） ---')
	}
}

// ==================== syncn 子命令 ====================

// 返回模拟同步命令；空字符串表示该包管理器不支持模拟。
// 依据各包管理器文档核对：
//   pacman  : pacman -Sy -p         (打印将要同步的内容，不实际执行)
//   apt     : apt-get update --print-uris  (只打印 URI，不下载)
//   dnf/yum : check-update -q       (只检查更新，不做实际更改)
//   zypper  : refresh -D            (dry-run)
//   apk     : update --simulate     (模拟模式)
//   brew/port/vcpkg : 无 dry-run 支持
fn get_sync_simulate_cmd(mgr PkgManager) string {
	return match mgr.name {
		'pacman' { 'pacman -Sy -p' }
		'apt', 'pkg (Termux)' { 'apt-get update --print-uris' }
		'rpm' {
			if (os.find_abs_path_of_executable('dnf') or { '' }).len > 0 {
				'dnf check-update -q'
			} else if (os.find_abs_path_of_executable('yum') or { '' }).len > 0 {
				'yum check-update -q'
			} else if (os.find_abs_path_of_executable('zypper') or { '' }).len > 0 {
				'zypper refresh -D'
			} else {
				''
			}
		}
		'apk' { 'apk update --simulate' }
		else { '' }
	}
}

fn handle_syncn(args []string) {
	_ = args

	mut executed := 0
	mut skipped := 0
	mut unsupported_names := []string{}

	println('')
	println('========== 模拟同步软件仓库 (不会实际修改系统) ==========')

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { continue }

		cmd_str := get_sync_simulate_cmd(mgr)
		if cmd_str.len == 0 {
			println('')
			println('---------- [${mgr.name}] 该包管理器不支持模拟同步，跳过 ----------')
			skipped++
			unsupported_names << mgr.name
			continue
		}

		executed++
		println('')
		println('---------- [${mgr.name}] ----------')
		println('\$ ${cmd_str}')
		println('---------------------------------------------')

		res := os.execute(cmd_str)
		out := res.output.trim_space()
		if out.len > 0 {
			println(out)
		} else {
			println('  (无输出)')
		}

		// dnf/yum check-update: 100 表示有可用更新，视为正常
		// apt-get update --print-uris: 0 表示正常
		// pacman -Sy -p: 0 表示正常
		// apk update --simulate: 0 表示正常
		if res.exit_code != 0 && res.exit_code != 100 {
			println('  ⚠️ exit code ${res.exit_code}')
		}
	}

	println('')
	mut summary := '--- 汇总: 执行 ${executed} 个包管理器'
	if unsupported_names.len > 0 {
		summary += '，跳过 ${skipped} 个（${unsupported_names.join(', ')} 不支持模拟）'
	} else if skipped > 0 {
		summary += '，跳过 ${skipped} 个'
	}
	summary += ' ---'
	println(summary)
}

// ==================== addn 子命令（模拟安装） ====================

// 返回模拟安装命令；空字符串表示不支持。
// 依据各包管理器文档核对：
//   pacman  : pacman -Sp <pkg>                    (print, 不执行)
//   apt     : apt install --dry-run <pkg>          (dry-run)
//   dnf/yum : install --setopt=tsflags=test <pkg>  (test 事务)
//   zypper  : install --dry-run <pkg>
//   apk     : add --simulate <pkg>
//   brew    : install --dry-run <pkg>
//   port    : -y install <pkg>                    (-y = dry-run)
//   vcpkg   : install --dry-run <pkg>
fn get_add_simulate_cmd(mgr PkgManager, query string) string {
	safe_q := escape_shell(query)
	return match mgr.name {
		'pacman' { 'pacman -Sp ${safe_q}' }
		'apt', 'pkg (Termux)' { 'apt install --dry-run ${safe_q}' }
		'rpm' {
			if (os.find_abs_path_of_executable('dnf') or { '' }).len > 0 {
				'dnf install --setopt=tsflags=test ${safe_q}'
			} else if (os.find_abs_path_of_executable('yum') or { '' }).len > 0 {
				'yum install --setopt=tsflags=test ${safe_q}'
			} else if (os.find_abs_path_of_executable('zypper') or { '' }).len > 0 {
				'zypper install --dry-run ${safe_q}'
			} else {
				''
			}
		}
		'apk' { 'apk add --simulate ${safe_q}' }
		'brew' { 'brew install --dry-run ${safe_q}' }
		'port' { 'port -y install ${safe_q}' }
		'vcpkg' { 'vcpkg install --dry-run ${safe_q}' }
		else { '' }
	}
}

fn handle_addn(args []string) {
	mut query := ''
	for a in args {
		if !a.starts_with('-') {
			query = a
		}
	}

	if query.len == 0 {
		eprintln('错误: addn 需要一个包名')
		eprintln('用法: zpkg addn <包名>')
		exit(1)
	}

	println('')
	println('========== 模拟安装 ${query} (不会实际修改系统) ==========')

	mut executed := 0
	mut skipped := 0
	mut unsupported_names := []string{}

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { continue }

		cmd_str := get_add_simulate_cmd(mgr, query)
		if cmd_str.len == 0 {
			println('')
			println('---------- [${mgr.name}] 该包管理器不支持模拟安装，跳过 ----------')
			skipped++
			unsupported_names << mgr.name
			continue
		}

		executed++
		println('')
		println('---------- [${mgr.name}] ----------')
		println('\$ ${cmd_str}')
		println('---------------------------------------------')

		res := os.execute(cmd_str)
		out := res.output.trim_space()
		if out.len > 0 {
			println(out)
		} else {
			println('  (无输出)')
		}

		if res.exit_code != 0 {
			println('  ⚠️ exit code ${res.exit_code}')
		}
	}

	println('')
	mut summary := '--- 汇总: 执行 ${executed} 个包管理器'
	if unsupported_names.len > 0 {
		summary += '，跳过 ${skipped} 个（${unsupported_names.join(', ')} 不支持模拟）'
	} else if skipped > 0 {
		summary += '，跳过 ${skipped} 个'
	}
	summary += ' ---'
	println(summary)
}

// ==================== deln 子命令（模拟删除） ====================

// 返回模拟删除命令；空字符串表示不支持。
// 依据各包管理器文档核对：
//   pacman  : pacman -Rsp <pkg>                        (print, 不执行)
//   apt     : apt remove --dry-run <pkg>               (dry-run)
//   dnf/yum : remove --assumeno <pkg>                  (自动回答 "no")
//   zypper  : remove --dry-run <pkg>
//   apk     : del --simulate <pkg>
//   brew    : rm --dry-run <pkg>
//   port    : -y uninstall <pkg>                       (-y = dry-run)
//   vcpkg   : remove --dry-run <pkg>
fn get_del_simulate_cmd(mgr PkgManager, query string) string {
	safe_q := escape_shell(query)
	return match mgr.name {
		'pacman' { 'pacman -Rsp ${safe_q}' }
		'apt', 'pkg (Termux)' { 'apt remove --dry-run ${safe_q}' }
		'rpm' {
			if (os.find_abs_path_of_executable('dnf') or { '' }).len > 0 {
				'dnf remove --assumeno ${safe_q} 2>&1'
			} else if (os.find_abs_path_of_executable('yum') or { '' }).len > 0 {
				'yum remove --assumeno ${safe_q} 2>&1'
			} else if (os.find_abs_path_of_executable('zypper') or { '' }).len > 0 {
				'zypper remove --dry-run ${safe_q}'
			} else {
				''
			}
		}
		'apk' { 'apk del --simulate ${safe_q}' }
		'brew' { 'brew rm --dry-run ${safe_q}' }
		'port' { 'port -y uninstall ${safe_q}' }
		'vcpkg' { 'vcpkg remove --dry-run ${safe_q}' }
		else { '' }
	}
}

fn handle_deln(args []string) {
	mut query := ''
	mut recursive := false

	for a in args {
		if a in ['--recursive', '-r'] {
			recursive = true
		} else if !a.starts_with('-') {
			query = a
		}
	}

	if query.len == 0 {
		eprintln('错误: deln 需要一个包名')
		eprintln('用法: zpkg deln [-r|--recursive] <包名>')
		exit(1)
	}

	println('')
	println('========== 模拟删除 ${query} (不会实际修改系统) ==========')

	mut executed := 0
	mut skipped := 0
	mut unsupported_names := []string{}

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { continue }

		base_cmd := get_del_simulate_cmd(mgr, query)
		if base_cmd.len == 0 {
			println('')
			println('---------- [${mgr.name}] 该包管理器不支持模拟删除，跳过 ----------')
			skipped++
			unsupported_names << mgr.name
			continue
		}

		mut final_cmd := base_cmd
		if recursive {
			match mgr.name {
				'pacman' { final_cmd = 'pacman -Rsp --recursive ${escape_shell(query)}' }
				'apt', 'pkg (Termux)' { final_cmd = 'apt remove --dry-run --auto-remove ${escape_shell(query)}' }
				'apk' { final_cmd = 'apk del --simulate --recursive ${escape_shell(query)}' }
				else { /* 其他包管理器不追加递归参数 */ }
			}
		}

		executed++
		println('')
		println('---------- [${mgr.name}] ----------')
		println('\$ ${final_cmd}')
		println('---------------------------------------------')

		res := os.execute(final_cmd)
		out := res.output.trim_space()
		if out.len > 0 {
			println(out)
		} else {
			println('  (无输出)')
		}

		// dnf/yum remove --assumeno 在取消时退出码可能非 0，视为正常
		if res.exit_code != 0 && mgr.name != 'rpm' {
			println('  ⚠️ exit code ${res.exit_code}')
		}
	}

	println('')
	mut summary := '--- 汇总: 执行 ${executed} 个包管理器'
	if unsupported_names.len > 0 {
		summary += '，跳过 ${skipped} 个（${unsupported_names.join(', ')} 不支持模拟）'
	} else if skipped > 0 {
		summary += '，跳过 ${skipped} 个'
	}
	summary += ' ---'
	println(summary)
}

// ==================== fetch 子命令 ====================

fn handle_fetch(args []string) {
	mut cfg, no_matches := flag.to_struct[FetchConfig](normalize_args(args), skip: 0, style: .long) or {
		eprintln('参数错误: ${err}')
		exit(1)
	}

	mut query := ''
	for m in no_matches {
		if !m.starts_with('-') {
			query = m
			break
		}
	}
	if query.len == 0 {
		eprintln('错误: fetch 需要一个包名')
		eprintln('用法: zpkg fetch [-r|--recursive] <包名>')
		exit(1)
	}

	mode_label := if cfg.recursive { 'recursive' } else { 'single' }
	println('')
	println('========== fetch ${query} (mode: ${mode_label}) ==========')

	mut executed := 0
	mut skipped := 0
	mut unsupported := 0

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { skipped++; continue }

		if mgr.fetch_tpl.len == 0 {
			println('')
			println('---------- [${mgr.name}] 不支持 fetch，跳过 ----------')
			unsupported++
			continue
		}

		mut used_tpl := mgr.fetch_tpl
		mut note := ''
		if cfg.recursive {
			if mgr.fetch_recursive_tpl.len > 0 {
				used_tpl = mgr.fetch_recursive_tpl
			} else {
				note = '  (该包管理器不支持 --recursive，已降级为普通 fetch)'
			}
		}

		cmd_str := build_command(used_tpl, query)
		executed++

		println('')
		println('---------- [${mgr.name}] ----------')
		println('\$ ${cmd_str}${note}')
		println('---------------------------------------------')

		res := os.execute(cmd_str)
		if res.exit_code == 0 {
			out := res.output.trim_space()
			if out.len > 0 {
				println(out)
			}
			println('  ✅ 成功')
		} else {
			println('  ⚠️ exit code ${res.exit_code}')
			out := res.output.trim_space()
			if out.len > 0 {
				println(out)
			}
		}
	}

	println('')
	println('--- 汇总: 执行 ${executed} 个, 跳过 ${skipped} 个 (未安装), 不支持 ${unsupported} 个 ---')
}

// ==================== files 子命令 ====================

fn handle_files(args []string) {
	if args.len < 1 {
		eprintln('错误: files 需要一个包名')
		eprintln('用法: zpkg files <包名>')
		exit(1)
	}
	query := args[0]

	println('')
	println('========== files ${query} ==========')

	mut executed := 0
	mut skipped := 0
	mut unsupported := 0

	for mgr in get_ordered_managers() {
		if !command_exists(mgr.cmd) { skipped++; continue }

		if mgr.name == 'vcpkg' {
			println('')
			println('---------- [vcpkg] (遍历安装目录) ----------')
			vcpkg_files(query)
			executed++
			continue
		}

		if mgr.files_tpl.len == 0 {
			println('')
			println('---------- [${mgr.name}] 不支持 files，跳过 ----------')
			unsupported++
			continue
		}

		cmd_str := build_command(mgr.files_tpl, query)
		executed++

		println('')
		println('---------- [${mgr.name}] ----------')
		println('\$ ${cmd_str}')
		println('---------------------------------------------')

		res := os.execute(cmd_str)
		out := res.output.trim_space()
		if res.exit_code == 0 {
			if out.len > 0 {
				println(out)
			} else {
				println('  (无文件)')
			}
		} else {
			println('  ⚠️ exit code ${res.exit_code}')
			if out.len > 0 { println(out) }
		}
	}

	println('')
	println('--- 汇总: 执行 ${executed} 个, 跳过 ${skipped} 个 (未安装), 不支持 ${unsupported} 个 ---')
}

fn vcpkg_files(query string) {
	root := get_vcpkg_root()
	if root.len == 0 {
		println('  未检测到 vcpkg root，跳过')
		return
	}
	installed := '${root}/installed'
	if !os.exists(installed) {
		println('  installed 目录不存在')
		return
	}

	triplets := os.ls(installed) or { [] }
	mut found := false
	for triplet in triplets {
		if triplet == 'vcpkg' { continue }
		share_pkg := '${installed}/${triplet}/share/${query}'
		if !os.exists(share_pkg) { continue }
		println('  [${triplet}/share/${query}/]')
		find_cmd := 'find ${escape_shell(share_pkg)} -type f 2>/dev/null'
		res := os.execute(find_cmd)
		files := res.output.trim_space()
		if files.len > 0 {
			for f in files.split_into_lines() {
				rel := f.replace(share_pkg, '').trim_left('/')
				if rel.len > 0 { println('    ${rel}') }
			}
		}
		found = true
	}
	if !found {
		println('  (未在任何 triplet 的 share 目录中找到该包)')
	}
	println('  提示: vcpkg 产物合并于 lib/ bin/ 等公共目录，精确文件列表可结合 vcpkg owns <file> 反向查询')
}

// ==================== vcpkg JSON 解析（search/info 用） ====================

fn extract_json(text string) string {
	t := text.trim_space()
	for i, c in t {
		if c == `[` || c == `{` { return t[i..] }
	}
	return t
}

fn pretty_key(k string) string {
	known := {
		'name': 'Name', 'version': 'Version', 'port-version': 'Port Version',
		'description': 'Description', 'homepage': 'Homepage', 'license': 'License',
		'supports': 'Supports', 'dependencies': 'Dependencies',
		'default-features': 'Default Features', 'features': 'Features', 'type': 'Type'
	}
	if v := known[k] { return v }
	return k.replace('-', ' ')
}

fn format_value(v json2.Any) string {
	if v is string { return v }
	if v is []json2.Any {
		mut parts := []string{}
		for item in v {
			if item is string { parts << item }
			else {
				mp := item.as_map()
				if n := mp['name'] {
					mut s := n.str()
					if feats := mp['features'] {
						farr := feats.arr()
						if farr.len > 0 {
							mut fparts := []string{}
							for x in farr { fparts << x.str() }
							s += '[' + fparts.join(',') + ']'
						}
					}
					if h := mp['host'] { if h.bool() { s += ' ' + c_yellow('[host]') } }
					parts << s
				} else { parts << item.str() }
			}
		}
		return parts.join('  ')
	}
	if v is map[string]json2.Any {
		mp := v.clone()
		mut keys := []string{}
		for k, _ in mp { keys << k }
		keys.sort()
		return keys.join(', ')
	}
	return v.str()
}

fn format_field(key string, value json2.Any) string {
	val_str := format_value(value)
	if val_str.len == 0 { return '' }
	pretty := pretty_key(key)
	mut padded := pretty
	for padded.len < 16 { padded += ' ' }
	colored_key := c_cyan_bold(padded)
	colored_val := match key {
		'name', 'version' { c_bright_white_bold(val_str) }
		'dependencies' { c_green(val_str) }
		'features', 'default-features' { c_magenta(val_str) }
		'port-version' { if val_str == '0' { c_dim(val_str) } else { val_str } }
		else { val_str }
	}
	return '${colored_key}: ${colored_val}'
}

fn format_vcpkg_port(p map[string]json2.Any) string {
	priority := ['name', 'version', 'port-version', 'description', 'homepage',
		'license', 'supports', 'dependencies', 'default-features', 'features', 'type']
	mut lines := []string{}
	mut shown := map[string]bool{}
	for key in priority {
		if v := p[key] {
			line := format_field(key, v)
			if line.len > 0 { lines << line }
			shown[key] = true
		}
	}
	mut extras := []string{}
	for k, _ in p { if k !in shown { extras << k } }
	extras.sort()
	for k in extras {
		if v := p[k] {
			line := format_field(k, v)
			if line.len > 0 { lines << line }
		}
	}
	return if lines.len == 0 { '(无有效字段)' } else { lines.join('\n') }
}

fn parse_vcpkg_json(text string) string {
	t := extract_json(text)
	if t.len == 0 { return '(无数据)' }
	mut out := []string{}
	if t[0] == `[` {
		ports := json2.decode[[]map[string]json2.Any](t) or { return text }
		for i, p in ports {
			if i > 0 { out << '' }
			out << format_vcpkg_port(p)
		}
	} else if t[0] == `{` {
		top := json2.decode[map[string]json2.Any](t) or { return text }
		if results_any := top['results'] {
			results := results_any.as_map()
			mut names := []string{}
			for k, _ in results { names << k }
			names.sort()
			for i, name in names {
				if i > 0 { out << '' }
				out << format_vcpkg_port(results[name].as_map())
			}
		} else { out << format_vcpkg_port(top) }
	} else { return text }
	return out.join('\n')
}

fn handle_vcpkg_info(query string) string {
	safe := escape_shell(query)
	cmd := 'vcpkg x-package-info ${safe} --x-json'
	res := os.execute(cmd)
	mut out := []string{}
	out << '\$ ${cmd}'
	out << '---------------------------------------------'
	if res.output.trim_space().len == 0 { out << '(包信息无输出)' }
	else { out << parse_vcpkg_json(res.output) }
	return out.join('\n')
}

// ==================== 主逻辑 ====================

fn main() {
	if os.args.len < 2 {
		eprintln('用法: zpkg <search|info|list|upable|syncn|addn|deln|fetch|files> [参数]')
		eprintln('')
		eprintln('子命令:')
		eprintln('  search <关键词>          在所有包管理器中搜索包（已安装的会在行尾标记 [installed]）')
		eprintln('  info <包名>              查询包详细信息')
		eprintln('  list                     列出已安装的包')
		eprintln('  upable                   列出已安装的可更新包（默认显示 10 个）')
		eprintln('  syncn                    模拟同步软件仓库（只显示将要更新的内容，不实际修改系统）')
		eprintln('  addn <包名>              模拟安装包，预览影响而不实际执行')
		eprintln('  deln <包名>              模拟删除包，预览影响而不实际执行')
		eprintln('  fetch <包名>             下载包（不安装）')
		eprintln('  files <包名>             列出包安装的文件')
		eprintln('')
		eprintln('list 参数:')
		eprintln('  -s, --sort <mode>        排序方式（默认: natural）')
		eprintln('                           natural  按包名自然排序（package2 在 package10 前）')
		eprintln('                           time     按安装时间倒序（最新在前）')
		eprintln('                           size     按包大小倒序（最大在前）')
		eprintln('  -m, --max <N>            每个包管理器最多显示 N 个包（默认: 10，-1 表示不限制）')
		eprintln('')
		eprintln('upable 参数:')
		eprintln('  -m, --max <N>            每个包管理器最多显示 N 个可更新包（默认: 10，-1 表示不限制）')
		eprintln('')
		eprintln('deln 参数:')
		eprintln('  -r, --recursive          模拟递归删除（对 pacman/apt/apk 生效）')
		eprintln('')
		eprintln('fetch 参数:')
		eprintln('  -r, --recursive          同时下载依赖（默认关闭；部分包管理器不支持时会降级为普通 fetch）')
		eprintln('')
		eprintln('示例:')
		eprintln('  zpkg search curl')
		eprintln('  zpkg info curl')
		eprintln('  zpkg list --sort size --max 5')
		eprintln('  zpkg list -s size -m 5')
		eprintln('  zpkg upable')
		eprintln('  zpkg upable --max 5')
		eprintln('  zpkg upable --max=-1')
		eprintln('  zpkg upable -m 5')
		eprintln('  zpkg syncn')
		eprintln('  zpkg addn curl')
		eprintln('  zpkg deln curl')
		eprintln('  zpkg deln -r curl')
		eprintln('  zpkg fetch --recursive curl')
		eprintln('  zpkg fetch -r curl')
		eprintln('  zpkg files curl')
		exit(1)
	}

	subcmd := os.args[1]
	rest := os.args[2..]

	match subcmd {
		'list' { handle_list(rest) }
		'upable' { handle_upable(rest) }
		'syncn' { handle_syncn(rest) }
		'addn' { handle_addn(rest) }
		'deln' { handle_deln(rest) }
		'fetch' { handle_fetch(rest) }
		'files' { handle_files(rest) }
		'search', 'info' {
			if rest.len < 1 {
				eprintln('错误: ${subcmd} 需要一个包名或关键词')
				exit(1)
			}
			action := subcmd.to_lower()
			query := rest[0]

			mut executed := 0
			mut skipped := 0
			mut installed_total := 0
			mut skipped_names := []string{}

			for mgr in get_ordered_managers() {
				if !command_exists(mgr.cmd) {
					skipped++
					skipped_names << mgr.name
					continue
				}
				executed++

				if mgr.info_parser == 'vcpkg' && action == 'info' {
					println('')
					println('========== [${mgr.name}] ${action} ==========')
					println(handle_vcpkg_info(query))
					continue
				}

				tpl := if action == 'search' { mgr.search_tpl } else { mgr.info_tpl }
				cmd_str := build_command(tpl, query)
				println('')
				println('========== [${mgr.name}] ${action} ==========')
				println('\$ ${cmd_str}')
				println('---------------------------------------------')
				output := run_command(cmd_str)
				if output.len > 0 {
					if action == 'search' {
						ann := annotate_search_with_installed(output, mgr, query)
						println(ann.text)
						installed_total += ann.installed_count
					} else {
						println(colorize_output(output, action))
					}
				} else {
					println('  (无输出)')
				}
			}

			println('')
			mut summary := '--- 汇总: 执行 ${executed} 个包管理器'
			if action == 'search' {
				summary += '，搜索到已安装包 ${installed_total} 个'
			}
			summary += '，跳过 ${skipped} 个包管理器'
			if skipped_names.len > 0 {
				summary += '（${skipped_names.join(', ')} 命令不存在）'
			}
			summary += ' ---'
			println(summary)
		}
		else {
			eprintln('未知子命令: ${subcmd}，可用: search, info, list, upable, syncn, addn, deln, fetch, files')
			exit(1)
		}
	}
}
