module psutil

// P3 查询走相邻的 extra.c。-3 表示平台不支持，避免伪造数值。
#flag -I @DIR/
#flag @DIR/extra.o
#include "@DIR/extra.h"

const max_env_vars = 1024
const max_shwtemp = 512
const max_sfan = 512
const max_battery = 1
const max_winsvc = 1024

@[typedef]
pub struct C.psutil_OneShot {
    name            [256]char
    ppid            int
    uids            [3]u64
    gids            [3]u64
    status          [64]char
    create_time     f64
    user            f64
    system          f64
    children_user   f64
    children_system f64
    iowait          f64
    terminal        [512]char
    num_threads     int
    vms             u64
    rss             u64
    shared          u64
    text            u64
    lib             u64
    data            u64
    dirty           u64
}

@[typedef]
pub struct C.psutil_Rlimit {
    soft i64
    hard i64
}

@[typedef]
pub struct C.psutil_EnvVar {
    key   [512]char
    value [4096]char
}

@[typedef]
pub struct C.psutil_Shwtemp {
    chip     [128]char
    name     [128]char
    label    [128]char
    current  f64
    high     f64
    critical f64
}

@[typedef]
pub struct C.psutil_Fan {
    chip  [128]char
    name  [128]char
    speed int
}

@[typedef]
pub struct C.psutil_Battery {
    percent       f64
    secsleft      int
    power_plugged int
}

@[typedef]
pub struct C.psutil_WindowsService {
    service_name [256]char
    display_name [512]char
    binary_path  [4096]char
    user_name    [512]char
    start_type   int
    service_pid  int
    status       int
    description  [4096]char
}

@[typedef]
pub struct C.psutil_HeapInfo {
    heap_used  u64
    mmap_used  u64
    heap_count int
}

fn C.psutil_extra_oneshot(int, &C.psutil_OneShot) int
fn C.psutil_extra_rlimit(int, int, &C.psutil_Rlimit) int
fn C.psutil_extra_set_rlimit(int, int, i64, i64) int
fn C.psutil_extra_environ(int, &C.psutil_EnvVar, int) int
fn C.psutil_extra_sensors_temperatures(int, &C.psutil_Shwtemp, int) int
fn C.psutil_extra_sensors_fans(&C.psutil_Fan, int) int
fn C.psutil_extra_sensors_battery(&C.psutil_Battery, int) int
fn C.psutil_extra_win_service_iter(&C.psutil_WindowsService, int) int
fn C.psutil_extra_win_service_get(&char, &C.psutil_WindowsService) int
fn C.psutil_extra_heap_info(&C.psutil_HeapInfo) int
fn C.psutil_extra_heap_trim() int
