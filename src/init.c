#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include "serialize_redis.h"

static const R_CallMethodDef CallEntries[] = {
  {"c_rush_connect",      (DL_FUNC) &rush_connect,      2},
  {"c_rush_write_hashes", (DL_FUNC) &rush_write_hashes, 4},
  {"c_rush_read_hashes",  (DL_FUNC) &rush_read_hashes,  3},
  {NULL, NULL, 0}
};

void R_init_rush(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
