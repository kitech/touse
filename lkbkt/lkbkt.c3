// C3 binding for lkbkt (single file, safe wrapper + self-test).
//
// Build via `make c3-check`, which compiles leakybucket.c into
// build/c3/liblkbkt.a and then links it with c3c.
//
// To use as a library inside your own project: drop `fn void main` and
// import the module.

module lkbkt;

import std::io;

const NODELAY = 0xFFFF_FFFF;

enum Result : int
{
	PASS,
	DELAY,
	REJECT,
	ERROR,
}

extern fn void* lkbkt_new(uint rate, uint burst, uint delay, usz max_keys);
extern fn void  lkbkt_free(void* handle);
extern fn int   lkbkt_check(void* handle, char* key, usz keylen, ulong now_ms, uint* delay_ms);
extern fn usz   lkbkt_expire(void* handle, ulong now_ms);
extern fn usz   lkbkt_size(void* handle);

struct Decision
{
	Result result;
	uint delay_ms;
}

struct Bucket
{
	void* handle;
}

fn bool Bucket.init(&self, uint rate, uint burst, uint delay, usz max_keys)
{
	self.handle = null;
	if (rate == 0 || max_keys == 0) return false;
	self.handle = lkbkt_new(rate, burst, delay, max_keys);
	return self.handle != null;
}

fn void Bucket.destroy(&self)
{
	if (self.handle != null)
	{
		lkbkt_free(self.handle);
		self.handle = null;
	}
}

fn Decision Bucket.check(&self, String key, ulong now_ms)
{
	if (self.handle == null) return { .result = Result.ERROR, .delay_ms = 0 };

	uint delay_ms = 0;
	int r = lkbkt_check(self.handle, key.ptr, key.len, now_ms, &delay_ms);
	return { .result = (Result)r, .delay_ms = delay_ms };
}

fn usz Bucket.expire(&self, ulong now_ms)
{
	if (self.handle == null) return 0;
	return lkbkt_expire(self.handle, now_ms);
}

fn usz Bucket.size(&self)
{
	if (self.handle == null) return 0;
	return lkbkt_size(self.handle);
}

struct Timespec
{
	long tv_sec;
	long tv_nsec;
}

extern fn int clock_gettime(int clk_id, Timespec* tp);
const CLOCK_MONOTONIC = 1;

fn ulong now_ms()
{
	Timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (ulong)ts.tv_sec * 1000 + (ulong)ts.tv_nsec / 1000000;
}

fn void main()
{
	Bucket b;
	if (!b.init(10, 5, 0, 1024))
	{
		io::printn("c3: init failed");
		return;
	}

	Decision d = b.check("192.0.2.1", 1000);
	assert(d.result == Result.PASS);
	assert(d.delay_ms == 0);

	d = b.check("192.0.2.1", 1000);
	assert(d.result == Result.DELAY);
	assert(d.delay_ms == 100);

	d = b.check("192.0.2.1", 1000);
	assert(d.delay_ms == 200);

	for (usz i = 0; i < 3; i++)
	{
		d = b.check("192.0.2.1", 1000);
	}

	assert(b.check("192.0.2.1", 1000).result == Result.REJECT);
	assert(b.check("192.0.2.1", 2000).result == Result.PASS);
	assert(b.expire(62000) == 1);
	assert(b.size() == 0);

	b.destroy();
	assert(b.size() == 0);

	io::printn("c3: all checks passed");
}
