#include <ntipc.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
typedef HANDLE thread_t;
static DWORD WINAPI thread_fn(void* p) { void (**fn)(void*) = (void(**)(void*))p; /*unused*/ return 0; }
static void sleep_ms(int ms) { Sleep((DWORD)ms); }
#else
#include <poll.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
typedef pthread_t thread_t;
static void sleep_ms(int ms) { poll(NULL, 0, ms); }
#endif

static int g_failures = 0;
#define CHECK(cond, msg) do { if (!(cond)) { fprintf(stderr, "FAIL: %s (%s:%d)\n", msg, __FILE__, __LINE__); g_failures++; } } while (0)

struct connect_arg { const char* name; int timeout; void* out; };
#if defined(_WIN32)
static DWORD WINAPI connect_thread(LPVOID p) { struct connect_arg* a = (struct connect_arg*)p; a->out = ntipc_connect(a->name, a->timeout); return 0; }
static thread_t start_connect(struct connect_arg* a) { return CreateThread(NULL, 0, connect_thread, a, 0, NULL); }
static void join_thread(thread_t t) { WaitForSingleObject(t, INFINITE); CloseHandle(t); }
#else
static void* connect_thread(void* p) { struct connect_arg* a = (struct connect_arg*)p; a->out = ntipc_connect(a->name, a->timeout); return NULL; }
static thread_t start_connect(struct connect_arg* a) { thread_t t; pthread_create(&t, NULL, connect_thread, a); return t; }
static void join_thread(thread_t t) { pthread_join(t, NULL); }
#endif

static void* accept_wait(void* l, int ms)
{
	for (int i = 0; i < ms / 5; i++) {
		void* s = ntipc_accept(l);
		if (s) return s;
		sleep_ms(5);
	}
	return NULL;
}

static void test_round_trip(void)
{
	void* l = ntipc_listen("ntipc-test-roundtrip");
	CHECK(l != NULL, "listen");
	CHECK(ntipc_last_error() == NTIPC_ERROR_NONE, "listen err none");

	struct connect_arg ca = {"ntipc-test-roundtrip", 3000, NULL};
	thread_t th = start_connect(&ca);
	void* s = accept_wait(l, 3000);
	join_thread(th);
	void* c = ca.out;
	CHECK(c != NULL, "connect");
	CHECK(s != NULL, "accept");
	if (!c || !s) { if (c) ntipc_close(c); if (s) ntipc_close(s); ntipc_close(l); return; }

	const char* msg = "hello-ntipc";
	CHECK(ntipc_write(c, (const unsigned char*)msg, (int)strlen(msg)), "client write");
	unsigned char buf[64]; memset(buf, 0, sizeof(buf));
	for (int i = 0; i < 400 && ntipc_bytes_available(s) < (int)strlen(msg); i++) sleep_ms(5);
	CHECK(ntipc_read(s, buf, (int)strlen(msg)) == 0, "server read");
	CHECK(memcmp(buf, msg, strlen(msg)) == 0, "payload match");

	CHECK(ntipc_write(s, (const unsigned char*)"ok", 2), "server write");
	memset(buf, 0, sizeof(buf));
	for (int i = 0; i < 400 && ntipc_bytes_available(c) < 2; i++) sleep_ms(5);
	CHECK(ntipc_read(c, buf, 2) == 0, "client read");
	CHECK(memcmp(buf, "ok", 2) == 0, "reply match");

	CHECK(ntipc_is_open(c), "client open");
	CHECK(ntipc_is_open(s), "server open");

	ntipc_close(c);
	ntipc_close(s);
	ntipc_close(l);
}

static void test_peer_loss(void)
{
	void* l = ntipc_listen("ntipc-test-loss");
	struct connect_arg ca = {"ntipc-test-loss", 3000, NULL};
	thread_t th = start_connect(&ca);
	void* s = accept_wait(l, 3000);
	join_thread(th);
	void* c = ca.out;
	CHECK(c != NULL && s != NULL, "pair loss");
	if (!c || !s) { if (c) ntipc_close(c); if (s) ntipc_close(s); ntipc_close(l); return; }
	ntipc_close(c);
	for (int i = 0; i < 400 && ntipc_is_open(s); i++) sleep_ms(5);
	/* peer closed: is_open may become false or bytes_available becomes -1/0; read should detect */
	int avail = ntipc_bytes_available(s);
	CHECK(!ntipc_is_open(s) || avail <= 0, "server sees loss");
	ntipc_close(s);
	ntipc_close(l);
}

static void test_name_in_use(void)
{
	void* l1 = ntipc_listen("ntipc-test-inuse");
	CHECK(l1 != NULL, "listen1");
	void* l2 = ntipc_listen("ntipc-test-inuse");
	CHECK(l2 == NULL, "listen2 fails");
	CHECK(ntipc_last_error() == NTIPC_ERROR_IN_USE, "in use error");
	ntipc_close(l1);
}

static void test_connect_timeout(void)
{
	void* c = ntipc_connect("ntipc-no-such-listener-xyz", 150);
	CHECK(c == NULL, "connect timeout returns null");
	CHECK(ntipc_last_error() == NTIPC_ERROR_TIMEOUT || ntipc_last_error() == NTIPC_ERROR_FAILED, "timeout error");
	(void)c;
}

