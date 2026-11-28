// vrtinfo 应用层协议 v1：一帧 = 一个 UTF-8 JSON 对象
module vrtinfo

import vcp.json

pub const (
	version        = 1
	service_prefix = 'vrtinfo'
	max_request    = 64 * 1024
	max_response   = 1024 * 1024
)

pub const (
	err_bad_request = 1001
	err_unknown_cmd = 1002
	err_bad_args    = 1003
	err_internal    = 1004
	err_too_large   = 1005
	err_unsupported = 1006
)

pub const command_names = [
	'ping', 'caps', 'info', 'gc.stats', 'gc.collect', 'gc.dump',
	'gc.set_free_space_divisor',
	'gc.set_full_freq', 'gc.set_is_disabled', 'gc.set_non_gc_bytes',
	'coro.stats', 'coro.list', 'threads', 'mem', 'fibers',
]

// 会修改进程状态/触发动作的命令；vrtic 的 help/caps 显示时用 * 标记。
pub const write_commands = [
	'gc.collect',
	'gc.set_free_space_divisor',
	'gc.set_full_freq',
	'gc.set_is_disabled',
	'gc.set_non_gc_bytes',
]

// 调用方注册的命令处理函数：args 为请求里的 JSON 对象字符串，返回响应 data 的 JSON 字符串
pub type CommandHandler = fn (args string) !string

pub struct Request {
pub:
	id   string
	cmd  string
	args string
}

pub struct Reply {
pub:
	id       string
	ok       bool
	data     string
	err_code int
	err_msg  string
}

// 实例名：vrtinfo-<pid>[-<tag>]
pub fn service_name(pid int, tag string) string {
	if tag == '' {
		return '${service_prefix}-${pid}'
	}
	return '${service_prefix}-${pid}-${tag}'
}

fn jesc(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')
}

pub fn jstr(s string) string {
	return '"${jesc(s)}"'
}

pub fn jobj(fields ...string) string {
	return '{${fields.join(',')}}'
}

// 用原始 JSON 节点解析，避免 cJSON 数字 double 对 id 的精度丢失
pub fn parse_request(raw string) !Request {
	jo := json.parse(raw)!
	defer { jo.freeit() }
	if !jo.isObject() {
		return error('request must be a JSON object')
	}
	v := jo.key('v')
	if v == nil || !v.isNumber() || int(v.tonum()) != version {
		return error('unsupported protocol version')
	}
	idn := jo.key('id')
	if idn == nil || !idn.isString() {
		return error('id must be a string')
	}
	id := idn.tostr()
	if id.len == 0 || id.len > 64 {
		return error('id length out of range')
	}
	cmdn := jo.key('cmd')
	if cmdn == nil || !cmdn.isString() {
		return error('cmd must be a string')
	}
	cmd := cmdn.tostr()
	if cmd.len == 0 || cmd.len > 64 {
		return error('cmd length out of range')
	}
	mut args := '{}'
	argn := jo.key('args')
	if argn != nil {
		if !argn.isObject() {
			return error('args must be an object')
		}
		args = argn.json_str()
	}
	return Request{ id: id, cmd: cmd, args: args }
}

pub fn parse_reply(raw string) !Reply {
	jo := json.parse(raw)!
	defer { jo.freeit() }
	if !jo.isObject() {
		return error('response must be a JSON object')
	}
	v := jo.key('v')
	if v == nil || !v.isNumber() || int(v.tonum()) != version {
		return error('unsupported protocol version')
	}
	idn := jo.key('id')
	if idn == nil || !idn.isString() {
		return error('id must be a string')
	}
	okn := jo.key('ok')
	if okn == nil || !okn.isBool() {
		return error('ok must be a bool')
	}
	mut data := '{}'
	mut code := 0
	mut msg := ''
	dn := jo.key('data')
	if dn != nil {
		data = dn.json_str()
	}
	en := jo.key('err')
	if en != nil && en.isObject() {
		cn := en.key('code')
		mn := en.key('msg')
		if cn != nil && cn.isNumber() {
			code = int(cn.tonum())
		}
		if mn != nil && mn.isString() {
			msg = mn.tostr()
		}
	}
	return Reply{ id: idn.tostr(), ok: okn.tobool(), data: data, err_code: code, err_msg: msg }
}

pub fn ok_response(id string, data string) string {
	return '{"v":${version},"id":${jstr(id)},"ok":true,"data":${data}}'
}

pub fn err_response(id string, code int, msg string) string {
	return '{"v":${version},"id":${jstr(id)},"ok":false,"err":{"code":${code},"msg":${jstr(msg)}}}'
}
