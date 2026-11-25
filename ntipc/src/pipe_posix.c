#if !defined(_WIN32)

#include "internal.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

#define N_PIPE_LISTEN_BACKLOG 16
// The most clients one accept takes from the socket before it looks at
// their hellos.
#define N_ACCEPTS_PER_CALL 16

// A send to a peer that has gone raises SIGPIPE, whose default action
// ends the process, unless the send says not to. macOS has no flag for
// it and sets SO_NOSIGPIPE on the socket instead.
#if defined(MSG_NOSIGNAL)
#define N_SEND_FLAGS MSG_NOSIGNAL
#else
#define N_SEND_FLAGS 0
#endif

// How often, at most, a listener's lock file has its times brought up
// to date: often enough that a cleaner of old files in /tmp never finds
// a listener's old.
#define N_LOCK_FILE_REFRESH_SECONDS 3600

struct ntipc_connection
{
	uint32_t kind;
	int fd;
};

// A client the listener's socket has taken that has not said hello yet.
struct ntipc_pending
{
	int fd;
	unsigned char hello[NTIPC_HELLO_SIZE];
	int got;
	int64_t deadline;
};

struct ntipc_listener
{
	uint32_t kind;
	int listen_fd;
	// Held for as long as this listens on its name: see ntipc_listen.
	int lock_fd;
	char path[108];
	// When the lock file's times were last brought up to date.
	int64_t lock_refreshed;
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

static struct ntipc_connection* make_connection(int fd)
{
	struct ntipc_connection* connection = (struct ntipc_connection*)calloc(1, sizeof(*connection));
	if (connection == NULL)
	{
		close(fd);
		return NULL;
	}
	connection->kind = NTIPC_KIND_CONNECTION;
	connection->fd = fd;
	return connection;
}

static void set_non_blocking(int fd)
{
	int flags = fcntl(fd, F_GETFL, 0);
	if (flags != -1)
	{
		fcntl(fd, F_SETFL, flags | O_NONBLOCK);
	}
}

static int test_socket_buffer = 0;

// A connected socket, and one about to connect, never makes its caller
// wait: each read, write and connect takes what the socket can do now,
// and what has to wait does so in poll(), with a deadline.
static void configure_connected_socket(int fd)
{
	set_non_blocking(fd);
	fcntl(fd, F_SETFD, FD_CLOEXEC);
#if defined(__APPLE__)
	int option_value = 1;
	setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &option_value, sizeof(option_value));
#endif
	int buffer = test_socket_buffer;
	if (buffer > 0)
	{
		setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &buffer, sizeof(buffer));
		setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &buffer, sizeof(buffer));
	}
}

// Waits for `fd` to be ready for `events` until `deadline`: whether it
// became so.
static bool wait_ready(int fd, short events, int64_t deadline)
{
	while (true)
	{
		int64_t now = n_now_ms();
		if (now >= deadline)
		{
			return false;
		}
		int left_ms = (int)(deadline - now) + 1;
		struct pollfd entry;
		entry.fd = fd;
		entry.events = events;
		entry.revents = 0;
		int ready = poll(&entry, 1, left_ms);
		if (ready > 0)
		{
			return true;
		}
		if (ready < 0 && errno != EINTR)
		{
			return false;
		}
	}
}

static void user_directory(char out[64])
{
	snprintf(out, 64, "/tmp/native-ipc-%lu", (unsigned long)geteuid());
}

// Whether `directory` is there and this user's own: 1 if so; 0 if nothing
// is there (made first when `make`); -1 if something else is, or it cannot
// be looked at, the last error saying which.
static int check_user_directory(const char* directory, bool make)
{
	struct stat info;
	if (lstat(directory, &info) != 0)
	{
		if (errno != ENOENT)
		{
			n_set_last_error(NTIPC_ERROR_FAILED);
			return -1;
		}
		if (!make)
		{
			return 0;
		}
		if ((mkdir(directory, 0700) != 0 && errno != EEXIST) || lstat(directory, &info) != 0)
		{
			n_set_last_error(NTIPC_ERROR_FAILED);
			return -1;
		}
	}
	if (!S_ISDIR(info.st_mode) || info.st_uid != geteuid() || (info.st_mode & 077) != 0)
	{
		n_set_last_error(NTIPC_ERROR_NOT_OWNED);
		return -1;
	}
	return 1;
}

