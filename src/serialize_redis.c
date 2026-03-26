// rush - Fast serialize/unserialize directly to/from Redis
// Serialization callbacks adapted from nanonext (MIT license, Charlie Gao)

#include "serialize_redis.h"

// --- Serialization buffer callbacks (adapted from nanonext) ---

static void rush_write_bytes(R_outpstream_t stream, void *src, int len) {
  rush_buf *buf = (rush_buf *) stream->data;
  size_t req = buf->cur + (size_t) len;
  if (req > buf->len) {
    if (req > R_XLEN_T_MAX) {
      if (buf->len) free(buf->buf);
      Rf_error("serialization exceeds max length");
    }
    do {
      buf->len += buf->len > RUSH_SERIAL_THR ? RUSH_SERIAL_THR : buf->len;
    } while (buf->len < req);
    unsigned char *nbuf = realloc(buf->buf, buf->len);
    if (nbuf == NULL) {
      free(buf->buf);
      Rf_error("memory allocation failed");
    }
    buf->buf = nbuf;
  }
  memcpy(buf->buf + buf->cur, src, len);
  buf->cur += len;
}

static void rush_read_bytes(R_inpstream_t stream, void *dst, int len) {
  rush_buf *buf = (rush_buf *) stream->data;
  if (buf->cur + len > buf->len) Rf_error("unserialization error");
  memcpy(dst, buf->buf + buf->cur, len);
  buf->cur += len;
}

static int rush_read_char(R_inpstream_t stream) {
  rush_buf *buf = (rush_buf *) stream->data;
  if (buf->cur >= buf->len) Rf_error("unserialization error");
  return buf->buf[buf->cur++];
}

// --- Serialize an R object into a rush_buf ---

static void rush_serialize(rush_buf *buf, SEXP object) {
  buf->buf = malloc(RUSH_INIT_BUFSIZE);
  if (buf->buf == NULL) Rf_error("memory allocation failed");
  buf->len = RUSH_INIT_BUFSIZE;
  buf->cur = 0;

  struct R_outpstream_st output_stream;
  R_InitOutPStream(
    &output_stream,
    (R_pstream_data_t) buf,
    R_pstream_binary_format,
    RUSH_SERIAL_VER,
    NULL,
    rush_write_bytes,
    NULL,
    R_NilValue
  );
  R_Serialize(object, &output_stream);
}

// --- Unserialize from a raw buffer ---

static SEXP rush_unserialize(unsigned char *buf, size_t sz) {
  rush_buf nbuf = {.buf = buf, .len = sz, .cur = 0};
  struct R_inpstream_st input_stream;
  R_InitInPStream(
    &input_stream,
    (R_pstream_data_t) &nbuf,
    R_pstream_any_format,
    rush_read_char,
    rush_read_bytes,
    NULL,
    R_NilValue
  );
  return R_Unserialize(&input_stream);
}

// --- Connection management ---
// Rush manages its own redisContext, separate from redux.

static void rush_context_finalize(SEXP extPtr) {
  redisContext *ctx = (redisContext *) R_ExternalPtrAddr(extPtr);
  if (ctx) {
    redisFree(ctx);
    R_ClearExternalPtr(extPtr);
  }
}

SEXP rush_connect(SEXP host, SEXP port) {
  const char *h = CHAR(STRING_ELT(host, 0));
  int p = INTEGER(port)[0];

  redisContext *ctx = redisConnect(h, p);
  if (ctx == NULL)
    Rf_error("failed to create Redis context");
  if (ctx->err) {
    const char *errstr = ctx->errstr;
    redisFree(ctx);
    Rf_error("Redis connection error: %s", errstr);
  }

  SEXP extPtr = PROTECT(R_MakeExternalPtr(ctx, R_NilValue, R_NilValue));
  R_RegisterCFinalizer(extPtr, rush_context_finalize);
  UNPROTECT(1);
  return extPtr;
}

// --- Helper: get redisContext from our own external pointer ---

static redisContext *rush_get_context(SEXP ptr) {
  if (TYPEOF(ptr) != EXTPTRSXP)
    Rf_error("expected an external pointer");
  redisContext *ctx = (redisContext *) R_ExternalPtrAddr(ptr);
  if (ctx == NULL)
    Rf_error("Redis context is not connected");
  if (ctx->err)
    Rf_error("Redis connection error: %s", ctx->errstr);
  return ctx;
}

// --- Write hashes: serialize R objects and HSET directly to Redis ---

