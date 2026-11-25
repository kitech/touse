#if defined(_WIN32)

#include "internal.h"

#include <aclapi.h>
#include <sddl.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Vista's; older SDKs leave it out.
#ifndef PIPE_REJECT_REMOTE_CLIENTS
#define PIPE_REJECT_REMOTE_CLIENTS 0x00000008
#endif

#define N_PIPE_BUFFER_SIZE 65536
#define N_ACCEPTS_PER_CALL 16

static bool is_invalid(HANDLE handle)
{
	return handle == NULL || handle == INVALID_HANDLE_VALUE;
}

struct process_user
{
	BYTE sid[SECURITY_MAX_SID_SIZE];
	DWORD sid_len;
	char text[256];
	bool valid;
};

static struct process_user g_user;
static bool g_user_init = false;

static const struct process_user* process_user_get(void)
{
	if (g_user_init)
	{
		return &g_user;
	}
	g_user_init = true;
	memset(&g_user, 0, sizeof(g_user));
	HANDLE token = NULL;
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token))
	{
		return &g_user;
	}
	DWORD size = 0;
	GetTokenInformation(token, TokenUser, NULL, 0, &size);
	if (size > 0)
	{
		BYTE* buffer = (BYTE*)malloc(size);
		if (buffer != NULL && GetTokenInformation(token, TokenUser, buffer, size, &size))
		{
			PSID sid = ((TOKEN_USER*)buffer)->User.Sid;
			LPSTR text = NULL;
			if (IsValidSid(sid) && ConvertSidToStringSidA(sid, &text))
			{
				DWORD length = GetLengthSid(sid);
				if (length <= sizeof(g_user.sid))
				{
					memcpy(g_user.sid, sid, length);
					g_user.sid_len = length;
					snprintf(g_user.text, sizeof(g_user.text), "%s", text);
					g_user.valid = true;
				}
				LocalFree(text);
			}
		}
		free(buffer);
	}
	CloseHandle(token);
	return &g_user;
}

static bool make_own_security(PSECURITY_DESCRIPTOR* desc_out, SECURITY_ATTRIBUTES* attrs_out)
{
	const struct process_user* user = process_user_get();
	if (!user->valid)
	{
		return false;
	}
	char sddl[512];
	snprintf(sddl, sizeof(sddl), "O:%sD:P(A;;GA;;;%s)(A;;GA;;;SY)", user->text, user->text);
	if (!ConvertStringSecurityDescriptorToSecurityDescriptorA(sddl, SDDL_REVISION_1, desc_out, NULL))
	{
		*desc_out = NULL;
		return false;
	}
	attrs_out->nLength = sizeof(*attrs_out);
	attrs_out->lpSecurityDescriptor = *desc_out;
	attrs_out->bInheritHandle = FALSE;
	return true;
}

static const char* name_or_empty(const char* name)
{
	return name == NULL ? "" : name;
}

// Pipe names are one namespace for every user of the machine. The SID in the
// path makes it per-user.
static bool make_pipe_name(const char* name, char out[512])
{
	const struct process_user* user = process_user_get();
	if (!user->valid)
	{
		return false;
	}
	snprintf(out, 512, "\\\\.\\pipe\\native-ipc-%s-%s", user->text, name_or_empty(name));
	return true;
}

static void bell_base(const char* name, char out[512])
{
	char hex[17];
	n_hex64(n_hash_name(name_or_empty(name)), hex);
	snprintf(out, 512, "Local\\native-ipc-%s-%s", process_user_get()->text, hex);
}

static HANDLE make_bell(const char* name)
{
	PSECURITY_DESCRIPTOR desc = NULL;
	SECURITY_ATTRIBUTES attrs;
	if (!make_own_security(&desc, &attrs))
	{
		return NULL;
	}
	HANDLE h = CreateEventA(&attrs, FALSE, FALSE, name);
	LocalFree(desc);
	return h;
}

static void ring(HANDLE bell)
{
	if (bell != NULL)
	{
		SetEvent(bell);
	}
}

static void close_bell(HANDLE bell)
{
	if (bell != NULL)
	{
		CloseHandle(bell);
	}
}

struct ntipc_connection
{
	uint32_t kind;
	HANDLE pipe;
	HANDLE mine;
	HANDLE peer;
};

struct ntipc_pending
{
	HANDLE pipe;
	unsigned char hello[NTIPC_HELLO_SIZE];
	int got;
	int64_t deadline;
};