static void sanitize_pipe_name(const char* name, char out[64])
{
	const size_t budget = 48;
	const char* source = (name == NULL || name[0] == '\0') ? "default" : name;
	char sanitized[256];
	bool changed = false;
	size_t n = 0;

	for (const char* p = source; *p != '\0' && n < sizeof(sanitized) - 1; p++)
	{
		char c = *p;
		if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_')
		{
			sanitized[n++] = c;
		}
		else
		{
			sanitized[n++] = '_';
			changed = true;
		}
	}
	sanitized[n] = '\0';

	if (!changed && n <= budget)
	{
		snprintf(out, 64, "%.*s", (int)n, sanitized);
		return;
	}

	const size_t keep = budget - 17;
	size_t take = n < keep ? n : keep;
	char hex[17];
	n_hex64(n_hash_name(source), hex);
	snprintf(out, 64, "%.*s_%s", (int)take, sanitized, hex);
}

static void make_pipe_name(const char* directory, const char* name, char out[128])
{
	char sane[64];
	sanitize_pipe_name(name, sane);
	snprintf(out, 128, "%s/%s", directory, sane);
}

// An exclusive lock on `path`.lock, taken without waiting: the descriptor
// holding it, or -1 when another listener has it.
static int lock_name(const char* path)
{
	char lock_path[120];
	snprintf(lock_path, sizeof(lock_path), "%s.lock", path);
	for (int attempt = 0; attempt < 8; attempt++)
	{
		int fd = open(lock_path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK, 0600);
		if (fd < 0)
		{
			n_set_last_error(NTIPC_ERROR_FAILED);
			return -1;
		}
		struct stat held;
		if (fstat(fd, &held) != 0 || !S_ISREG(held.st_mode) || held.st_uid != geteuid())
		{
			close(fd);
			n_set_last_error(NTIPC_ERROR_NOT_OWNED);
			return -1;
		}
		if (flock(fd, LOCK_EX | LOCK_NB) != 0)
		{
			close(fd);
			n_set_last_error(errno == EWOULDBLOCK ? NTIPC_ERROR_IN_USE : NTIPC_ERROR_FAILED);
			return -1;
		}
		struct stat current;
		if (lstat(lock_path, &current) == 0 && held.st_ino == current.st_ino && held.st_dev == current.st_dev)
		{
			futimens(fd, NULL);
			return fd;
		}
		close(fd);
	}
	n_set_last_error(NTIPC_ERROR_FAILED);
	return -1;
}

// Whether what is at `path` may be connected to: 1 if a socket of this
// user's is there, 0 if nothing is, -1 if anything else is.
static int check_socket_path(const char* path)
{
	struct stat info;
	if (lstat(path, &info) != 0)
	{
		if (errno == ENOENT)
		{
			return 0;
		}
		n_set_last_error(NTIPC_ERROR_FAILED);
		return -1;
	}
	if (!S_ISSOCK(info.st_mode) || info.st_uid != geteuid())
	{
		n_set_last_error(NTIPC_ERROR_NOT_OWNED);
		return -1;
	}
	return 1;
}

// As much as `fd` holds, up to `size`, without waiting: the bytes read,
// 0 for none, -1 when the connection is gone.
static int read_some_raw(int fd, unsigned char* buffer, int size)
{
	while (true)
	{
		ssize_t bytes_read = recv(fd, (char*)buffer, (size_t)size, 0);
		if (bytes_read > 0)
		{
			return (int)bytes_read;
		}
		if (bytes_read == 0)
		{
			return -1;
		}
		if (errno == EINTR)
		{
			continue;
		}
		return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -1;
	}
}