SEXP rush_write_hashes(SEXP ptr, SEXP keys, SEXP fields, SEXP values) {
  if (TYPEOF(ptr) != EXTPTRSXP) Rf_error("ptr must be an external pointer");
  if (TYPEOF(keys) != STRSXP) Rf_error("keys must be a character vector");
  if (TYPEOF(fields) != STRSXP) Rf_error("fields must be a character vector");
  if (TYPEOF(values) != VECSXP) Rf_error("values must be a list");

  redisContext *ctx = rush_get_context(ptr);
  int n_hashes = LENGTH(keys);
  int n_fields = LENGTH(fields);

  // Pipeline: append all HSET commands
  for (int i = 0; i < n_hashes; i++) {
    int argc = 2 + 2 * n_fields;
    const char **argv = (const char **) R_alloc(argc, sizeof(const char *));
    size_t *argvlen = (size_t *) R_alloc(argc, sizeof(size_t));

    // Serialize all field values into buffers for this hash
    rush_buf *bufs = (rush_buf *) R_alloc(n_fields, sizeof(rush_buf));
    for (int j = 0; j < n_fields; j++) {
      SEXP field_values = VECTOR_ELT(values, j);
      SEXP obj = VECTOR_ELT(field_values, i);
      rush_serialize(&bufs[j], obj);
    }

    // Build argv
    argv[0] = "HSET";
    argvlen[0] = 4;
    argv[1] = CHAR(STRING_ELT(keys, i));
    argvlen[1] = strlen(argv[1]);

    for (int j = 0; j < n_fields; j++) {
      argv[2 + 2 * j] = CHAR(STRING_ELT(fields, j));
      argvlen[2 + 2 * j] = strlen(argv[2 + 2 * j]);
      argv[2 + 2 * j + 1] = (const char *) bufs[j].buf;
      argvlen[2 + 2 * j + 1] = bufs[j].cur;
    }

    int status = redisAppendCommandArgv(ctx, argc, argv, argvlen);

    // Free serialization buffers
    for (int j = 0; j < n_fields; j++) {
      free(bufs[j].buf);
    }

    if (status != REDIS_OK)
      Rf_error("Redis append error: %s", ctx->errstr);
  }

  // Collect replies
  for (int i = 0; i < n_hashes; i++) {
    redisReply *reply = NULL;
    redisGetReply(ctx, (void **) &reply);
    if (reply == NULL) {
      Rf_error("failure communicating with Redis");
    }
    if (reply->type == REDIS_REPLY_ERROR) {
      char *msg = R_alloc(reply->len + 1, 1);
      memcpy(msg, reply->str, reply->len);
      msg[reply->len] = '\0';
      freeReplyObject(reply);
      Rf_error("Redis error: %s", msg);
    }
    freeReplyObject(reply);
  }

  return R_NilValue;
}

// --- Read hashes: HMGET from Redis and unserialize directly ---

SEXP rush_read_hashes(SEXP ptr, SEXP keys, SEXP fields) {
  redisContext *ctx = rush_get_context(ptr);
  int n_hashes = LENGTH(keys);
  int n_fields = LENGTH(fields);

  // Pipeline HMGET commands
  for (int i = 0; i < n_hashes; i++) {
    int argc = 2 + n_fields;
    const char **argv = (const char **) R_alloc(argc, sizeof(const char *));
    size_t *argvlen = (size_t *) R_alloc(argc, sizeof(size_t));

    argv[0] = "HMGET";
    argvlen[0] = 5;
    argv[1] = CHAR(STRING_ELT(keys, i));
    argvlen[1] = strlen(argv[1]);
    for (int j = 0; j < n_fields; j++) {
      argv[2 + j] = CHAR(STRING_ELT(fields, j));
      argvlen[2 + j] = strlen(argv[2 + j]);
    }

    redisAppendCommandArgv(ctx, argc, argv, argvlen);
  }

  // Collect replies and unserialize
  SEXP result = PROTECT(Rf_allocVector(VECSXP, n_hashes));
  for (int i = 0; i < n_hashes; i++) {
    redisReply *reply = NULL;
    redisGetReply(ctx, (void **) &reply);
    if (reply == NULL) {
      UNPROTECT(1);
      Rf_error("failure communicating with Redis");
    }
    if (reply->type == REDIS_REPLY_ERROR) {
      char *msg = R_alloc(reply->len + 1, 1);
      memcpy(msg, reply->str, reply->len);
      msg[reply->len] = '\0';
      freeReplyObject(reply);
      UNPROTECT(1);
      Rf_error("Redis error: %s", msg);
    }

    SEXP hash = PROTECT(Rf_allocVector(VECSXP, n_fields));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, n_fields));
    for (int j = 0; j < n_fields; j++) {
      SET_STRING_ELT(names, j, STRING_ELT(fields, j));
      if (reply->type == REDIS_REPLY_ARRAY && j < (int) reply->elements) {
        redisReply *elem = reply->element[j];
        if (elem->type == REDIS_REPLY_STRING && elem->len > 0) {
          SEXP obj = PROTECT(rush_unserialize((unsigned char *) elem->str, elem->len));
          SET_VECTOR_ELT(hash, j, obj);
          UNPROTECT(1);
        } else {
          SET_VECTOR_ELT(hash, j, R_NilValue);
        }
      } else {
        SET_VECTOR_ELT(hash, j, R_NilValue);
      }
    }
    Rf_setAttrib(hash, R_NamesSymbol, names);
    SET_VECTOR_ELT(result, i, hash);
    UNPROTECT(2);
    freeReplyObject(reply);
  }

  UNPROTECT(1);
  return result;
}
