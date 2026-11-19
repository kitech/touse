module rclone

import vcp.json

// ============ 内部基础设施（不对外） ============

struct Params {
mut:
	parts []string
}
fn pnew() Params { return Params{} }
fn (mut p Params) raw(k string, v string)        { p.parts << '"${k}":${v}' }
fn (mut p Params) put_str(k string, v string)    { p.raw(k, json.encode(v)) }
fn (mut p Params) integer(k string, v int)       { p.raw(k, '${v}') }
fn (mut p Params) integer64(k string, v i64)     { p.raw(k, '${v}') }
fn (mut p Params) float(k string, v f64)         { p.raw(k, '${v}') }
fn (mut p Params) boolean(k string, v bool)      { p.raw(k, if v { 'true' } else { 'false' }) }
fn (mut p Params) strings(k string, v []string)  { p.raw(k, json.encode(v)) }
fn (mut p Params) obj(k string, s string)        { p.raw(k, s) }
fn (p Params) build() string                     { return '{${p.parts.join(',')}}' }

// 内部中转：非 200 抛错；成功只返回原始节点，由各方法自行 decode。
fn call(method string, input string) !&json.JSON {
	r := rpc(method, input)
	if r.status != 200 {
		return error('rclone rpc ${method}: status ${r.status}: ${r.output}')
	}
	return json.decode_raw(r.output)
}

// ============ 类 Backend (1) ============

pub struct Backend {}

pub struct BackendCommandResult {
pub:
	arg []string          @[json: 'arg']
	name string           @[json: 'name']
	opt map[string]string @[json: 'opt']
}

pub fn (b Backend) command(command string, fs string, arg []string, opt map[string]string) !BackendCommandResult {
	mut p := pnew()
	p.put_str('command', command); p.put_str('fs', fs); p.strings('arg', arg); p.raw('opt', json.encode(opt))
	jo := call('backend/command', p.build()) or { return err }
	return jo.key('result').as[BackendCommandResult]()
}

// ============ 类 Cache (3) ============

pub struct Cache {}

pub fn (c Cache) expire(remote string, with_data ?bool) !(string, string) {
	mut p := pnew(); p.put_str('remote', remote)
	if v := with_data { p.boolean('withData', v) }
	jo := call('cache/expire', p.build()) or { return err }
	status := jo.key('status').as[string]() or { return err }
	message := jo.key('message').as[string]() or { return err }
	return status, message
}
pub fn (c Cache) fetch(chunks string, files []string) ! {
	mut p := pnew(); p.put_str('chunks', chunks)
	for i, f in files { p.put_str(if i == 0 { 'file' } else { 'file${i+1}' }, f) }
	_ := call('cache/fetch', p.build()) or { return err }
}
pub fn (c Cache) stats(stats ?string) !(string, map[string]i64) {
	mut p := pnew()
	if v := stats { p.put_str('stats', v) }
	jo := call('cache/stats', p.build()) or { return err }
	status := jo.key('status').as[string]() or { return err }
	m := jo.key('stats').as[map[string]i64]() or { return err }
	return status, m
}

// ============ 类 Config (14) ============

pub struct Config {}

pub struct ConfigPathsResult {
pub:
	config string @[json: 'config']
	cache  string @[json: 'cache']
	temp   string @[json: 'temp']
}
pub struct ConfigProvider {
pub:
	name string @[json: 'Name']
	help string @[json: 'Help']
}