// As much of `buffer` as `fd` takes now, without waiting: the bytes
// written, 0 when it is full, -1 when the connection is gone.
static int write_some_raw(int fd, const unsigned char* buffer, int size)
{
	int bytes_written = 0;
	while (bytes_written < size)
	{
		ssize_t send_result = send(fd, (const char*)buffer + bytes_written, (size_t)(size - bytes_written), MSG_DONTWAIT | N_SEND_FLAGS);
		if (send_result > 0)
		{
			bytes_written += (int)send_result;
			continue;
		}
		if (send_result < 0 && errno == EINTR)
		{
			continue;
		}
		if (send_result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == ENOBUFS))
		{
			break;
		}
		return bytes_written > 0 ? bytes_written : -1;
	}
	return bytes_written;
}

static int descriptor_of(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection != NULL)
	{
		return connection->fd;
	}
	struct ntipc_listener* listener = as_listener(handle);
	if (listener != NULL)
	{
		return listener->listen_fd;
	}
	return -1;
}

void n_waker_init(struct n_waker* waker)
{
	waker->fds[0] = -1;
	waker->fds[1] = -1;
	if (pipe(waker->fds) == 0)
	{
		for (int i = 0; i < 2; i++)
		{
			set_non_blocking(waker->fds[i]);
			fcntl(waker->fds[i], F_SETFD, FD_CLOEXEC);
		}
	}
	else
	{
		waker->fds[0] = -1;
		waker->fds[1] = -1;
	}
}

void n_waker_fini(struct n_waker* waker)
{
	for (int i = 0; i < 2; i++)
	{
		if (waker->fds[i] >= 0)
		{
			close(waker->fds[i]);
		}
	}
}

void n_waker_signal(struct n_waker* waker)
{
	if (waker->fds[1] >= 0)
	{
		unsigned char byte = 1;
		ssize_t ignored = write(waker->fds[1], &byte, 1);
		(void)ignored;
	}
}

void n_waker_drain(struct n_waker* waker)
{
	if (waker->fds[0] >= 0)
	{
		unsigned char buffer[64];
		while (read(waker->fds[0], buffer, sizeof(buffer)) > 0)
		{
		}
	}
}

