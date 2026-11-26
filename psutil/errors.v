module psutil

pub const err_no_such_process = 101
pub const err_access_denied = 102
pub const err_zombie_process = 103
pub const err_timeout_expired = 104
pub const err_unsupported = 105
pub const err_invalid_arg = 106

// ProcessError 对齐 pypi psutil 的异常族，用 code 区分类型。
pub struct ProcessError {
pub:
    code int
    pid  int
    text string
}

pub fn (e ProcessError) msg() string {
    return e.text
}

pub fn (e ProcessError) code() int {
    return e.code
}

pub fn (e ProcessError) str() string {
    return e.text
}

fn proc_err(pid int, code int, op string) ProcessError {
    return proc_err_text(pid, code, proc_err_default_text(pid, code, op))
}

fn proc_err_text(pid int, code int, text string) ProcessError {
    return ProcessError{
        code: code
        pid:  pid
        text: text
    }
}

fn proc_err_default_text(pid int, code int, op string) string {
    match code {
        err_no_such_process { return 'no such process (pid=${pid})' }
        err_access_denied { return 'access denied (pid=${pid})' }
        err_zombie_process { return 'zombie process (pid=${pid})' }
        err_timeout_expired { return 'timeout while waiting for pid=${pid}' }
        err_unsupported { return '${op} is not supported on this platform' }
        else { return '${op} failed (pid=${pid})' }
    }
}

// C shim 状态码 -> pypi 风格异常码。
fn map_proc_err(pid int, code int, op string) ProcessError {
    match code {
        -1 { return proc_err(pid, err_no_such_process, op) }
        -2 { return proc_err(pid, err_access_denied, op) }
        -3 { return proc_err(pid, err_unsupported, op) }
        -4 { return proc_err(pid, err_zombie_process, op) }
        else { return proc_err(pid, err_invalid_arg, op) }
    }
}