struct ntipc_listener
{
	uint32_t kind;
	char name[256];
	char pipe_name[512];
	HANDLE pending;
	HANDLE accept_bell;
	struct ntipc_pending* handshaking;
	size_t handshaking_len;
	size_t handshaking_cap;
};

static struct ntipc_connection* as_connection(void* handle)
{
	if (handle == NULL)
	{
		return NULL;
	}
	if (((struct ntipc_handle_base*)handle)->kind != NTIPC_KIND_CONNECTION)
	{
		return NULL;
	}
	return (struct ntipc_connection*)handle;
}

static struct ntipc_listener* as_listener(void* handle)
{
	if (handle == NULL)
	{
		return NULL;
	}
	if (((struct ntipc_handle_base*)handle)->kind != NTIPC_KIND_LISTENER)
	{
		return NULL;
	}
	return (struct ntipc_listener*)handle;
}

static HANDLE create_instance(const char* pipe_name, bool first)
{
	PSECURITY_DESCRIPTOR desc = NULL;
	SECURITY_ATTRIBUTES attrs;
	if (!make_own_security(&desc, &attrs))
	{
		return INVALID_HANDLE_VALUE;
	}
	HANDLE h = CreateNamedPipeA(
		pipe_name,
		PIPE_ACCESS_DUPLEX | (first ? FILE_FLAG_FIRST_PIPE_INSTANCE : 0),
		PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_NOWAIT | PIPE_REJECT_REMOTE_CLIENTS,
		PIPE_UNLIMITED_INSTANCES,
		N_PIPE_BUFFER_SIZE,
		N_PIPE_BUFFER_SIZE,
		0,
		&attrs);
	LocalFree(desc);
	return h;
}

static struct ntipc_connection* make_connection(HANDLE pipe, const char* name, uint64_t id, bool listener_side)
{
	struct ntipc_connection* connection = (struct ntipc_connection*)calloc(1, sizeof(*connection));
	if (connection == NULL)
	{
		CloseHandle(pipe);
		return NULL;
	}
	connection->kind = NTIPC_KIND_CONNECTION;
	connection->pipe = pipe;
	char base[512];
	char hex[17];
	n_hex64(id, hex);
	bell_base(name, base);
	char tmp[600];
	snprintf(tmp, sizeof(tmp), "%s-%s-l", base, hex);
	HANDLE to_listener = make_bell(tmp);
	snprintf(tmp, sizeof(tmp), "%s-%s-c", base, hex);
	HANDLE to_client = make_bell(tmp);
	if (to_listener != NULL && to_client != NULL)
	{
		connection->mine = listener_side ? to_listener : to_client;
		connection->peer = listener_side ? to_client : to_listener;
	}
	else
	{
		close_bell(to_listener);
		close_bell(to_client);
	}
	return connection;
}

static void close_connection(struct ntipc_connection* connection)
{
	ring(connection->peer);
	if (!is_invalid(connection->pipe))
	{
		CloseHandle(connection->pipe);
	}
	close_bell(connection->mine);
	close_bell(connection->peer);
	free(connection);
}

static bool is_gone(DWORD error)
{
	return error == ERROR_BROKEN_PIPE || error == ERROR_INVALID_HANDLE || error == ERROR_PIPE_NOT_CONNECTED;
}

static int read_some_raw(HANDLE pipe, unsigned char* buffer, int size)
{
	DWORD bytes_read = 0;
	if (ReadFile(pipe, buffer, (DWORD)size, &bytes_read, NULL))
	{
		return (int)bytes_read;
	}
	DWORD error = GetLastError();
	if (error == ERROR_MORE_DATA)
	{
		return (int)bytes_read;
	}
	if (error == ERROR_NO_DATA)
	{
		return 0;
	}
	return is_gone(error) ? -1 : 0;
}

static int write_some_raw(HANDLE pipe, const unsigned char* buffer, int size)
{
	int total_written = 0;
	while (total_written < size)
	{
		int write_size = size - total_written;
		if (write_size > N_PIPE_BUFFER_SIZE)
		{
			write_size = N_PIPE_BUFFER_SIZE;
		}
		DWORD bytes_written = 0;
		if (!WriteFile(pipe, buffer + total_written, (DWORD)write_size, &bytes_written, NULL))
		{
			DWORD error = GetLastError();
			if (error == ERROR_NO_DATA || is_gone(error))
			{
				return total_written > 0 ? total_written : -1;
			}
			break;
		}
		if (bytes_written == 0)
		{
			break;
		}
		total_written += (int)bytes_written;
	}
	return total_written;
}

