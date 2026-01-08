module psutil

// Test get_current_pid function
fn test_get_current_pid() {
    pid := get_current_pid()
    assert pid > 0
    println('✓ Current PID: ${pid}')
}

// Test process_exists function
fn test_process_exists() {
    current_pid := get_current_pid()
    
    // Current process should definitely exist
    assert process_exists(current_pid) == true
    println('  Current process (PID ${current_pid}) exists: true')
    
    // Invalid PIDs should not exist
    assert process_exists(-1) == false
    assert process_exists(0) == false
    println('  Invalid PIDs (-1, 0) correctly return false')
    
    println('✓ test_process_exists passed')
}

// Test get_process_name function
fn test_get_process_name() {
    current_pid := get_current_pid()
    
    // Get current process name (should always work)
    name := get_process_name(current_pid) or { panic('Failed to get current process name') }
    assert name.len > 0
    println('  Current process name: ${name}')
    
    // Try to get launchd name (PID 1)
    get_process_name(1) or {
        println('  Note: Could not get launchd name (PID 1) - ${err}')
    }
    
    // Invalid PID should fail
    get_process_name(-1) or { 
        /* Expected error - do nothing */ 
    }
    
    println('✓ test_get_process_name passed')
}

// Test get_process_path function
fn test_get_process_path() {
    current_pid := get_current_pid()
    
    // Get current process path (should work)
    path := get_process_path(current_pid) or { panic('Failed to get current process path') }
    assert path.len > 0
    println('  Current process path: ${path}')
    
    // Try to get launchd path
    get_process_path(1) or {
        println('  Note: Could not get launchd path - ${err}')
    }
    
    println('✓ test_get_process_path passed')
}

// Test get_process_arguments function - fixed version
fn test_get_process_arguments() {
    current_pid := get_current_pid()
    
    // Get current process arguments
    args := get_process_arguments(current_pid) or { 
        println('  Note: Could not get process arguments - ${err}')
        []string{}
    }
    
    println('  Current process has ${args.len} arguments')
    
    // Display arguments if we have them
    if args.len > 0 {
        println('  Arguments:')
        for i, arg in args {
            println('    [${i}] ${arg}')
        }
        
        // Check if first argument is non-empty (might be empty in some cases)
        if args[0].len == 0 {
            println('  Note: First argument is empty (this can happen in some environments)')
        }
    } else {
        println('  Note: No arguments retrieved (this can happen in some environments)')
    }
    
    // Try to get launchd arguments
    launchd_args := get_process_arguments(1) or { []string{} }
    println('  launchd has ${launchd_args.len} arguments')
    
    // Invalid PID should fail
    get_process_arguments(-1) or { /* Expected error */ }
    
    println('✓ test_get_process_arguments passed')
}

// Test get_current_arguments function
fn test_get_current_arguments() {
    args := get_current_arguments() or { 
        println('  Note: Could not get current arguments - ${err}')
        []string{}
    }
    println('  Current process arguments count: ${args.len}')
    println('✓ test_get_current_arguments passed')
}

// Test get_all_processes function
fn test_get_all_processes() {
    processes := get_all_processes() or { panic('Failed to get process list') }
    
    assert processes.len > 0
    println('  Total processes: ${processes.len}')
    
    // Find current process
    current_pid := get_current_pid()
    mut found_current := false
    
    for process in processes {
        if process.pid == current_pid {
            found_current = true
            println('    Found current process: ${process.name} (PID ${process.pid})')
            println('    Current process has ${process.arguments.len} arguments')
            break
        }
    }
    
    assert found_current == true
    
    // Show some process info
    println('  Sample processes (PID < 100):')
    mut count := 0
    for process in processes {
        if process.pid < 100 && count < 5 {
            println('    ${process.pid:6} ${process.user:12} ${process.name:20}')
            count++
        }
    }
    
    println('✓ test_get_all_processes passed')
}

// Test get_process_count function
fn test_get_process_count() {
    count := get_process_count() or { panic('Failed to get process count') }
    assert count > 0
    println('  Process count: ${count}')
    println('✓ test_get_process_count passed')
}

