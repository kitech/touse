#ifndef NTIPC_INTERNAL_H
#define NTIPC_INTERNAL_H

#include <ntipc.h>

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#endif

// What every handle begins with, so one passed where the other kind was
// meant is refused rather than misread.
#define NTIPC_KIND_LISTENER 0x4c495354u   /* 'LIST' */
#define NTIPC_KIND_CONNECTION 0x434f4e4eu /* 'CONN' */

struct ntipc_handle_base
{
	uint32_t kind;
};

// How long a connect waits between tries, and the longest a listener
// waits for a client that has connected to say hello.
#define NTIPC_CONNECT_WAIT_SLICE_MS 50
#define NTIPC_HELLO_TIMEOUT_MS 1000
// How long ntipc_read and ntipc_write wait at most.
#define NTIPC_IO_TIMEOUT_MS 5000

// The hello each end sends first: see PROTOCOL.md.
#define NTIPC_HELLO_SIZE 16
void n_write_hello(unsigned char* out, uint64_t id);
// Whether `in` is a hello of this protocol's version, and its id.
bool n_read_hello(const unsigned char* in, uint64_t* id);
// An id no other connection of this process has, and almost certainly
// no other process's.
uint64_t n_new_connection_id(void);

uint64_t n_hash_name(const char* input);
void n_hex64(uint64_t value, char out[17]);

void n_set_last_error(int error);
int n_last_error(void);

// A monotonic clock in milliseconds, for deadlines. No GetTickCount64 (Vista+):
// Windows uses QueryPerformanceCounter, POSIX clock_gettime.
int64_t n_now_ms(void);

// Whether another attempt fits before `deadline`.
bool n_another_try(bool forever, int64_t deadline);

// Wakes a thread waiting in n_wait_any from another. Implemented per platform.
struct n_waker
{
#if defined(_WIN32)
	HANDLE event;
#else
	int fds[2];
#endif
};
void n_waker_init(struct n_waker* waker);
void n_waker_fini(struct n_waker* waker);
void n_waker_signal(struct n_waker* waker);
void n_waker_drain(struct n_waker* waker);

// Public calls without their blocking scope, for threads no collector stops.
// `cancel` (when given) makes connect give up between tries and while waiting
// for the listener's hello.
void* n_connect(const char* name, int timeoutMs, const volatile bool* cancel);

// Waits up to `timeoutMs` for `handle` to have something to read (or a client
// to take, for a listener) when `read`, room to write when `write`, or for
// `waker` to be signalled. Whether `waker` was.
bool n_wait_any(void* handle, bool read, bool write, struct n_waker* waker, int timeoutMs);

// Whether a listener has clients that have connected and not said hello yet.
bool n_handshaking(void* handle);

#endif
