import os
import readline
import vrtinfo
import time
import vcp
import vcp.json
import vcp.yco

// running/connected/reconnecting/done 跨 coro（可能落在不同 photon thread）读写，全部走 atomic
struct App {
mut:
	name         string
	timeout_ms   int
	cli          vrtinfo.Client // 只在 main_loop coro 内访问，不跨线程
	rl           readline.Readline
	ch           yco.Chan
	ackch        yco.Chan
	id           int
	running      bool
	connected    bool
	reconnecting bool
	was_open     bool // 只由 monitor_loop 读写
	done         int
}

struct Ev {
	kind int // 0=line 2=ack
	line string
}

const (
	ev_line = 0
	ev_ack  = 2
)

// send[voidptr] 的 Anyer 装箱在 coro 间传递会崩，直接走 yco.Chan 的底层 C API
fn C.crn_hchan_send(voidptr, voidptr) bool
fn C.crn_hchan_recv(voidptr, &voidptr) bool

// C 队列不被 GC 扫描，事件指针必须保活；各池由单一 coro 独占写入
const input_evs = []&Ev{}
const ack_ev = &Ev{kind: ev_ack, line: ''}

// 列表结果表格化：只处理列表类命令，别的结果保持原 JSON 输出
fn list_headers(key string) []string {
	return match key {
		'threads' { ['TID', 'NAME', 'STATE', 'IS_CURRENT', 'GOID', 'GC_REGISTERED', 'CPU_MS', 'STKSZ', 'USED_STKSZ', 'WCHAN', 'SYSCALL', 'FUNC'] }
		'fibers' { ['ID', 'MCID', 'STATE', 'PKREASON', 'STKSZ', 'USED_STKSZ'] }
		'cmds' { ['COMMAND'] }
		else { []string{} }
	}
}

fn json_cell(el &json.JSON, field string) string {
	if el.isObject() {
		n := el.key(field)
		if n == nil || n.isNull() {
			return '-'
		}
		if n.isString() {
			return n.tostr()
		}
		if n.isBool() {
			return if n.tobool() { 'true' } else { 'false' }
		}
		return n.json_str()
	}
	if el.isString() {
		return el.tostr()
	}
	return el.json_str()
}

// 纯 ASCII 表格：按列最大宽度左对齐，列间两个空格
fn table_text(headers []string, rows [][]string) string {
	mut widths := []int{len: headers.len}
	for i, h in headers {
		widths[i] = h.len
	}
	for row in rows {
		for i, cell in row {
			if i < widths.len && cell.len > widths[i] {
				widths[i] = cell.len
			}
		}
	}
	mut lines := []string{cap: rows.len + 1}
	mut head := []string{cap: headers.len}
	for i, h in headers {
		head << h + ' '.repeat(widths[i] - h.len)
	}
	lines << head.join('  ')
	for row in rows {
		mut line := []string{cap: headers.len}
		for i in 0 .. headers.len {
			cell := if i < row.len { row[i] } else { '' }
			line << cell + ' '.repeat(widths[i] - cell.len)
		}
		lines << line.join('  ')
	}
	return lines.join('\n')
}

fn format_lists(data string) string {
	jo := json.parse(data) or { return '' }
	defer { jo.freeit() }
	if !jo.isObject() {
		return ''
	}
	mut write_cmds := map[string]bool{}
	w := jo.key('write_cmds')
	if w != nil && w.isArray() {
		for i in 0 .. w.size() {
			write_cmds[w.index(i).tostr()] = true
		}
	}
	mut out := []string{}
	mut marked_help := false
	for key in ['threads', 'fibers', 'cmds'] {
		arr := jo.key(key)
		if arr == nil || !arr.isArray() || arr.size() == 0 {
			continue
		}
		headers := list_headers(key)
		if headers.len == 0 {
			continue
		}
		mut rows := [][]string{cap: arr.size()}
		for i in 0 .. arr.size() {
			el := arr.index(i)
			if el == nil {
				continue
			}
			mut row := []string{cap: headers.len}
			for h in headers {
				row << json_cell(el, h.to_lower())
			}
			rows << row
		}
		if headers.len == 1 {
			mut vals := []string{cap: rows.len}
			for row in rows {
				mut v := row[0]
				if key == 'cmds' && (v in write_cmds) {
					v += '*'
					marked_help = true
				}
				vals << v
			}
			out << '${key}: ' + vals.join(' ')
		} else {
			out << '${key}:'
			out << table_text(headers, rows)
		}
	}
	if marked_help {
		out << '(* = 会修改状态/触发动作)'
	}
	return out.join('\n')
}

fn usage() {
	eprintln('usage: vrtic -name <service> [-timeout <ms>]')
}

