#ifndef _REPROC_P_H_
#define _REPROC_P_H_

#include <stdint.h>


#if defined(_WIN32)
typedef void *process_type; // `HANDLE`
#else
typedef int process_type; // fd
#endif

#ifdef _WIN64
typedef uint64_t pipe_type; // `SOCKET`
#elif _WIN32
typedef uint32_t pipe_type; // `SOCKET`
#else
typedef int pipe_type; // fd
#endif

enum {
  STATUS_NOT_STARTED = -1,
  STATUS_IN_PROGRESS = -2,
  STATUS_IN_CHILD = -3,
};

#include <reproc/reproc.h>

struct reproc_t_emu {
  process_type handle;

  struct {
    pipe_type in;
    pipe_type out;
    pipe_type err;
    pipe_type exit_;
  } pipe;

  int status;
  struct reproc_stop_actions stop;
  int64_t deadline;
  bool nonblocking;

  struct {
    pipe_type out;
    pipe_type err;
  } child;
};


#endif _REPROC_P_H_
