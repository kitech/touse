#include "internal.h"

#include <stdio.h>
#include <string.h>

#if !defined(_WIN32)
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#endif

// Why the last listen, accept or connect failed: what ntipc_last_error
// answers, so the caller can tell a name that is not this user's from one in
// use or not listened on. C11 _Thread_local; MSVC before 2022 uses __declspec.
#if defined(_MSC_VER)
#define NTIPC_THREAD_LOCAL __declspec(thread)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define NTIPC_THREAD_LOCAL _Thread_local
#else
#define NTIPC_THREAD_LOCAL
#endif

static NTIPC_THREAD_LOCAL int last_error_value = NTIPC_ERROR_NONE;

static const unsigned char HELLO_MAGIC[4] = {'N', 'I', 'P', 'C'};

static uint64_t mix(uint64_t value)
{
	// splitmix64's finaliser.
	value += 0x9e3779b97f4a7c15ULL;
	value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9ULL;
	value = (value ^ (value >> 27)) * 0x94d049bb133111ebULL;
	return value ^ (value >> 31);
}

void n_set_last_error(int error)
{
	last_error_value = error;
}

int n_last_error(void)
{
	return last_error_value;
}

int ntipc_last_error(void)
{
	return n_last_error();
}

void n_write_hello(unsigned char* out, uint64_t id)
{
	out[0] = HELLO_MAGIC[0];
	out[1] = HELLO_MAGIC[1];
	out[2] = HELLO_MAGIC[2];
	out[3] = HELLO_MAGIC[3];
	out[4] = (unsigned char)(NTIPC_PROTOCOL_VERSION & 0xff);
	out[5] = (unsigned char)((NTIPC_PROTOCOL_VERSION >> 8) & 0xff);
	// Flags: none are defined, and a peer sending any is still spoken to.
	out[6] = 0;
	out[7] = 0;
	for (int i = 0; i < 8; i++)
	{
		out[8 + i] = (unsigned char)((id >> (8 * i)) & 0xff);
	}
}

bool n_read_hello(const unsigned char* in, uint64_t* id)
{
	if (in[0] != HELLO_MAGIC[0] || in[1] != HELLO_MAGIC[1] || in[2] != HELLO_MAGIC[2] || in[3] != HELLO_MAGIC[3])
	{
		return false;
	}
	int version = in[4] | (in[5] << 8);
	if (version != NTIPC_PROTOCOL_VERSION)
	{
		return false;
	}
	uint64_t value = 0;
	for (int i = 0; i < 8; i++)
	{
		value |= (uint64_t)in[8 + i] << (8 * i);
	}
	*id = value;
	return true;
}

uint64_t n_new_connection_id(void)
{
	uint32_t sequence;
#if defined(_WIN32)
	uint64_t process = (uint64_t)GetCurrentProcessId();
	static volatile LONG counter = 0;
	// InterlockedIncrement is available on XP/Server 2003. The 64-bit
	// Interlocked*64 APIs require Vista on the client. The sequence only
	// feeds mix(), so a 32-bit counter is enough.
	sequence = (uint32_t)InterlockedIncrement(&counter);
#else
	uint64_t process = (uint64_t)getpid();
	// A mutex, not a compiler atomic: V embeds this source into its generated
	// C, whose default compiler (tcc) has neither __atomic_* nor __sync_*.
	static uint32_t counter = 0;
	static pthread_mutex_t counter_lock = PTHREAD_MUTEX_INITIALIZER;
	pthread_mutex_lock(&counter_lock);
	sequence = ++counter;
	pthread_mutex_unlock(&counter_lock);
#endif
	uint64_t now = (uint64_t)n_now_ms();
	uint64_t id = 0;
	while (id == 0)
	{
		id = mix(now ^ (process << 32) ^ mix(sequence));
	}
	return id;
}

uint64_t n_hash_name(const char* input)
{
	// 64-bit FNV-1a.
	uint64_t hash = 1469598103934665603ULL;
	if (input != NULL)
	{
		for (const unsigned char* p = (const unsigned char*)input; *p != '\0'; p++)
		{
			hash ^= *p;
			hash *= 1099511628211ULL;
		}
	}
	return hash;
}

void n_hex64(uint64_t value, char out[17])
{
	snprintf(out, 17, "%016llx", (unsigned long long)value);
}

int64_t n_now_ms(void)
{
#if defined(_WIN32)
	// QueryPerformanceCounter is available on XP. A single read at startup is
	// enough; the raw count is monotonic and need not be rebased.
	static LONG64 frequency = 0;
	if (frequency == 0)
	{
		LARGE_INTEGER query;
		if (QueryPerformanceFrequency(&query) && query.QuadPart > 0)
		{
			frequency = query.QuadPart;
		}
	}
	LARGE_INTEGER counter;
	if (frequency > 0 && QueryPerformanceCounter(&counter))
	{
		return (int64_t)(counter.QuadPart * 1000 / frequency);
	}
	return (int64_t)GetTickCount(); // XP-safe fallback.
#else
	struct timespec ts;
	if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
	{
		return 0;
	}
	return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
#endif
}

bool n_another_try(bool forever, int64_t deadline)
{
	return forever || n_now_ms() + NTIPC_CONNECT_WAIT_SLICE_MS < deadline;
}