pub fn (c Config) create(name string, parameters map[string]string, type_name string, opt ?map[string]string, obscure ?bool, no_obscure ?bool, no_output ?bool, non_interactive ?bool, continue_flag ?bool, all ?bool, state ?string, result ?string) !map[string]string {
	mut p := pnew(); p.put_str('name', name); p.raw('parameters', json.encode(parameters)); p.put_str('type', type_name)
	if v := opt { p.raw('opt', json.encode(v)) }
	if v := obscure { p.boolean('obscure', v) }
	if v := no_obscure { p.boolean('noObscure', v) }
	if v := no_output { p.boolean('noOutput', v) }
	if v := non_interactive { p.boolean('nonInteractive', v) }
	if v := continue_flag { p.boolean('continue', v) }
	if v := all { p.boolean('all', v) }
	if v := state { p.put_str('state', v) }
	if v := result { p.put_str('result', v) }
	jo := call('config/create', p.build()) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (c Config) delete(name string) ! {
	mut p := pnew(); p.put_str('name', name)
	_ := call('config/delete', p.build()) or { return err }
}
pub fn (c Config) dump() !map[string]map[string]string {
	jo := call('config/dump', '{}') or { return err }
	submap := jo.decode[map[string]&json.JSON]() or { return err }
	mut res := map[string]map[string]string{}
	for k, subjo in submap {
		res[k] = subjo.as[map[string]string]() or { return err }
	}
	return res
}
pub fn (c Config) get(name string) !map[string]string {
	mut p := pnew(); p.put_str('name', name)
	jo := call('config/get', p.build()) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (c Config) listremotes() ![]string {
	jo := call('config/listremotes', '{}') or { return err }
	return jo.key('remotes').as[[]string]()
}
pub fn (c Config) oauthstatus() !(string, string) {
	jo := call('config/oauthstatus', '{}') or { return err }
	status := jo.key('status').as[string]() or { return err }
	auth_url := jo.key('authUrl').as[string]() or { return '', '' }
	return status, auth_url
}
pub fn (c Config) oauthstop() ! { _ := call('config/oauthstop', '{}') or { return err } }
pub fn (c Config) password(name string, parameters map[string]string, opt ?map[string]string) !map[string]string {
	mut p := pnew(); p.put_str('name', name); p.raw('parameters', json.encode(parameters))
	if v := opt { p.raw('opt', json.encode(v)) }
	jo := call('config/password', p.build()) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (c Config) paths() !ConfigPathsResult {
	jo := call('config/paths', '{}') or { return err }
	return jo.decode[ConfigPathsResult]()
}
pub fn (c Config) providers() ![]ConfigProvider {
	jo := call('config/providers', '{}') or { return err }
	return jo.key('providers').as[[]ConfigProvider]()
}
pub fn (c Config) setpath(path string) ! {
	mut p := pnew(); p.put_str('path', path)
	_ := call('config/setpath', p.build()) or { return err }
}
pub fn (c Config) unlock(config_password string) ! {
	mut p := pnew(); p.put_str('configPassword', config_password)
	_ := call('config/unlock', p.build()) or { return err }
}
pub fn (c Config) unset(name string, keys []string) ![]string {
	mut p := pnew(); p.put_str('name', name); p.strings('keys', keys)
	jo := call('config/unset', p.build()) or { return err }
	return jo.key('removed').as[[]string]()
}
pub fn (c Config) update(name string, parameters map[string]string, opt ?map[string]string, obscure ?bool, no_obscure ?bool, no_output ?bool, non_interactive ?bool, continue_flag ?bool, all ?bool, state ?string, result ?string) !map[string]string {
	mut p := pnew(); p.put_str('name', name); p.raw('parameters', json.encode(parameters))
	if v := opt { p.raw('opt', json.encode(v)) }
	if v := obscure { p.boolean('obscure', v) }
	if v := no_obscure { p.boolean('noObscure', v) }
	if v := no_output { p.boolean('noOutput', v) }
	if v := non_interactive { p.boolean('nonInteractive', v) }
	if v := continue_flag { p.boolean('continue', v) }
	if v := all { p.boolean('all', v) }
	if v := state { p.put_str('state', v) }
	if v := result { p.put_str('result', v) }
	jo := call('config/update', p.build()) or { return err }
	return jo.decode[map[string]string]()
}

// ============ 类 Core (15) ============

pub struct Core {}

pub struct DuInfo {
pub:
	available i64 @[json: 'Available']
	free      i64 @[json: 'Free']
	total     i64 @[json: 'Total']
}
pub struct CoreBwlimitResult {
pub:
	bytes_per_second    i64    @[json: 'bytesPerSecond']
	bytes_per_second_tx i64    @[json: 'bytesPerSecondTx']
	bytes_per_second_rx i64    @[json: 'bytesPerSecondRx']
	rate                string @[json: 'rate']
}
pub struct CoreCommandResult {
pub:
	err         bool   @[json: 'error']
	result      string @[json: 'result']
	return_type string @[json: 'returnType']
}
pub struct MemStatsResult {
pub:
	alloc u64 @[json: 'Alloc']
	total_alloc u64 @[json: 'TotalAlloc']
	sys u64 @[json: 'Sys']
	mallocs u64 @[json: 'Mallocs']
	frees u64 @[json: 'Frees']
	heap_alloc u64 @[json: 'HeapAlloc']
	heap_sys u64 @[json: 'HeapSys']
	heap_idle u64 @[json: 'HeapIdle']
	heap_inuse u64 @[json: 'HeapInuse']
	heap_released u64 @[json: 'HeapReleased']
	heap_objects u64 @[json: 'HeapObjects']
	stack_inuse u64 @[json: 'StackInuse']
	stack_sys u64 @[json: 'StackSys']
}
pub struct TransferringItem {
pub:
	bytes i64 @[json: 'bytes']
	eta f64 @[json: 'eta']
	name string @[json: 'name']
	percentage f64 @[json: 'percentage']
	speed f64 @[json: 'speed']
	speed_avg f64 @[json: 'speedAvg']
	size i64 @[json: 'size']
}
pub struct CoreStatsResult {
pub:
	bytes i64 @[json: 'bytes']
	checks i64 @[json: 'checks']
	deleted_dirs i64 @[json: 'deletedDirs']
	deletes i64 @[json: 'deletes']
	elapsed_time f64 @[json: 'elapsedTime']
	errors i64 @[json: 'errors']
	eta f64 @[json: 'eta']
	fatal_error bool @[json: 'fatalError']
	last_error string @[json: 'lastError']
	renames i64 @[json: 'renames']
	listed i64 @[json: 'listed']
	retry_error bool @[json: 'retryError']
	server_side_copies i64 @[json: 'serverSideCopies']
	server_side_copy_bytes i64 @[json: 'serverSideCopyBytes']
	server_side_moves i64 @[json: 'serverSideMoves']
	server_side_move_bytes i64 @[json: 'serverSideMoveBytes']
	speed f64 @[json: 'speed']
	total_bytes i64 @[json: 'totalBytes']
	total_checks i64 @[json: 'totalChecks']
	total_transfers i64 @[json: 'totalTransfers']
	transfer_time f64 @[json: 'transferTime']
	transfers i64 @[json: 'transfers']
	updated_dirs i64 @[json: 'updatedDirs']
	transferring []TransferringItem @[json: 'transferring']
	checking []string @[json: 'checking']
}
pub struct CompletedTransfer {
pub:
	name string @[json: 'name']
	size i64 @[json: 'size']
	bytes i64 @[json: 'bytes']
	checked bool @[json: 'checked']
	what string @[json: 'what']
	timestamp i64 @[json: 'timestamp']
	err string @[json: 'error']
	jobid i64 @[json: 'jobid']
}
pub struct CoreVersionResult {
pub:
	version string @[json: 'version']
	decomposed []int @[json: 'decomposed']
	is_git bool @[json: 'isGit']
	is_beta bool @[json: 'isBeta']
	os string @[json: 'os']
	os_version string @[json: 'osVersion']
	os_kernel string @[json: 'osKernel']
	os_arch string @[json: 'osArch']
	arch string @[json: 'arch']
	go_version string @[json: 'goVersion']
	linking string @[json: 'linking']
	go_tags string @[json: 'goTags']
}

pub fn (c Core) bwlimit(rate ?string) !CoreBwlimitResult {
	mut p := pnew(); if v := rate { p.put_str('rate', v) }
	jo := call('core/bwlimit', p.build()) or { return err }
	return jo.decode[CoreBwlimitResult]()
}
pub fn (c Core) command(command string, arg []string, opt map[string]string, return_type ?string) !CoreCommandResult {
	mut p := pnew(); p.put_str('command', command); p.strings('arg', arg); p.raw('opt', json.encode(opt))
	if v := return_type { p.put_str('returnType', v) }
	jo := call('core/command', p.build()) or { return err }
	return jo.decode[CoreCommandResult]()
}
pub fn (c Core) disks() ![]string {
	jo := call('core/disks', '{}') or { return err }
	return jo.key('disks').as[[]string]()
}
pub fn (c Core) du(dir ?string) !(string, DuInfo) {
	mut p := pnew(); if v := dir { p.put_str('dir', v) }
	jo := call('core/du', p.build()) or { return err }
	d := jo.key('dir').as[string]() or { return err }
	info := jo.key('info').as[DuInfo]() or { return err }
	return d, info
}
pub fn (c Core) gc() ! { _ := call('core/gc', '{}') or { return err } }
pub fn (c Core) group_list() ![]string {
	jo := call('core/group-list', '{}') or { return err }
	return jo.key('groups').as[[]string]()
}
pub fn (c Core) memstats() !MemStatsResult {
	jo := call('core/memstats', '{}') or { return err }
	return jo.decode[MemStatsResult]()
}
pub fn (c Core) obscure(clear string) !string {
	mut p := pnew(); p.put_str('clear', clear)
	jo := call('core/obscure', p.build()) or { return err }
	return jo.key('obscured').as[string]()
}
pub fn (c Core) pid() !int {
	jo := call('core/pid', '{}') or { return err }
	return jo.key('pid').as[int]()
}
pub fn (c Core) quit(exit_code ?int) ! {
	mut p := pnew(); if v := exit_code { p.integer('exitCode', v) }
	_ := call('core/quit', p.build()) or { return err }
}
pub fn (c Core) stats(group ?string, short ?bool) !CoreStatsResult {
	mut p := pnew()
	if v := group { p.put_str('group', v) }
	if v := short { p.boolean('short', v) }
	jo := call('core/stats', p.build()) or { return err }
	return jo.decode[CoreStatsResult]()
}
pub fn (c Core) stats_delete(group string) ! {
	mut p := pnew(); p.put_str('group', group)
	_ := call('core/stats-delete', p.build()) or { return err }
}
pub fn (c Core) stats_reset(group ?string) ! {
	mut p := pnew(); if v := group { p.put_str('group', v) }
	_ := call('core/stats-reset', p.build()) or { return err }
}
pub fn (c Core) transferred(group ?string) ![]CompletedTransfer {
	mut p := pnew(); if v := group { p.put_str('group', v) }
	jo := call('core/transferred', p.build()) or { return err }
	return jo.key('transferred').as[[]CompletedTransfer]()
}
pub fn (c Core) version() !CoreVersionResult {
	jo := call('core/version', '{}') or { return err }
	return jo.decode[CoreVersionResult]()
}

// ============ 类 Debug (4) ============

pub struct Debug {}

pub fn (d Debug) set_block_profile_rate(rate int) ! {
	mut p := pnew(); p.integer('rate', rate)
	_ := call('debug/set-block-profile-rate', p.build()) or { return err }
}
pub fn (d Debug) set_gc_percent(gc_percent int) !int {
	mut p := pnew(); p.integer('gc-percent', gc_percent)
	jo := call('debug/set-gc-percent', p.build()) or { return err }
	return jo.key('existing-gc-percent').as[int]()
}
pub fn (d Debug) set_mutex_profile_fraction(rate int) !int {
	mut p := pnew(); p.integer('rate', rate)
	jo := call('debug/set-mutex-profile-fraction', p.build()) or { return err }
	return jo.key('previousRate').as[int]()
}
pub fn (d Debug) set_soft_memory_limit(mem_limit i64) !i64 {
	mut p := pnew(); p.integer64('mem-limit', mem_limit)
	jo := call('debug/set-soft-memory-limit', p.build()) or { return err }
	return jo.key('existing-mem-limit').as[i64]()
}

// ============ 类 Fscache (2) ============

pub struct Fscache {}

pub fn (f Fscache) clear() ! { _ := call('fscache/clear', '{}') or { return err } }
pub fn (f Fscache) entries() !int {
	jo := call('fscache/entries', '{}') or { return err }
	return jo.key('entries').as[int]()
}

// ============ 类 Job (5) ============

pub struct Job {}

pub struct JobListResult {
pub:
	execute_id string @[json: 'executeId']
	jobids []int @[json: 'jobids']
	running_ids []int @[json: 'runningIds']
	finished_ids []int @[json: 'finishedIds']
}
pub struct JobStatusResult {
pub:
	finished bool @[json: 'finished']
	duration f64 @[json: 'duration']
	end_time string @[json: 'endTime']
	err string @[json: 'error']
	id i64 @[json: 'id']
	execute_id string @[json: 'executeId']
	start_time string @[json: 'startTime']
	success bool @[json: 'success']
	output map[string]string @[json: 'output']
	progress map[string]string @[json: 'progress']
}
pub struct JobBatchResult {
pub:
	parameter string @[json: 'parameter']
	err string @[json: 'error']
	input map[string]string @[json: 'input']
	path string @[json: 'path']
	status int @[json: 'status']
}

pub fn (j Job) batch(concurrency ?int, inputs_json string) ![]JobBatchResult {
	mut p := pnew()
	if v := concurrency { p.integer('concurrency', v) }
	p.obj('inputs', inputs_json)
	jo := call('job/batch', p.build()) or { return err }
	return jo.key('results').as[[]JobBatchResult]()
}
pub fn (j Job) list() !JobListResult {
	jo := call('job/list', '{}') or { return err }
	return jo.decode[JobListResult]()
}
pub fn (j Job) status(jobid int) !JobStatusResult {
	mut p := pnew(); p.integer('jobid', jobid)
	jo := call('job/status', p.build()) or { return err }
	return jo.decode[JobStatusResult]()
}
pub fn (j Job) stop(jobid int) ! {
	mut p := pnew(); p.integer('jobid', jobid)
	_ := call('job/stop', p.build()) or { return err }
}
pub fn (j Job) stopgroup(group string) ! {
	mut p := pnew(); p.put_str('group', group)
	_ := call('job/stopgroup', p.build()) or { return err }
}

// ============ 类 Mount (5) ============

pub struct Mount {}

pub struct MountPoint {
pub:
	path string @[json: 'Path']
	fs_type string @[json: 'FSType']
	mount_point string @[json: 'MountPoint']
}

pub fn (m Mount) listmounts() ![]MountPoint {
	jo := call('mount/listmounts', '{}') or { return err }
	return jo.key('mountPoints').as[[]MountPoint]()
}
pub fn (m Mount) mount(fs string, mount_point string, mount_type ?string, mount_opt ?string, vfs_opt ?string) !string {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('mountPoint', mount_point)
	if v := mount_type { p.put_str('mountType', v) }
	if v := mount_opt { p.obj('mountOpt', v) }
	if v := vfs_opt { p.obj('vfsOpt', v) }
	jo := call('mount/mount', p.build()) or { return err }
	return jo.key('mountPoint').as[string]()
}
pub fn (m Mount) types() ![]string {
	jo := call('mount/types', '{}') or { return err }
	return jo.key('mountTypes').as[[]string]()
}
pub fn (m Mount) unmount(mount_point string) ! {
	mut p := pnew(); p.put_str('mountPoint', mount_point)
	_ := call('mount/unmount', p.build()) or { return err }
}
pub fn (m Mount) unmountall() ! { _ := call('mount/unmountall', '{}') or { return err } }

// ============ 类 Operations (24) ============

pub struct Operations {}

pub struct ListItem {
pub:
	path string @[json: 'Path']
	name string @[json: 'Name']
	size i64 @[json: 'Size']
	mime_type string @[json: 'MimeType']
	mod_time string @[json: 'ModTime']
	is_dir bool @[json: 'IsDir']
	hashes map[string]string @[json: 'Hashes']
}
pub struct OperationsSizeResult {
pub:
	count i64 @[json: 'count']
	bytes i64 @[json: 'bytes']
	sizeless i64 @[json: 'sizeless']
}
pub struct OperationsCheckResult {
pub:
	success bool @[json: 'success']
	status string @[json: 'status']
	hash_type string @[json: 'hashType']
	combined []string @[json: 'combined']
	missing_on_src []string @[json: 'missingOnSrc']
	missing_on_dst []string @[json: 'missingOnDst']
	@match []string @[json: 'match']
	differ []string @[json: 'differ']
	err_list []string @[json: 'error']
}
pub struct AboutResult {
pub:
	total i64 @[json: 'total']
	used i64 @[json: 'used']
	free i64 @[json: 'free']
}
pub struct FsFeatures {
pub:
	about bool @[json: 'About']
	command bool @[json: 'Command']
	public_link bool @[json: 'PublicLink']
	purge bool @[json: 'Purge']
	move bool @[json: 'Move']
	copy bool @[json: 'Copy']
}
pub struct FsinfoResult {
pub:
	name string @[json: 'Name']
	root string @[json: 'Root']
	str string @[json: 'String']
	hashes []string @[json: 'Hashes']
	features FsFeatures @[json: 'Features']
}

pub fn (o Operations) about(fs string) !AboutResult {
	mut p := pnew(); p.put_str('fs', fs)
	jo := call('operations/about', p.build()) or { return err }
	return jo.decode[AboutResult]()
}
pub fn (o Operations) check(src_fs string, dst_fs string, download ?bool, check_file_hash ?string, check_file_fs ?string, check_file_remote ?string, one_way ?bool, combined ?bool, missing_on_src ?bool, missing_on_dst ?bool, @match ?bool, differ ?bool, error_report ?bool) !OperationsCheckResult {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('dstFs', dst_fs)
	if v := download { p.boolean('download', v) }
	if v := check_file_hash { p.put_str('checkFileHash', v) }
	if v := check_file_fs { p.put_str('checkFileFs', v) }
	if v := check_file_remote { p.put_str('checkFileRemote', v) }
	if v := one_way { p.boolean('oneWay', v) }
	if v := combined { p.boolean('combined', v) }
	if v := missing_on_src { p.boolean('missingOnSrc', v) }
	if v := missing_on_dst { p.boolean('missingOnDst', v) }
	if v := @match { p.boolean('match', v) }
	if v := differ { p.boolean('differ', v) }
	if v := error_report { p.boolean('error', v) }
	jo := call('operations/check', p.build()) or { return err }
	return jo.decode[OperationsCheckResult]()
}
pub fn (o Operations) cleanup(fs string) ! {
	mut p := pnew(); p.put_str('fs', fs)
	_ := call('operations/cleanup', p.build()) or { return err }
}
pub fn (o Operations) copyfile(src_fs string, src_remote string, dst_fs string, dst_remote string) ! {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('srcRemote', src_remote); p.put_str('dstFs', dst_fs); p.put_str('dstRemote', dst_remote)
	_ := call('operations/copyfile', p.build()) or { return err }
}
pub fn (o Operations) copyurl(fs string, remote string, url string, auto_filename ?bool) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote); p.put_str('url', url)
	if v := auto_filename { p.boolean('autoFilename', v) }
	_ := call('operations/copyurl', p.build()) or { return err }
}
pub fn (o Operations) delete(fs string) ! {
	mut p := pnew(); p.put_str('fs', fs)
	_ := call('operations/delete', p.build()) or { return err }
}
pub fn (o Operations) deletefile(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/deletefile', p.build()) or { return err }
}
pub fn (o Operations) fsinfo(fs string) !FsinfoResult {
	mut p := pnew(); p.put_str('fs', fs)
	jo := call('operations/fsinfo', p.build()) or { return err }
	return jo.decode[FsinfoResult]()
}
pub fn (o Operations) getfile(fs string, remote ?string, offset ?i64, count ?i64, head ?i64, tail ?i64, max_size ?i64, base64 ?bool) !string {
	mut p := pnew(); p.put_str('fs', fs)
	if v := remote { p.put_str('remote', v) }
	if v := offset { p.integer64('offset', v) }
	if v := count { p.integer64('count', v) }
	if v := head { p.integer64('head', v) }
	if v := tail { p.integer64('tail', v) }
	if v := max_size { p.integer64('maxSize', v) }
	if v := base64 { p.boolean('base64', v) }
	jo := call('operations/getfile', p.build()) or { return err }
	return jo.key('result').as[string]()
}
pub fn (o Operations) hashsum(fs string, hash_type ?string, download ?bool, base64 ?bool) !(string, []string) {
	mut p := pnew(); p.put_str('fs', fs)
	if v := hash_type { p.put_str('hashType', v) }
	if v := download { p.boolean('download', v) }
	if v := base64 { p.boolean('base64', v) }
	jo := call('operations/hashsum', p.build()) or { return err }
	ht := jo.key('hashType').as[string]() or { return err }
	hs := jo.key('hashsum').as[[]string]() or { return err }
	return ht, hs
}
pub fn (o Operations) hashsumfile(fs string, remote string, hash_type ?string, download ?bool, base64 ?bool) !(string, string) {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	if v := hash_type { p.put_str('hashType', v) }
	if v := download { p.boolean('download', v) }
	if v := base64 { p.boolean('base64', v) }
	jo := call('operations/hashsumfile', p.build()) or { return err }
	ht := jo.key('hashType').as[string]() or { return err }
	h := jo.key('hash').as[string]() or { return err }
	return ht, h
}
pub fn (o Operations) index(fs string, opt_json ?string) ! {
	mut p := pnew(); p.put_str('fs', fs)
	if v := opt_json { p.obj('opt', v) }
	_ := call('operations/index', p.build()) or { return err }
}
pub fn (o Operations) list(fs string, remote string, opt_json ?string) ![]ListItem {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	if v := opt_json { p.obj('opt', v) }
	jo := call('operations/list', p.build()) or { return err }
	return jo.key('list').as[[]ListItem]()
}
pub fn (o Operations) mkdir(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/mkdir', p.build()) or { return err }
}
pub fn (o Operations) movefile(src_fs string, src_remote string, dst_fs string, dst_remote string) ! {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('srcRemote', src_remote); p.put_str('dstFs', dst_fs); p.put_str('dstRemote', dst_remote)
	_ := call('operations/movefile', p.build()) or { return err }
}
pub fn (o Operations) publiclink(fs string, remote string, unlink ?bool, expire ?string) !string {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	if v := unlink { p.boolean('unlink', v) }
	if v := expire { p.put_str('expire', v) }
	jo := call('operations/publiclink', p.build()) or { return err }
	return jo.key('url').as[string]()
}
pub fn (o Operations) purge(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/purge', p.build()) or { return err }
}
pub fn (o Operations) rmdir(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/rmdir', p.build()) or { return err }
}
pub fn (o Operations) rmdirs(fs string, remote string, leave_root ?bool) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	if v := leave_root { p.boolean('leaveRoot', v) }
	_ := call('operations/rmdirs', p.build()) or { return err }
}
pub fn (o Operations) settier(fs string) ! {
	mut p := pnew(); p.put_str('fs', fs)
	_ := call('operations/settier', p.build()) or { return err }
}
pub fn (o Operations) settierfile(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/settierfile', p.build()) or { return err }
}
pub fn (o Operations) size(fs string) !OperationsSizeResult {
	mut p := pnew(); p.put_str('fs', fs)
	jo := call('operations/size', p.build()) or { return err }
	return jo.decode[OperationsSizeResult]()
}
pub fn (o Operations) stat(fs string, remote string, opt_json ?string) !ListItem {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	if v := opt_json { p.obj('opt', v) }
	jo := call('operations/stat', p.build()) or { return err }
	return jo.key('item').as[ListItem]()
}
pub fn (o Operations) uploadfile(fs string, remote string) ! {
	mut p := pnew(); p.put_str('fs', fs); p.put_str('remote', remote)
	_ := call('operations/uploadfile', p.build()) or { return err }
}