bool n_wait_any(void* handle, bool read, bool write, struct n_waker* waker, int timeoutMs)
{
	struct pollfd entries[2];
	int count = 0;
	int fd = (read || write) ? descriptor_of(handle) : -1;
	if (fd >= 0)
	{
		entries[count].fd = fd;
		entries[count].events = (short)((read ? POLLIN : 0) | (write ? POLLOUT : 0));
		entries[count].revents = 0;
		count++;
	}
	int waker_index = -1;
	if (waker != NULL && waker->fds[0] >= 0)
	{
		waker_index = count;
		entries[count].fd = waker->fds[0];
		entries[count].events = POLLIN;
		entries[count].revents = 0;
		count++;
	}
	int ready = poll(count > 0 ? entries : NULL, (nfds_t)count, timeoutMs);
	if (ready > 0 && waker_index >= 0 && (entries[waker_index].revents & POLLIN) != 0)
	{
		n_waker_drain(waker);
		return true;
	}
	return false;
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
	char directory[64];
	user_directory(directory);
	char pipe_name[128];
	make_pipe_name(directory, name, pipe_name);
	if (strlen(pipe_name) >= sizeof(((struct sockaddr_un*)0)->sun_path))
	{
		return NULL;
	}

	struct sockaddr_un address;
	memset(&address, 0, sizeof(address));
	address.sun_family = AF_UNIX;
	memcpy(address.sun_path, pipe_name, strlen(pipe_name) + 1);

	bool forever = timeoutMs <= 0;
	int64_t deadline = n_now_ms() + (forever ? 0 : timeoutMs);
	while (true)
	{
		if (cancel != NULL && *cancel)
		{
			return NULL;
		}

		int present = check_user_directory(directory, false);
		if (present > 0)
		{
			present = check_socket_path(pipe_name);
		}
		if (present < 0)
		{
			return NULL;
		}

		int error = ENOENT;
		int fd = -1;
		if (present > 0)
		{
			fd = socket(AF_UNIX, SOCK_STREAM, 0);
			if (fd < 0)
			{
				return NULL;
			}

			configure_connected_socket(fd);
			int result = connect(fd, (struct sockaddr*)&address, sizeof(address));
			error = result == 0 ? 0 : errno;
			if (result != 0 && error == EINPROGRESS)
			{
				int64_t slice = n_now_ms() + NTIPC_CONNECT_WAIT_SLICE_MS;
				socklen_t length = sizeof(error);
				if (!wait_ready(fd, POLLOUT, slice) || getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) != 0)
				{
					error = EAGAIN;
				}
			}
			if (error != 0)
			{
				close(fd);
				fd = -1;
			}
		}

		if (fd >= 0)
		{
			uint64_t id = n_new_connection_id();
			unsigned char hello[NTIPC_HELLO_SIZE];
			n_write_hello(hello, id);
			int sent = 0;
			while (sent < NTIPC_HELLO_SIZE)
			{
				int w = write_some_raw(fd, hello + sent, NTIPC_HELLO_SIZE - sent);
				if (w < 0)
				{
					close(fd);
					fd = -1;
					break;
				}
				if (w > 0)
				{
					sent += w;
					continue;
				}
				int64_t slice = n_now_ms() + NTIPC_CONNECT_WAIT_SLICE_MS;
				if (!wait_ready(fd, POLLOUT, slice))
				{
					close(fd);
					fd = -1;
					break;
				}
			}
			if (fd < 0)
			{
				return NULL;
			}

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
				int read = read_some_raw(fd, answer + got, NTIPC_HELLO_SIZE - got);
				if (read < 0)
				{
					close(fd);
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
					close(fd);
					return NULL;
				}
				int64_t now = n_now_ms();
				if (!forever && now >= answer_by)
				{
					close(fd);
					n_set_last_error(NTIPC_ERROR_TIMEOUT);
					return NULL;
				}
				int64_t slice = now + NTIPC_CONNECT_WAIT_SLICE_MS;
				wait_ready(fd, POLLIN, (!forever && answer_by < slice) ? answer_by : slice);
			}
			uint64_t echoed = 0;
			if (!n_read_hello(answer, &echoed) || echoed != id)
			{
				close(fd);
				n_set_last_error(NTIPC_ERROR_PROTOCOL);
				return NULL;
			}
			struct ntipc_connection* connection = make_connection(fd);
			if (connection != NULL)
			{
				n_set_last_error(NTIPC_ERROR_NONE);
			}
			return connection;
		}

		if (error != ENOENT && error != ECONNREFUSED && error != EAGAIN && error != EWOULDBLOCK)
		{
			return NULL;
		}
		if (!n_another_try(forever, deadline))
		{
			n_set_last_error(NTIPC_ERROR_TIMEOUT);
			return NULL;
		}

		struct pollfd none = {0};
		poll(&none, 0, NTIPC_CONNECT_WAIT_SLICE_MS);
	}
}