fn input_loop(p voidptr) voidptr {
	mut app := &App(p)
	yco.register_mycoro()
	defer { vcp.atomic_add(&app.done, 1) }
	for vcp.atomic_load(&app.running) {
		status := if vcp.atomic_load(&app.connected) { 'on' } else { 'off' }
		line := app.rl.read_line('${app.name}@${status}> ') or {
			ev := &Ev{kind: ev_line, line: 'quit'}
			input_evs << ev
			C.crn_hchan_send(app.ch, voidptr(ev))
			vcp.atomic_store(&app.running, false)
			break
		}
		ev := &Ev{kind: ev_line, line: line}
		input_evs << ev
		C.crn_hchan_send(app.ch, voidptr(ev))
		// 等主循环打印完响应再进入下一轮 read_line（prompt 在那时才输出）
		mut ack_raw := voidptr(0)
		C.crn_hchan_recv(app.ackch, &ack_raw)
	}
	return voidptr(0)
}

// 直接检测并打印断开提示，不往 chan 发 tick：退出时 tick 发送会踩到调度资源而 segfault
fn monitor_loop(p voidptr) voidptr {
	mut app := &App(p)
	yco.register_mycoro()
	defer { vcp.atomic_add(&app.done, 1) }
	app.was_open = true
	for vcp.atomic_load(&app.running) {
		time.sleep(200 * time.millisecond)
		// reconnect 期间 Client 正在被替换，跳过检查
		if vcp.atomic_load(&app.reconnecting) {
			continue
		}
		connected := vcp.atomic_load(&app.connected)
		if !connected {
			app.was_open = false
			continue
		}
		if !app.was_open {
			app.was_open = true
			continue
		}
		now_open := app.cli.is_open()
		if !now_open {
			println("[disconnected] server closed the connection; type 'reconnect' or 'quit'")
			vcp.atomic_store(&app.connected, false)
		}
		app.was_open = now_open
	}
	return voidptr(0)
}

// 返回 false 表示 quit；无论哪个分支退出都发 ack，驱动输入 coro 打印下一个 prompt
fn handle_line(app &App, line string) bool {
	defer { C.crn_hchan_send(app.ackch, voidptr(ack_ev)) }
	if line == '' {
		return true
	}
	if line == 'quit' || line == 'exit' {
		vcp.atomic_store(&app.running, false)
		return false
	}
	if line == 'reconnect' {
		vcp.atomic_store(&app.reconnecting, true)
		app.cli.close()
		app.cli = vrtinfo.connect(app.name, app.timeout_ms) or {
			vcp.atomic_store(&app.reconnecting, false)
			eprintln('reconnect failed: ' + err.msg())
			return true
		}
		vcp.atomic_store(&app.connected, true)
		vcp.atomic_store(&app.reconnecting, false)
		return true
	}
	cmd := line
	args := '{}'
	if sp := line.index(' ') {
		cmd = line[..sp]
		args = line[sp + 1..].trim_space()
		if !args.starts_with('{') || !args.ends_with('}') {
			eprintln('args must be a JSON object')
			return true
		}
	}
	// help 走服务端 caps，命令表只有一份
	if cmd == 'help' {
		cmd = 'caps'
	}
	if !vcp.atomic_load(&app.connected) {
		eprintln('server disconnected; type "reconnect" or "quit"')
		return true
	}
	app.id++
	reply := app.cli.request(app.id.str(), cmd, args) or {
		eprintln('request failed: ' + err.msg())
		return true
	}
	if reply.ok {
		tbl := format_lists(reply.data)
		if tbl != '' {
			println('[id=${reply.id}] ok')
			println(tbl)
		} else {
			println('[id=${reply.id}] ok ${reply.data}')
		}
	} else {
		println('[id=${reply.id}] err(${reply.err_code}) ${reply.err_msg}')
	}
	return true
}

fn main_loop(p voidptr) voidptr {
	mut app := &App(p)
	yco.register_mycoro()
	defer { vcp.atomic_add(&app.done, 1) }
	for vcp.atomic_load(&app.running) {
		mut raw := voidptr(0)
		C.crn_hchan_recv(app.ch, &raw)
		ev := &Ev(raw)
		if !handle_line(app, ev.line.trim_space()) {
			return voidptr(0)
		}
	}
	return voidptr(0)
}

mut name := ''
mut timeout_ms := 2000
mut i := 0
for i < os.args.len {
	a := os.args[i]
	if a == '-name' && i + 1 < os.args.len {
		name = os.args[i + 1]
		i += 2
		continue
	}
	if a == '-timeout' && i + 1 < os.args.len {
		timeout_ms = os.args[i + 1].int()
		i += 2
		continue
	}
	i++
}
if name == '' {
	usage()
	return
}

mut cli := vrtinfo.connect(name, timeout_ms) or {
	eprintln('connect failed: ' + err.msg())
	return
}
mut app := &App{
	name: name
	timeout_ms: timeout_ms
	cli: cli
	ch: yco.Chan.new(64)
	ackch: yco.Chan.new(8)
	id: 0
	running: true
	connected: true
	reconnecting: false
	was_open: true
	done: 0
}
defer { app.cli.close() }

yco.gofy(vcp.gcfix_uepause, nil)
yco.gofy(input_loop, voidptr(app))
yco.gofy(monitor_loop, voidptr(app))
yco.gofy(main_loop, voidptr(app))

// 等三个 coro 全部收尾再退出，避免 coro 仍在运行时进程销毁调度资源
for vcp.atomic_load(&app.done) < 3 {
	time.sleep(500 * time.millisecond)
}