// ============ 类 Options (5) ============

pub struct Options {}

pub struct OptionInfo {
pub:
	name string @[json: 'Name']
	help string @[json: 'Help']
	type_name string @[json: 'Type']
}
pub struct OptionsGetResult {
pub:
	main map[string]string @[json: 'main']
	vfs map[string]string @[json: 'vfs']
	mount map[string]string @[json: 'mount']
}
pub struct OptionsLocalResult {
pub:
	config map[string]string @[json: 'config']
	filter map[string]string @[json: 'filter']
}

pub fn (o Options) blocks() ![]string {
	jo := call('options/blocks', '{}') or { return err }
	return jo.key('options').as[[]string]()
}
pub fn (o Options) get(blocks ?string) !OptionsGetResult {
	mut p := pnew(); if v := blocks { p.put_str('blocks', v) }
	jo := call('options/get', p.build()) or { return err }
	return jo.decode[OptionsGetResult]()
}
pub fn (o Options) info(blocks ?string) !map[string][]OptionInfo {
	mut p := pnew(); if v := blocks { p.put_str('blocks', v) }
	jo := call('options/info', p.build()) or { return err }
	return jo.decode[map[string][]OptionInfo]()
}
pub fn (o Options) local() !OptionsLocalResult {
	jo := call('options/local', '{}') or { return err }
	return jo.decode[OptionsLocalResult]()
}
pub fn (o Options) set(data_json string) ! {
	_ := call('options/set', data_json) or { return err }
}