void* ntipc_listen(const char* name)
{
	n_set_last_error(NTIPC_ERROR_FAILED);
	char directory[64];
	user_directory(directory);
	if (check_user_directory(directory, true) < 0)
	{
		return NULL;
	}
	char pipe_name[128];
	make_pipe_name(directory, name, pipe_name);
	if (strlen(pipe_name) + 5 >= sizeof(((struct sockaddr_un*)0)->sun_path))
	{
		return NULL;
	}

	int lock_fd = lock_name(pipe_name);
	if (lock_fd < 0)
	{
		return NULL;
	}

	int listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
	if (listen_fd < 0)
	{
		close(lock_fd);
		n_set_last_error(NTIPC_ERROR_FAILED);
		return NULL;
	}

	struct sockaddr_un address;
	memset(&address, 0, sizeof(address));
	address.sun_family = AF_UNIX;
	memcpy(address.sun_path, pipe_name, strlen(pipe_name) + 1);

	unlink(pipe_name);
	if (bind(listen_fd, (struct sockaddr*)&address, sizeof(address)) < 0 || listen(listen_fd, N_PIPE_LISTEN_BACKLOG) < 0)
	{
		close(listen_fd);
		close(lock_fd);
		n_set_last_error(NTIPC_ERROR_FAILED);
		return NULL;
	}

	struct ntipc_listener* listener = (struct ntipc_listener*)calloc(1, sizeof(*listener));
	if (listener == NULL)
	{
		close(listen_fd);
		close(lock_fd);
		n_set_last_error(NTIPC_ERROR_FAILED);
		return NULL;
	}
	set_non_blocking(listen_fd);
	fcntl(listen_fd, F_SETFD, FD_CLOEXEC);
	listener->kind = NTIPC_KIND_LISTENER;
	listener->listen_fd = listen_fd;
	listener->lock_fd = lock_fd;
	snprintf(listener->path, sizeof(listener->path), "%.*s", (int)(sizeof(listener->path) - 1), pipe_name);
	listener->lock_refreshed = n_now_ms();
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
		int fd = accept(listener->listen_fd, NULL, NULL);
		if (fd < 0)
		{
			break;
		}
		configure_connected_socket(fd);
		struct ntipc_pending pending;
		pending.fd = fd;
		pending.got = 0;
		pending.deadline = n_now_ms() + NTIPC_HELLO_TIMEOUT_MS;
		if (!push_pending(listener, pending))
		{
			close(fd);
			break;
		}
	}

	int64_t now = n_now_ms();
	for (size_t i = 0; i < listener->handshaking_len;)
	{
		struct ntipc_pending* pending = &listener->handshaking[i];
		int read = read_some_raw(pending->fd, pending->hello + pending->got, NTIPC_HELLO_SIZE - pending->got);
		if (read > 0)
		{
			pending->got += read;
		}
		if (read < 0 || (pending->got < NTIPC_HELLO_SIZE && now >= pending->deadline))
		{
			close(pending->fd);
			erase_pending(listener, i);
			continue;
		}
		if (pending->got < NTIPC_HELLO_SIZE)
		{
			i++;
			continue;
		}

		int fd = pending->fd;
		uint64_t id = 0;
		bool spoken = n_read_hello(pending->hello, &id);
		erase_pending(listener, i);
		unsigned char answer[NTIPC_HELLO_SIZE];
		n_write_hello(answer, spoken ? id : 0);
		bool answered = write_some_raw(fd, answer, NTIPC_HELLO_SIZE) == NTIPC_HELLO_SIZE;
		if (!spoken || !answered)
		{
			close(fd);
			continue;
		}
		struct ntipc_connection* connection = make_connection(fd);
		if (connection != NULL)
		{
			return connection;
		}
	}
	return NULL;
}

void ntipc_close(void* handle)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection != NULL)
	{
		close(connection->fd);
		connection->kind = 0;
		free(connection);
		return;
	}
	struct ntipc_listener* listener = as_listener(handle);
	if (listener != NULL)
	{
		for (size_t i = 0; i < listener->handshaking_len; i++)
		{
			close(listener->handshaking[i].fd);
		}
		free(listener->handshaking);
		if (listener->listen_fd >= 0)
		{
			close(listener->listen_fd);
			unlink(listener->path);
		}
		if (listener->lock_fd >= 0)
		{
			char lock_path[120];
			snprintf(lock_path, sizeof(lock_path), "%s.lock", listener->path);
			unlink(lock_path);
			close(listener->lock_fd);
		}
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
	int bytes_available = 0;
	if (ioctl(connection->fd, FIONREAD, &bytes_available) == 0)
	{
		return bytes_available;
	}
	if (errno == EBADF || errno == ENOTCONN || errno == ECONNRESET)
	{
		return -1;
	}
	return 0;
}

