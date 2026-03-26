#ifndef RUSH_SERIALIZE_REDIS_H
#define RUSH_SERIALIZE_REDIS_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Connections.h>
#include <hiredis.h>
#include <string.h>
#include <stdlib.h>

#define RUSH_INIT_BUFSIZE 4096
#define RUSH_SERIAL_VER 3
#define RUSH_SERIAL_THR 67108864

typedef struct rush_buf_s {
  unsigned char *buf;
  size_t len;
  size_t cur;
} rush_buf;

SEXP rush_connect(SEXP host, SEXP port);
SEXP rush_write_hashes(SEXP ptr, SEXP keys, SEXP fields, SEXP values);
SEXP rush_read_hashes(SEXP ptr, SEXP keys, SEXP fields);

#endif