// ============ 类 Rc (6) ============

pub struct Rc {}

pub struct RcCommandInfo {
pub:
	title string @[json: 'title']
	help string @[json: 'help']
	auth bool @[json: 'auth']
}

pub fn (r Rc) error(input ?string) ! {
	mut p := pnew(); if v := input { p.put_str('input', v) }
	_ := call('rc/error', p.build()) or { return err }
}
pub fn (r Rc) fatal(input ?string) ! {
	mut p := pnew(); if v := input { p.put_str('input', v) }
	_ := call('rc/fatal', p.build()) or { return err }
}
pub fn (r Rc) list() !map[string]RcCommandInfo {
	jo := call('rc/list', '{}') or { return err }
	return jo.key('commands').as[map[string]RcCommandInfo]()
}
pub fn (r Rc) noop(input_json string) !map[string]string {
	jo := call('rc/noop', input_json) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (r Rc) noopauth(input_json string) !map[string]string {
	jo := call('rc/noopauth', input_json) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (r Rc) panic(input ?string) ! {
	mut p := pnew(); if v := input { p.put_str('input', v) }
	_ := call('rc/panic', p.build()) or { return err }
}

// ============ 类 Serve (5) ============

pub struct Serve {}

pub struct ServeParams {
pub:
	fs string @[json: 'fs']
	type_name string @[json: 'type']
	opt map[string]string @[json: 'opt']
	vfs_opt map[string]string @[json: 'vfsOpt']
}
pub struct ServeItem {
pub:
	addr string @[json: 'addr']
	id string @[json: 'id']
	params ServeParams @[json: 'params']
}

pub fn (s Serve) list() ![]ServeItem {
	jo := call('serve/list', '{}') or { return err }
	return jo.key('list').as[[]ServeItem]()
}
pub fn (s Serve) start(server_type string, fs string, addr ?string, extra_json ?string) !(string, string) {
	mut p := pnew(); p.put_str('type', server_type); p.put_str('fs', fs)
	if v := addr { p.put_str('addr', v) }
	if v := extra_json {
		for k, val in json.decode[map[string]string](v) or { map[string]string{} } { p.put_str(k, val) }
	}
	jo := call('serve/start', p.build()) or { return err }
	a := jo.key('addr').as[string]() or { return err }
	id := jo.key('id').as[string]() or { return err }
	return a, id
}
pub fn (s Serve) stop(id string) ! {
	mut p := pnew(); p.put_str('id', id)
	_ := call('serve/stop', p.build()) or { return err }
}
pub fn (s Serve) stopall() ! { _ := call('serve/stopall', '{}') or { return err } }
pub fn (s Serve) types() ![]string {
	jo := call('serve/types', '{}') or { return err }
	return jo.key('types').as[[]string]()
}

// ============ 类 Sync (4) ============

pub struct Sync {}

pub struct SyncReport {
pub:
	combined []string @[json: 'combined']
	missing_on_src []string @[json: 'missingOnSrc']
	missing_on_dst []string @[json: 'missingOnDst']
	@match []string @[json: 'match']
	differ []string @[json: 'differ']
	err_list []string @[json: 'error']
	dest_after []string @[json: 'destAfter']
}

pub fn (s Sync) bisync(path1 string, path2 string, opts_json ?string) !SyncReport {
	mut p := pnew(); p.put_str('path1', path1); p.put_str('path2', path2)
	if v := opts_json {
		for k, val in json.decode[map[string]string](v) or { map[string]string{} } { p.put_str(k, val) }
	}
	jo := call('sync/bisync', p.build()) or { return err }
	return jo.decode[SyncReport]()
}
pub fn (s Sync) copy(src_fs string, dst_fs string, create_empty_src_dirs ?bool, combined ?bool, missing_on_src ?bool, missing_on_dst ?bool, @match ?bool, differ ?bool, error_report ?bool, dest_after ?bool) !SyncReport {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('dstFs', dst_fs)
	if v := create_empty_src_dirs { p.boolean('createEmptySrcDirs', v) }
	if v := combined { p.boolean('combined', v) }
	if v := missing_on_src { p.boolean('missingOnSrc', v) }
	if v := missing_on_dst { p.boolean('missingOnDst', v) }
	if v := @match { p.boolean('match', v) }
	if v := differ { p.boolean('differ', v) }
	if v := error_report { p.boolean('error', v) }
	if v := dest_after { p.boolean('destAfter', v) }
	jo := call('sync/copy', p.build()) or { return err }
	return jo.decode[SyncReport]()
}
pub fn (s Sync) move(src_fs string, dst_fs string, create_empty_src_dirs ?bool, delete_empty_src_dirs ?bool, combined ?bool, missing_on_src ?bool, missing_on_dst ?bool, @match ?bool, differ ?bool, error_report ?bool, dest_after ?bool) !SyncReport {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('dstFs', dst_fs)
	if v := create_empty_src_dirs { p.boolean('createEmptySrcDirs', v) }
	if v := delete_empty_src_dirs { p.boolean('deleteEmptySrcDirs', v) }
	if v := combined { p.boolean('combined', v) }
	if v := missing_on_src { p.boolean('missingOnSrc', v) }
	if v := missing_on_dst { p.boolean('missingOnDst', v) }
	if v := @match { p.boolean('match', v) }
	if v := differ { p.boolean('differ', v) }
	if v := error_report { p.boolean('error', v) }
	if v := dest_after { p.boolean('destAfter', v) }
	jo := call('sync/move', p.build()) or { return err }
	return jo.decode[SyncReport]()
}
pub fn (s Sync) sync(src_fs string, dst_fs string, create_empty_src_dirs ?bool, combined ?bool, missing_on_src ?bool, missing_on_dst ?bool, @match ?bool, differ ?bool, error_report ?bool, dest_after ?bool) !SyncReport {
	mut p := pnew(); p.put_str('srcFs', src_fs); p.put_str('dstFs', dst_fs)
	if v := create_empty_src_dirs { p.boolean('createEmptySrcDirs', v) }
	if v := combined { p.boolean('combined', v) }
	if v := missing_on_src { p.boolean('missingOnSrc', v) }
	if v := missing_on_dst { p.boolean('missingOnDst', v) }
	if v := @match { p.boolean('match', v) }
	if v := differ { p.boolean('differ', v) }
	if v := error_report { p.boolean('error', v) }
	if v := dest_after { p.boolean('destAfter', v) }
	jo := call('sync/sync', p.build()) or { return err }
	return jo.decode[SyncReport]()
}

// ============ 类 Vfs (7) ============

pub struct Vfs {}

pub struct VfsPollResult {
pub:
	current string @[json: 'current']
	status string @[json: 'status']
}
pub struct VfsQueueItem {
pub:
	name string @[json: 'name']
	id i64 @[json: 'id']
	size i64 @[json: 'size']
	expiry f64 @[json: 'expiry']
	tries i64 @[json: 'tries']
	delay f64 @[json: 'delay']
	uploading bool @[json: 'uploading']
}
pub struct DiskCache {
pub:
	bytes_used i64 @[json: 'bytesUsed']
	errored_files i64 @[json: 'erroredFiles']
	files i64 @[json: 'files']
	hash_type i64 @[json: 'hashType']
	out_of_space bool @[json: 'outOfSpace']
	path string @[json: 'path']
	path_meta string @[json: 'pathMeta']
	uploads_in_progress i64 @[json: 'uploadsInProgress']
	uploads_queued i64 @[json: 'uploadsQueued']
}
pub struct MetadataCache {
pub:
	dirs i64 @[json: 'dirs']
	files i64 @[json: 'files']
}
pub struct VfsStatsResult {
pub:
	fs string @[json: 'fs']
	in_use i64 @[json: 'inUse']
	disk_cache DiskCache @[json: 'diskCache']
	metadata_cache MetadataCache @[json: 'metadataCache']
	opt map[string]string @[json: 'opt']
}

pub fn (v Vfs) forget(fs ?string, files []string, dirs []string) ! {
	mut p := pnew(); if v2 := fs { p.put_str('fs', v2) }
	for i, f in files { p.put_str(if i == 0 { 'file' } else { 'file${i+1}' }, f) }
	for i, d in dirs { p.put_str(if i == 0 { 'dir' } else { 'dir${i+1}' }, d) }
	_ := call('vfs/forget', p.build()) or { return err }
}
pub fn (v Vfs) list() ![]string {
	jo := call('vfs/list', '{}') or { return err }
	return jo.key('vfses').as[[]string]()
}
pub fn (v Vfs) poll_interval(fs ?string, interval ?string, timeout ?string) !VfsPollResult {
	mut p := pnew()
	if v2 := fs { p.put_str('fs', v2) }
	if i := interval { p.put_str('interval', i) }
	if t := timeout { p.put_str('timeout', t) }
	jo := call('vfs/poll-interval', p.build()) or { return err }
	return jo.decode[VfsPollResult]()
}
pub fn (v Vfs) queue(fs ?string) ![]VfsQueueItem {
	mut p := pnew(); if v2 := fs { p.put_str('fs', v2) }
	jo := call('vfs/queue', p.build()) or { return err }
	return jo.key('queue').as[[]VfsQueueItem]()
}
pub fn (v Vfs) queue_set_expiry(fs ?string, id int, expiry f64, relative ?bool) ! {
	mut p := pnew()
	if v2 := fs { p.put_str('fs', v2) }
	p.integer('id', id); p.float('expiry', expiry)
	if r := relative { p.boolean('relative', r) }
	_ := call('vfs/queue-set-expiry', p.build()) or { return err }
}
pub fn (v Vfs) refresh(fs ?string, dirs []string, recursive ?bool) !map[string]string {
	mut p := pnew(); if v2 := fs { p.put_str('fs', v2) }
	for i, d in dirs { p.put_str(if i == 0 { 'dir' } else { 'dir${i+1}' }, d) }
	if r := recursive { p.boolean('recursive', r) }
	jo := call('vfs/refresh', p.build()) or { return err }
	return jo.decode[map[string]string]()
}
pub fn (v Vfs) stats(fs ?string) !VfsStatsResult {
	mut p := pnew(); if v2 := fs { p.put_str('fs', v2) }
	jo := call('vfs/stats', p.build()) or { return err }
	return jo.decode[VfsStatsResult]()
}