int ntipc_read(void* handle, unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size <= 0)
	{
		return -1;
	}
	int fd = connection->fd;
	int64_t deadline = n_now_ms() + NTIPC_IO_TIMEOUT_MS;
	int bytes_read_total = 0;
	while (bytes_read_total < size)
	{
		ssize_t bytes_read = recv(fd, (char*)buffer + bytes_read_total, (size_t)(size - bytes_read_total), 0);
		if (bytes_read > 0)
		{
			bytes_read_total += (int)bytes_read;
			continue;
		}
		if (bytes_read == 0)
		{
			return -1;
		}
		if (errno == EINTR)
		{
			continue;
		}
		if (errno == EAGAIN || errno == EWOULDBLOCK)
		{
			if (wait_ready(fd, POLLIN, deadline))
			{
				continue;
			}
		}
		return -1;
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
	return read_some_raw(connection->fd, buffer, size);
}

int ntipc_write_some(void* handle, const unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size < 0)
	{
		return -1;
	}
	return write_some_raw(connection->fd, buffer, size);
}

bool ntipc_write(void* handle, const unsigned char* buffer, int size)
{
	struct ntipc_connection* connection = as_connection(handle);
	if (connection == NULL || buffer == NULL || size <= 0)
	{
		return false;
	}
	int fd = connection->fd;
	int64_t deadline = n_now_ms() + NTIPC_IO_TIMEOUT_MS;
	int bytes_written = 0;
	while (bytes_written < size)
	{
		ssize_t send_result = send(fd, (const char*)buffer + bytes_written, (size_t)(size - bytes_written), N_SEND_FLAGS);
		if (send_result > 0)
		{
			bytes_written += (int)send_result;
			continue;
		}
		if (send_result == 0 || errno == EPIPE)
		{
			return false;
		}
		if (errno == EINTR)
		{
			continue;
		}
		if ((errno == EAGAIN || errno == EWOULDBLOCK || errno == ENOBUFS) && wait_ready(fd, POLLOUT, deadline))
		{
			continue;
		}
		return false;
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
	char probe;
	ssize_t result = recv(connection->fd, &probe, 1, MSG_PEEK | MSG_DONTWAIT);
	if (result > 0)
	{
		return true;
	}
	if (result == 0)
	{
		return false;
	}
	return errno == EAGAIN || errno == EWOULDBLOCK;
}

void* ntipc_connect(const char* name, int timeoutMs)
{
	return n_connect(name, timeoutMs, NULL);
}

void ntipc_keep_name(void* handle)
{
	struct ntipc_listener* listener = as_listener(handle);
	if (listener == NULL || listener->lock_fd < 0)
	{
		return;
	}
	int64_t now = n_now_ms();
	if (now - listener->lock_refreshed >= (int64_t)N_LOCK_FILE_REFRESH_SECONDS * 1000)
	{
		futimens(listener->lock_fd, NULL);
		listener->lock_refreshed = now;
	}
}

int ntipc_descriptor_of(void* handle)
{
	return descriptor_of(handle);
}

bool ntipc_wait_for_work(int descriptor, bool read, bool write, int timeoutMs)
{
	if (descriptor < 0 || (!read && !write))
	{
		poll(NULL, 0, timeoutMs);
		return false;
	}
	struct pollfd entry;
	entry.fd = descriptor;
	entry.events = (short)((read ? POLLIN : 0) | (write ? POLLOUT : 0));
	entry.revents = 0;
	return poll(&entry, 1, timeoutMs) > 0;
}

bool ntipc_admits_others_for_test(void* handle)
{
	(void)handle;
	return false;
}

void ntipc_set_socket_buffer_for_test(int bytes)
{
	test_socket_buffer = bytes;
}

#endif
