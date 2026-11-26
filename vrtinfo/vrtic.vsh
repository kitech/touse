import os
import readline
import vrtinfo

fn usage() {
	eprintln('usage: vrtic -name <service> [-timeout <ms>]')
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
defer { cli.close() }

mut rl := readline.Readline{}
mut id := 0
for {
	status := if cli.is_open() { 'on' } else { 'off' }
	line := rl.read_line('${name}@${status}> ') or { break }
	line = line.trim_space()
	if line == '' {
		continue
	}
	if line == 'quit' || line == 'exit' {
		break
	}
	if line == 'reconnect' {
		cli.close()
		cli = vrtinfo.connect(name, timeout_ms) or {
			eprintln('reconnect failed: ' + err.msg())
			continue
		}
		continue
	}
	cmd := line
	args := '{}'
	if sp := line.index(' ') {
		cmd = line[..sp]
		args = line[sp + 1..].trim_space()
		if !args.starts_with('{') || !args.ends_with('}') {
			eprintln('args must be a JSON object')
			continue
		}
	}
	// help 走服务端 caps，命令表只有一份
	if cmd == 'help' {
		cmd = 'caps'
	}
	id++
	reply := cli.request(id.str(), cmd, args) or {
		eprintln('request failed: ' + err.msg())
		continue
	}
	if reply.ok {
		println('[id=${reply.id}] ok ${reply.data}')
	} else {
		println('[id=${reply.id}] err(${reply.err_code}) ${reply.err_msg}')
	}
}