static bool owned_by_process_user(HANDLE pipe)
{
	const struct process_user* user = process_user_get();
	if (!user->valid)
	{
		return false;
	}
	PSID owner = NULL;
	PSECURITY_DESCRIPTOR descriptor = NULL;
	if (GetSecurityInfo(pipe, SE_KERNEL_OBJECT, OWNER_SECURITY_INFORMATION, &owner, NULL, NULL, NULL, &descriptor) != ERROR_SUCCESS)
	{
		return false;
	}
	bool same = owner != NULL && IsValidSid(owner) && EqualSid(owner, (PSID)user->sid);
	LocalFree(descriptor);
	return same;
}

static HANDLE bell_of(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection != NULL)
	{
		return connection->mine;
	}
	struct ntipc_listener* listener = as_listener(handle);
	if (listener != NULL)
	{
		return listener->accept_bell;
	}
	return NULL;
}

void n_waker_init(struct n_waker* waker)
{
	waker->event = CreateEventA(NULL, FALSE, FALSE, NULL);
}

void n_waker_fini(struct n_waker* waker)
{
	if (waker->event != NULL)
	{
		CloseHandle(waker->event);
	}
}

void n_waker_signal(struct n_waker* waker)
{
	if (waker->event != NULL)
	{
		SetEvent(waker->event);
	}
}

void n_waker_drain(struct n_waker* waker)
{
	(void)waker;
}

bool n_wait_any(void* handle, bool read, bool write, struct n_waker* waker, int timeoutMs)
{
	HANDLE objects[2];
	DWORD count = 0;
	HANDLE bell = (read || write) ? bell_of(handle) : NULL;
	if (bell != NULL)
	{
		objects[count++] = bell;
	}
	if (waker != NULL && waker->event != NULL)
	{
		objects[count++] = waker->event;
	}
	if (count == 0)
	{
		Sleep((DWORD)timeoutMs);
		return false;
	}
	DWORD result = WaitForMultipleObjects(count, objects, FALSE, (DWORD)timeoutMs);
	return waker != NULL && waker->event != NULL && result == WAIT_OBJECT_0 + count - 1;
}

bool n_handshaking(void* handle)
{
	struct ntipc_listener* listener = as_listener(handle);
	return listener != NULL && listener->handshaking_len > 0;
}

static bool push_pending(struct ntipc_listener* listener, struct ntipc_pending p)
{
	if (listener->handshaking_len == listener->handshaking_cap)
	{
		size_t cap = listener->handshaking_cap == 0 ? 8 : listener->handshaking_cap * 2;
		struct ntipc_pending* next = (struct ntipc_pending*)realloc(listener->handshaking, cap * sizeof(*next));
		if (next == NULL)
		{
			return false;
		}
		listener->handshaking = next;
		listener->handshaking_cap = cap;
	}
	listener->handshaking[listener->handshaking_len++] = p;
	return true;
}

static void erase_pending(struct ntipc_listener* listener, size_t index)
{
	if (index + 1 < listener->handshaking_len)
	{
		memmove(listener->handshaking + index, listener->handshaking + index + 1, (listener->handshaking_len - index - 1) * sizeof(*listener->handshaking));
	}
	listener->handshaking_len--;
}

