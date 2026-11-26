import vrtinfo
import os
import time

mut name := 'vrtinfo-demo'
mut i := 0
for i < os.args.len {
	if os.args[i] == '-name' && i + 1 < os.args.len {
		name = os.args[i + 1]
		i += 2
		continue
	}
	i++
}

// 被监控进程：内嵌 vrtinfo server 后保持运行
s := vrtinfo.start_named(name) or {
	panic('vrtinfo start failed: ' + err.msg())
}
println('service name: ${s.name}')
for {
	time.sleep(1000 * time.millisecond)
}
