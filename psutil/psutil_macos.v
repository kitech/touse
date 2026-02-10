module psutil

// Link required libraries for macOS
$if macos && tinyc {
} $else {
    #flag darwin -framework CoreFoundation
    #flag darwin -framework CoreServices
}
#flag @DIR/psutil_macos.o

// Use @[importc] to map C functions directly
@[importc: 'psutil_get_all_processes']
fn get_all_processes_raw(processes voidptr, count &int) int

@[importc: 'psutil_get_process_path']
fn get_process_path_raw(pid int, buffer &char, buffer_size usize) int

@[importc: 'psutil_get_process_name']
fn get_process_name_raw(pid int, buffer &char, buffer_size usize) int

@[importc: 'psutil_free_processes']
fn free_processes_raw(processes voidptr)

@[importc: 'psutil_get_current_pid']
fn get_current_pid_raw() int

@[importc: 'psutil_process_exists']
fn process_exists_raw(pid int) int

@[importc: 'psutil_get_process_arguments']
fn get_process_arguments_raw(pid int, args voidptr, arg_count &int) int

@[importc: 'psutil_free_arguments']
fn free_arguments_raw(args voidptr, count int)

// Define C structure to match exactly what C returns

struct CProcessInfo {
    pid  int
    name [256]char
    path [1024]char
    ppid int
    user [64]char
}

// V layer ProcessInfo
pub struct ProcessInfo {
pub:
    pid       int
    name      string
    path      string
    ppid      int
    user      string
    arguments []string
}

// Helper function to convert C char array to V string
fn char_array_to_str(arr &char, max_len int) string {
    mut result := ''
    unsafe {
        mut i := 0
        for i < max_len {
            if arr[i] == 0 {
                break
            }
            i++
        }
        if i > 0 {
            // Create a slice and convert to string
            mut bytes := []u8{len: i}
            for j in 0 .. i {
                bytes[j] = u8(arr[j])
            }
            result = bytes.bytestr()
        }
    }
    return result
}

// Helper function to convert C string to V string
fn cstr_to_vstr(cstr &char) string {
    if isnil(cstr) {
        return ''
    }
    
    mut len := 0
    for {
        unsafe {
            if cstr[len] == 0 {
                break
            }
        }
        len++
    }
    
    if len == 0 {
        return ''
    }
    
    // Create byte array and convert
    mut bytes := []u8{len: len}
    for i in 0 .. len {
        unsafe {
            bytes[i] = u8(cstr[i])
        }
    }
    
    return bytes.bytestr()
}

// Get list of all running processes
pub fn get_all_processes() ![]ProcessInfo {
    mut c_processes := &CProcessInfo(unsafe { nil })
    mut count := 0
    
    result := get_all_processes_raw(voidptr(&c_processes), &count)
    if result != 0 {
        return error('Failed to get process list')
    }
    
    mut v_processes := []ProcessInfo{cap: count}
    
    // Convert C array to V array
    for i in 0 .. count {
        unsafe {
            c_info := &c_processes[i]
            
            // Get arguments for each process
            mut args_array := []string{}
            if c_info.pid > 0 {
                args := get_process_arguments(c_info.pid) or { []string{} }
                args_array = args.clone()
            }
            
            // Convert C strings to V strings using helper function
            name_str := char_array_to_str(&char(c_info.name), 256)
            path_str := char_array_to_str(&char(c_info.path), 1024)
            user_str := char_array_to_str(&char(c_info.user), 64)
            
            v_processes << ProcessInfo{
                pid:       c_info.pid
                name:      name_str
                path:      path_str
                ppid:      c_info.ppid
                user:      user_str
                arguments: args_array
            }
        }
    }
    
    // Free C memory
    free_processes_raw(c_processes)
    
    return v_processes
}

// Get process executable path by PID
pub fn get_process_path(pid int) !string {
    if pid <= 0 {
        return error('Invalid PID')
    }
    
    mut buffer := [4096]u8{}
    
    result := get_process_path_raw(pid, &char(buffer), usize(buffer.len))
    if result != 0 {
        return error('Failed to get process path for PID ${pid}')
    }
    
    // Find null terminator and convert to string
    mut length := 0
    for i in 0 .. buffer.len {
        if buffer[i] == 0 {
            length = i
            break
        }
    }
    
    if length == 0 {
        return ''
    }
    
    return buffer[..length].bytestr()
}

// Get process name by PID
pub fn get_process_name(pid int) !string {
    if pid <= 0 {
        return error('Invalid PID')
    }
    
    mut buffer := [256]u8{}
    
    result := get_process_name_raw(pid, &char(buffer), usize(buffer.len))
    if result != 0 {
        return error('Failed to get process name for PID ${pid}')
    }
    
    // Find null terminator and convert to string
    mut length := 0
    for i in 0 .. buffer.len {
        if buffer[i] == 0 {
            length = i
            break
        }
    }
    
    if length == 0 {
        return ''
    }
    
    return buffer[..length].bytestr()
}

// Get process command line arguments by PID
pub fn get_process_arguments(pid int) ![]string {
    if pid <= 0 {
        return error('Invalid PID')
    }
    
    mut args_ptr := &&char(unsafe { nil })
    mut arg_count := 0
    
    result := get_process_arguments_raw(pid, voidptr(&args_ptr), &arg_count)
    if result != 0 {
        return error('Failed to get process arguments for PID ${pid}')
    }
    
    mut arguments := []string{cap: arg_count}
    
    // Convert C string array to V array
    for i in 0 .. arg_count {
        unsafe {
            arg_ptr := args_ptr[i]
            if !isnil(arg_ptr) {
                arguments << cstr_to_vstr(arg_ptr)
            }
        }
    }
    
    // Free C memory
    free_arguments_raw(args_ptr, arg_count)
    
    return arguments
}

// Get current process PID
pub fn get_current_pid() int {
    return get_current_pid_raw()
}

// Check if process exists
pub fn process_exists(pid int) bool {
    return process_exists_raw(pid) != 0
}

// Get full process information including arguments
pub fn get_full_process_info(pid int) !ProcessInfo {
    if pid <= 0 {
        return error('Invalid PID')
    }
    
    name := get_process_name(pid)!
    path := get_process_path(pid) or { '' }
    arguments := get_process_arguments(pid) or { []string{} }
    
    // For PPID and user, we need to get process list
    processes := get_all_processes() or { return error('Failed to get processes') }
    
    for process in processes {
        if process.pid == pid {
            return ProcessInfo{
                pid:       pid
                name:      name
                path:      path
                ppid:      process.ppid
                user:      process.user
                arguments: arguments.clone()
            }
        }
    }
    
    return error('Process not found')
}

// Find process by name
pub fn find_process_by_name(name string) ?ProcessInfo {
    processes := get_all_processes() or { return none }
    
    for process in processes {
        if process.name == name {
            return process
        }
    }
    
    return none
}

// Get process count
pub fn get_process_count() !int {
    processes := get_all_processes() or { return error('Failed to get processes') }
    return processes.len
}

// Get processes by user
pub fn get_processes_by_user(username string) ![]ProcessInfo {
    all_processes := get_all_processes() or { 
        return error('Failed to get processes')
    }
    
    mut user_processes := []ProcessInfo{}
    
    for process in all_processes {
        if process.user == username {
            user_processes << process
        }
    }
    
    return user_processes
}

// Get current process arguments
pub fn get_current_arguments() ![]string {
    return get_process_arguments(get_current_pid())
}
// Total lines: 225