void* n_connect(const char* name, int timeoutMs, const volatile bool* cancel)
{
	n_set_last_error(NTIPC_ERROR_FAILED);
	char pipe_name[512];
	if (!make_pipe_name(name, pipe_name))
	{
		return NULL;
	}
	bool forever = timeoutMs <= 0;
	int64_t deadline = n_now_ms() + (forever ? 0 : timeoutMs);

	while (true)
	{
		if (cancel != NULL && *cancel)
		{
			return NULL;
		}

		HANDLE pipe = CreateFileA(
			pipe_name,
			GENERIC_READ | GENERIC_WRITE,
			0,
			NULL,
			OPEN_EXISTING,
			SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION,
			NULL);

		if (pipe != INVALID_HANDLE_VALUE)
		{
			if (!owned_by_process_user(pipe))
			{
				CloseHandle(pipe);
				n_set_last_error(NTIPC_ERROR_NOT_OWNED);
				return NULL;
			}
			DWORD mode = PIPE_READMODE_BYTE | PIPE_NOWAIT;
			SetNamedPipeHandleState(pipe, &mode, NULL, NULL);

			uint64_t id = n_new_connection_id();
			struct ntipc_connection* connection = make_connection(pipe, name, id, false);
			if (connection == NULL)
			{
				return NULL;
			}
			unsigned char hello[NTIPC_HELLO_SIZE];
			n_write_hello(hello, id);
			int sent = 0;
			while (sent < NTIPC_HELLO_SIZE)
			{
				int w = write_some_raw(pipe, hello + sent, NTIPC_HELLO_SIZE - sent);
				if (w < 0)
				{
					close_connection(connection);
					connection = NULL;
					break;
				}
				if (w > 0)
				{
					sent += w;
					continue;
				}
				Sleep(1);
			}
			if (connection == NULL)
			{
				return NULL;
			}
			char base[512];
			bell_base(name, base);
			char bell_name[600];
			snprintf(bell_name, sizeof(bell_name), "%s-a", base);
			HANDLE accept_bell = make_bell(bell_name);
			ring(accept_bell);
			close_bell(accept_bell);

			int64_t answer_by = deadline;
			int64_t least = n_now_ms() + NTIPC_CONNECT_WAIT_SLICE_MS;
			if (answer_by < least)
			{
				answer_by = least;
			}
			unsigned char answer[NTIPC_HELLO_SIZE];
			int got = 0;
			while (got < NTIPC_HELLO_SIZE)
			{
				int read = read_some_raw(pipe, answer + got, NTIPC_HELLO_SIZE - got);
				if (read < 0)
				{
					close_connection(connection);
					n_set_last_error(NTIPC_ERROR_FAILED);
					return NULL;
				}
				if (read > 0)
				{
					got += read;
					continue;
				}
				if (cancel != NULL && *cancel)
				{
					close_connection(connection);
					return NULL;
				}
				int64_t now = n_now_ms();
				int wait_ms = NTIPC_CONNECT_WAIT_SLICE_MS;
				if (!forever)
				{
					if (now >= answer_by)
					{
						close_connection(connection);
						n_set_last_error(NTIPC_ERROR_TIMEOUT);
						return NULL;
					}
					int left_ms = (int)(answer_by - now) + 1;
					if (left_ms < wait_ms)
					{
						wait_ms = left_ms;
					}
				}
				if (connection->mine != NULL)
				{
					WaitForSingleObject(connection->mine, (DWORD)wait_ms);
				}
				else
				{
					Sleep(1);
				}
			}
			uint64_t echoed = 0;
			if (!n_read_hello(answer, &echoed) || echoed != id)
			{
				close_connection(connection);
				n_set_last_error(NTIPC_ERROR_PROTOCOL);
				return NULL;
			}
			n_set_last_error(NTIPC_ERROR_NONE);
			return connection;
		}

		DWORD error = GetLastError();
		if (error != ERROR_PIPE_BUSY && error != ERROR_FILE_NOT_FOUND)
		{
			return NULL;
		}
		if (!n_another_try(forever, deadline))
		{
			n_set_last_error(NTIPC_ERROR_TIMEOUT);
			return NULL;
		}
		if (error == ERROR_PIPE_BUSY)
		{
			WaitNamedPipeA(pipe_name, NTIPC_CONNECT_WAIT_SLICE_MS);
		}
		else
		{
			Sleep(NTIPC_CONNECT_WAIT_SLICE_MS);
		}
	}
}

void* ntipc_listen(const char* name)
{
	n_set_last_error(NTIPC_ERROR_FAILED);
	char pipe_name[512];
	if (!make_pipe_name(name, pipe_name))
	{
		return NULL;
	}

	HANDLE pipe = create_instance(pipe_name, true);
	if (pipe == INVALID_HANDLE_VALUE)
	{
		DWORD error = GetLastError();
		n_set_last_error(error == ERROR_ACCESS_DENIED || error == ERROR_PIPE_BUSY ? NTIPC_ERROR_IN_USE : NTIPC_ERROR_FAILED);
		return NULL;
	}

	struct ntipc_listener* listener = (struct ntipc_listener*)calloc(1, sizeof(*listener));
	if (listener == NULL)
	{
		CloseHandle(pipe);
		n_set_last_error(NTIPC_ERROR_FAILED);
		return NULL;
	}
	listener->kind = NTIPC_KIND_LISTENER;
	snprintf(listener->name, sizeof(listener->name), "%s", name_or_empty(name));
	snprintf(listener->pipe_name, sizeof(listener->pipe_name), "%s", pipe_name);
	listener->pending = pipe;
	char base[512];
	bell_base(name, base);
	char bell_name[600];
	snprintf(bell_name, sizeof(bell_name), "%s-a", base);
	listener->accept_bell = make_bell(bell_name);
	n_set_last_error(NTIPC_ERROR_NONE);
	return listener;
}

