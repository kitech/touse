import touse.rclone

fn test_rclone_rpc() {
	if !rclone.libok() && rclone.dyn_init('') != 0 {
		println('SKIP: librclone not available')
		return
	}
	rclone.initialize()
	defer { rclone.finalize() }
	r := rclone.rpc('core/version', '{}')
	assert r.status == 200
	assert r.output.len > 0 && r.output[0] == `{`
	bad := rclone.rpc('no/such/method', '{}')
	assert bad.status != 200
}