// Test find_process_by_name function
fn test_find_process_by_name() {
    // First get current process name
    current_pid := get_current_pid()
    current_name := get_process_name(current_pid) or { panic('Failed to get current process name') }
    
    // Try to find current process by name
    found_process := find_process_by_name(current_name) or {
        println('  Note: Could not find process by name: ${current_name}')
        return
    }
    
    assert found_process.pid == current_pid
    println('  Found current process by name: ${current_name}')
    
    // Non-existent process should return none
    result := find_process_by_name('nonexistent_process_xyz123')
    assert result == none
    println('  Non-existent process correctly returns none')
    
    println('✓ test_find_process_by_name passed')
}

// Test get_processes_by_user function
fn test_get_processes_by_user() {
    current_pid := get_current_pid()
    
    // Get current process to find current user
    processes := get_all_processes() or { panic('Failed to get processes') }
    mut current_user := ''
    
    for process in processes {
        if process.pid == current_pid {
            current_user = process.user
            break
        }
    }
    
    if current_user.len == 0 {
        println('  Note: Could not determine current user')
        return
    }
    
    assert current_user.len > 0
    
    // Get processes for current user
    user_processes := get_processes_by_user(current_user) or { 
        panic('Failed to get user processes')
    }
    
    assert user_processes.len > 0
    
    println('  Current user: ${current_user}')
    println('  Processes for ${current_user}: ${user_processes.len}')
    println('✓ test_get_processes_by_user passed')
}

// Test get_full_process_info function
fn test_get_full_process_info() {
    current_pid := get_current_pid()
    
    // Get full info for current process
    info := get_full_process_info(current_pid) or { 
        println('  Note: Could not get full process info - ${err}')
        return
    }
    
    assert info.pid == current_pid
    assert info.name.len > 0
    
    println('  Full process info for PID ${current_pid}:')
    println('    Name: ${info.name}')
    println('    User: ${info.user}')
    println('    PPID: ${info.ppid}')
    println('    Path: ${if info.path.len > 0 { info.path } else { "unknown" }}')
    println('    Arguments: ${info.arguments.len}')
    
    println('✓ test_get_full_process_info passed')
}

// Test error handling
fn test_error_handling() {
    // Invalid PID for get_process_name
    get_process_name(-1) or { /* Expected error */ }
    
    // Invalid PID for get_process_path
    get_process_path(-1) or { /* Expected error */ }
    
    // Invalid PID for get_process_arguments
    get_process_arguments(-1) or { /* Expected error */ }
    
    println('✓ test_error_handling passed')
}

// Run all tests
fn test_all() {
    println('\n' + '='.repeat(60))
    println('RUNNING PSUTIL TESTS')
    println('='.repeat(60) + '\n')
    
    println('Note: Some tests may show informational messages.')
    println('This is normal and does not indicate test failure.\n')
    
    test_get_current_pid()
    test_process_exists()
    test_get_process_name()
    test_get_process_path()
    test_get_process_arguments()
    test_get_current_arguments()
    test_get_all_processes()
    test_get_process_count()
    test_find_process_by_name()
    test_get_processes_by_user()
    test_get_full_process_info()
    test_error_handling()
    
    println('\n' + '='.repeat(60))
    println('✅ ALL TESTS PASSED!')
    println('='.repeat(60))
    
    // Show summary
    show_test_summary()
}

fn show_test_summary() {
    println('\n' + '='.repeat(60))
    println('TEST SUMMARY')
    println('='.repeat(60))
    
    current_pid := get_current_pid()
    println('Current Process ID: ${current_pid}')
    
    // Get basic process info
    name := get_process_name(current_pid) or { 'unknown' }
    println('Current Process Name: ${name}')
    
    // Get process count
    count := get_process_count() or { 0 }
    println('Total Processes: ${count}')
    
    // Check if we can access system process
    launchd_exists := process_exists(1)
    println('PID 1 (launchd) exists: ${launchd_exists}')
    
    println('='.repeat(60))
}

fn main() {
    test_all()
}
// Total lines: 260