void* ntipc_accept(void* handle)
{
	struct ntipc_listener* listener = as_listener(handle);
	if (listener == NULL)
	{
		n_set_last_error(NTIPC_ERROR_FAILED);
		return NULL;
	}
	n_set_last_error(NTIPC_ERROR_NONE);

	for (int i = 0; i < N_ACCEPTS_PER_CALL; i++)
	{
		if (is_invalid(listener->pending))
		{
			listener->pending = create_instance(listener->pipe_name, false);
			if (is_invalid(listener->pending))
			{
				break;
			}
		}
		BOOL connected = ConnectNamedPipe(listener->pending, NULL);
		DWORD error = connected ? ERROR_SUCCESS : GetLastError();
		if (!connected && error != ERROR_PIPE_CONNECTED && error != ERROR_NO_DATA)
		{
			break;
		}
		struct ntipc_pending pending;
		pending.pipe = listener->pending;
		pending.got = 0;
		pending.deadline = n_now_ms() + NTIPC_HELLO_TIMEOUT_MS;
		if (!push_pending(listener, pending))
		{
			CloseHandle(listener->pending);
			listener->pending = INVALID_HANDLE_VALUE;
			break;
		}
		listener->pending = create_instance(listener->pipe_name, false);
	}

	int64_t now = n_now_ms();
	for (size_t i = 0; i < listener->handshaking_len;)
	{
		struct ntipc_pending* pending = &listener->handshaking[i];
		int read = read_some_raw(pending->pipe, pending->hello + pending->got, NTIPC_HELLO_SIZE - pending->got);
		if (read > 0)
		{
			pending->got += read;
		}
		if (read < 0 || (pending->got < NTIPC_HELLO_SIZE && now >= pending->deadline))
		{
			CloseHandle(pending->pipe);
			erase_pending(listener, i);
			continue;
		}
		if (pending->got < NTIPC_HELLO_SIZE)
		{
			i++;
			continue;
		}

		HANDLE pipe = pending->pipe;
		uint64_t id = 0;
		bool spoken = n_read_hello(pending->hello, &id);
		erase_pending(listener, i);
		unsigned char answer[NTIPC_HELLO_SIZE];
		n_write_hello(answer, spoken ? id : 0);
		if (!spoken)
		{
			write_some_raw(pipe, answer, NTIPC_HELLO_SIZE);
			CloseHandle(pipe);
			continue;
		}
		struct ntipc_connection* connection = make_connection(pipe, listener->name, id, true);
		if (connection == NULL)
		{
			continue;
		}
		if (write_some_raw(pipe, answer, NTIPC_HELLO_SIZE) != NTIPC_HELLO_SIZE)
		{
			close_connection(connection);
			continue;
		}
		ring(connection->peer);
		return connection;
	}
	return NULL;
}

void ntipc_close(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection != NULL)
	{
		close_connection(connection);
		return;
	}
	struct ntipc_listener* listener = as_listener(handle);
	if (listener != NULL)
	{
		if (!is_invalid(listener->pending))
		{
			CloseHandle(listener->pending);
		}
		for (size_t i = 0; i < listener->handshaking_len; i++)
		{
			CloseHandle(listener->handshaking[i].pipe);
		}
		free(listener->handshaking);
		close_bell(listener->accept_bell);
		listener->kind = 0;
		free(listener);
	}
}

int ntipc_bytes_available(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL)
	{
		return -1;
	}
	DWORD bytes_available = 0;
	if (PeekNamedPipe(connection->pipe, NULL, 0, NULL, &bytes_available, NULL))
	{
		return (int)bytes_available;
	}
	DWORD error = GetLastError();
	if (error == ERROR_NO_DATA)
	{
		return 0;
	}
	return is_gone(error) ? -1 : 0;
}

int ntipc_read(void* handle, unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size <= 0)
	{
		return -1;
	}
	int total_read = 0;
	int64_t deadline = n_now_ms() + NTIPC_IO_TIMEOUT_MS;
	while (total_read < size)
	{
		DWORD bytes_read = 0;
		if (ReadFile(connection->pipe, buffer + total_read, (DWORD)(size - total_read), &bytes_read, NULL))
		{
			if (bytes_read > 0)
			{
				total_read += (int)bytes_read;
				continue;
			}
		}
		DWORD error = GetLastError();
		if (error == ERROR_MORE_DATA)
		{
			total_read += (int)bytes_read;
			continue;
		}
		if (error == ERROR_NO_DATA)
		{
			if (n_now_ms() >= deadline)
			{
				return -1;
			}
			Sleep(1);
			continue;
		}
		if (is_gone(error))
		{
			return -1;
		}
		if (n_now_ms() >= deadline)
		{
			return -1;
		}
		Sleep(1);
	}
	if (total_read >= N_PIPE_BUFFER_SIZE / 2)
	{
		ring(connection->peer);
	}
	return 0;
}