static void test_many_clients(void)
{
	void* l = ntipc_listen("ntipc-test-many");
	CHECK(l != NULL, "listen many");
	enum { N = 8 };
	void* clients[N]; void* servers[N];
	struct connect_arg cas[N]; thread_t ths[N];
	for (int i = 0; i < N; i++) { cas[i].name = "ntipc-test-many"; cas[i].timeout = 3000; cas[i].out = NULL; ths[i] = start_connect(&cas[i]); }
	for (int i = 0; i < N; i++) servers[i] = NULL;
	for (int got = 0; got < N; ) {
		void* s = ntipc_accept(l);
		if (s) { servers[got++] = s; }
		else sleep_ms(5);
	}
	for (int i = 0; i < N; i++) { join_thread(ths[i]); clients[i] = cas[i].out; CHECK(clients[i] != NULL, "connect many"); CHECK(servers[i] != NULL, "accept many"); }
	for (int i = 0; i < N; i++) {
		unsigned char b = (unsigned char)(i + 1);
		if (clients[i]) CHECK(ntipc_write(clients[i], &b, 1), "write many");
	}
	int seen[256]; memset(seen, 0, sizeof(seen));
	for (int i = 0; i < N; i++) {
		if (servers[i]) {
			unsigned char r = 0;
			for (int j = 0; j < 400 && ntipc_bytes_available(servers[i]) < 1; j++) sleep_ms(5);
			CHECK(ntipc_read(servers[i], &r, 1) == 0, "read many");
			if (r > 0 && r <= N) seen[r - 1]++;
		}
	}
	for (int i = 0; i < N; i++) CHECK(seen[i] == 1, "payload many unique");
	for (int i = 0; i < N; i++) { if (clients[i]) ntipc_close(clients[i]); if (servers[i]) ntipc_close(servers[i]); }
	ntipc_close(l);
}

struct rw_arg { void* conn; unsigned char* buf; int n; int ok; };
#if defined(_WIN32)
static DWORD WINAPI writer_thread(LPVOID p) { struct rw_arg* a = (struct rw_arg*)p; a->ok = ntipc_write(a->conn, a->buf, a->n) ? 1 : 0; return 0; }
static DWORD WINAPI reader_thread(LPVOID p) { struct rw_arg* a = (struct rw_arg*)p; a->ok = (ntipc_read(a->conn, a->buf, a->n) == 0) ? 1 : 0; return 0; }
#else
static void* writer_thread(void* p) { struct rw_arg* a = (struct rw_arg*)p; a->ok = ntipc_write(a->conn, a->buf, a->n) ? 1 : 0; return NULL; }
static void* reader_thread(void* p) { struct rw_arg* a = (struct rw_arg*)p; a->ok = (ntipc_read(a->conn, a->buf, a->n) == 0) ? 1 : 0; return NULL; }
#endif

static void test_framing_large(void)
{
	void* l = ntipc_listen("ntipc-test-large");
	struct connect_arg ca = {"ntipc-test-large", 3000, NULL};
	thread_t th = start_connect(&ca);
	void* s = accept_wait(l, 3000);
	join_thread(th);
	void* c = ca.out;
	CHECK(c != NULL && s != NULL, "pair large");
	if (!c || !s) { if (c) ntipc_close(c); if (s) ntipc_close(s); ntipc_close(l); return; }
	size_t n = 256 * 1024;
	unsigned char* sendbuf = (unsigned char*)malloc(n);
	unsigned char* recvbuf = (unsigned char*)malloc(n);
	for (size_t i = 0; i < n; i++) sendbuf[i] = (unsigned char)(i * 131u + 7u);
	struct rw_arg wa = {c, sendbuf, (int)n, 0};
	struct rw_arg ra = {s, recvbuf, (int)n, 0};
#if defined(_WIN32)
	HANDLE wt = CreateThread(NULL, 0, writer_thread, &wa, 0, NULL);
	HANDLE rt = CreateThread(NULL, 0, reader_thread, &ra, 0, NULL);
	WaitForSingleObject(wt, INFINITE); WaitForSingleObject(rt, INFINITE);
	CloseHandle(wt); CloseHandle(rt);
#else
	pthread_t wt, rt;
	pthread_create(&wt, NULL, writer_thread, &wa);
	pthread_create(&rt, NULL, reader_thread, &ra);
	pthread_join(wt, NULL); pthread_join(rt, NULL);
#endif
	CHECK(wa.ok, "write large");
	CHECK(ra.ok, "read large");
	CHECK(memcmp(sendbuf, recvbuf, n) == 0, "large payload match");
	free(sendbuf); free(recvbuf);
	ntipc_close(c); ntipc_close(s); ntipc_close(l);
}

int main(void)
{
	test_round_trip();
	test_peer_loss();
	test_name_in_use();
	test_connect_timeout();
	test_many_clients();
	test_framing_large();
	if (g_failures == 0)
	{
		printf("ntipc pipe tests ok\n");
		return 0;
	}
	fprintf(stderr, "%d failures\n", g_failures);
	return 1;
}