int ntipc_read_some(void* handle, unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size <= 0)
	{
		return -1;
	}
	int read = read_some_raw(connection->pipe, buffer, size);
	if (read >= N_PIPE_BUFFER_SIZE / 2)
	{
		ring(connection->peer);
	}
	return read;
}

int ntipc_write_some(void* handle, const unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size < 0)
	{
		return -1;
	}
	int written = write_some_raw(connection->pipe, buffer, size);
	if (written > 0)
	{
		ring(connection->peer);
	}
	return written;
}

bool ntipc_write(void* handle, const unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size <= 0)
	{
		return false;
	}
	int total_written = 0;
	int64_t deadline = n_now_ms() + NTIPC_IO_TIMEOUT_MS;
	while (total_written < size)
	{
		int written = ntipc_write_some(handle, buffer + total_written, size - total_written);
		if (written < 0)
		{
			return false;
		}
		total_written += written;
		if (total_written < size)
		{
			if (n_now_ms() >= deadline)
			{
				return false;
			}
			Sleep(1);
		}
	}
	return true;
}

bool ntipc_is_open(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL)
	{
		return false;
	}
	DWORD bytes_available = 0;
	if (PeekNamedPipe(connection->pipe, NULL, 0, NULL, &bytes_available, NULL))
	{
		return true;
	}
	DWORD error = GetLastError();
	return error == ERROR_NO_DATA || !is_gone(error);
}

void* ntipc_connect(const char* name, int timeoutMs)
{
	return n_connect(name, timeoutMs, NULL);
}

void ntipc_keep_name(void* handle)
{
	(void)handle;
}

int ntipc_descriptor_of(void* handle)
{
	HANDLE bell = bell_of(handle);
	return bell == NULL ? -1 : (int)(intptr_t)bell;
}

bool ntipc_wait_for_work(int descriptor, bool read, bool write, int timeoutMs)
{
	(void)read;
	(void)write;
	if (descriptor == -1)
	{
		Sleep((DWORD)timeoutMs);
		return false;
	}
	HANDLE bell = (HANDLE)(intptr_t)descriptor;
	WaitForSingleObject(bell, (DWORD)timeoutMs);
	return false;
}

bool ntipc_admits_others_for_test(void* handle)
{
	struct ntipc_listener* listener = as_listener(handle);
	const struct process_user* user = process_user_get();
	if (listener == NULL || is_invalid(listener->pending) || !user->valid)
	{
		return true;
	}
	HANDLE pipe = listener->pending;
	if (!owned_by_process_user(pipe))
	{
		return true;
	}
	PACL dacl = NULL;
	PSECURITY_DESCRIPTOR descriptor = NULL;
	if (GetSecurityInfo(pipe, SE_KERNEL_OBJECT, DACL_SECURITY_INFORMATION, NULL, NULL, &dacl, NULL, &descriptor) != ERROR_SUCCESS)
	{
		return true;
	}
	bool others = dacl == NULL;
	BYTE system_sid[SECURITY_MAX_SID_SIZE];
	DWORD system_size = sizeof(system_sid);
	CreateWellKnownSid(WinLocalSystemSid, NULL, system_sid, &system_size);
	for (DWORD i = 0; !others && i < dacl->AceCount; i++)
	{
		void* ace = NULL;
		if (!GetAce(dacl, i, &ace))
		{
			others = true;
			break;
		}
		ACE_HEADER* header = (ACE_HEADER*)ace;
		if (header->AceType != ACCESS_ALLOWED_ACE_TYPE)
		{
			continue;
		}
		PSID sid = (PSID)&((ACCESS_ALLOWED_ACE*)ace)->SidStart;
		if (!EqualSid(sid, (PSID)user->sid) && !EqualSid(sid, system_sid))
		{
			others = true;
		}
	}
	LocalFree(descriptor);
	return others;
}

void ntipc_set_socket_buffer_for_test(int bytes)
{
	(void)bytes;
}

#endif
