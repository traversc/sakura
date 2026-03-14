// sakura - Core Functions -----------------------------------------------------

#include "sakura.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// internal functions ----------------------------------------------------------

static SEXP nano_eval_res;

static void nano_eval_safe(void *call) {
  nano_eval_res = Rf_eval((SEXP) call, R_GlobalEnv);
}

static void nano_write_bytes(R_outpstream_t stream, void *src, int len) {

  nano_buf *buf = (nano_buf *) stream->data;

  size_t req = buf->cur + (size_t) len;
  if (req > buf->len) {
    if (req > R_XLEN_T_MAX) {
      if (buf->len) R_Free(buf->buf);
      Rf_error("serialization exceeds max length of raw vector");
    }
    do {
      buf->len += buf->len > SAKURA_SERIAL_THR ? SAKURA_SERIAL_THR : buf->len;
    } while (buf->len < req);
    buf->buf = R_Realloc(buf->buf, buf->len, unsigned char);
  }

  memcpy(buf->buf + buf->cur, src, len);
  buf->cur += len;

}

static void nano_read_bytes(R_inpstream_t stream, void *dst, int len) {

  nano_buf *buf = (nano_buf *) stream->data;
  if (buf->cur + (size_t) len > buf->len) Rf_error("unserialization error");
  memcpy(dst, buf->buf + buf->cur, len);
  buf->cur += (size_t) len;

}

typedef struct sakura_gz_cleanup_s {
  const char *path;
  sakura_gz_file *file;
} sakura_gz_cleanup;

typedef struct sakura_save_rds_data_s {
  sakura_gz_cleanup cleanup;
  SEXP object;
  SEXP config;
} sakura_save_rds_data;

typedef struct sakura_read_rds_data_s {
  sakura_gz_cleanup cleanup;
} sakura_read_rds_data;

static void sakura_serialize_stream(
  R_outpstream_t output_stream,
  R_pstream_data_t data,
  void (*outbytes)(R_outpstream_t, void *, int),
  SEXP object,
  SEXP config
);

static SEXP sakura_unserialize_stream(
  R_inpstream_t input_stream,
  R_pstream_data_t data,
  void (*inbytes)(R_inpstream_t, void *, int)
);

static void sakura_write_gzip_bytes(R_outpstream_t stream, void *src, int len) {

  sakura_gz_file *file = (sakura_gz_file *) stream->data;
  unsigned char *cursor = (unsigned char *) src;

  while (len > 0) {
    int written = gzwrite(file->file, cursor, (unsigned int) len);
    if (written <= 0) {
      int errnum = Z_OK;
      const char *msg = gzerror(file->file, &errnum);
      Rf_error("gzip write error: %s", msg);
    }
    cursor += written;
    len -= written;
  }

}

static void sakura_read_gzip_bytes(R_inpstream_t stream, void *dst, int len) {

  sakura_gz_file *file = (sakura_gz_file *) stream->data;
  unsigned char *cursor = (unsigned char *) dst;

  while (len > 0) {
    int read = gzread(file->file, cursor, (unsigned int) len);
    if (read <= 0) {
      int errnum = Z_OK;
      const char *msg = gzerror(file->file, &errnum);
      if (errnum == Z_OK && gzeof(file->file)) {
        Rf_error("unexpected end of gzip stream");
      }
      Rf_error("gzip read error: %s", msg);
    }
    cursor += read;
    len -= read;
  }

}

static void sakura_gz_cleanup_close(void *data, Rboolean jump) {

  sakura_gz_cleanup *cleanup = (sakura_gz_cleanup *) data;

  if (cleanup->file->file != NULL) {
    int status = gzclose(cleanup->file->file);
    cleanup->file->file = NULL;

    if (!jump && status != Z_OK) {
      Rf_error("failed to close gzip file '%s'", cleanup->path);
    }
  }

}

static void nano_write_string(R_outpstream_t stream, SEXP string) {

  int length = LENGTH(string);
  const char *value = CHAR(string);
  void (*OutBytes)(R_outpstream_t, void *, int) = stream->OutBytes;

  OutBytes(stream, &length, sizeof(int));
  if (length) {
    // OutBytes uses a non-const pointer even though the bytes are not mutated.
    OutBytes(stream, (void *) value, length);
  }

}

static SEXP nano_read_string(R_inpstream_t stream) {

  int length;
  char *value;
  void (*InBytes)(R_inpstream_t, void *, int) = stream->InBytes;

  InBytes(stream, &length, sizeof(int));
  if (length < 0) {
    Rf_error("unserialization error");
  }

  value = (char *) R_alloc((size_t) length + 1, sizeof(char));
  if (length) {
    InBytes(stream, value, length);
  }
  value[length] = '\0';

  return Rf_mkString(value);

}

static SEXP sakura_save_rds_impl(void *data) {

  sakura_save_rds_data *save_data = (sakura_save_rds_data *) data;
  struct R_outpstream_st output_stream;

  sakura_serialize_stream(
    &output_stream,
    (R_pstream_data_t) save_data->cleanup.file,
    sakura_write_gzip_bytes,
    save_data->object,
    save_data->config
  );

  return R_NilValue;

}

static SEXP sakura_read_rds_impl(void *data) {

  sakura_read_rds_data *read_data = (sakura_read_rds_data *) data;
  struct R_inpstream_st input_stream;

  return sakura_unserialize_stream(
    &input_stream,
    (R_pstream_data_t) read_data->cleanup.file,
    sakura_read_gzip_bytes
  );

}

static SEXP nano_serialize_hook(SEXP x, SEXP bundle_xptr) {

  sakura_serial_bundle *bundle = (sakura_serial_bundle *) R_ExternalPtrAddr(bundle_xptr);
  R_outpstream_t stream = bundle->stream;
  SEXP klass = bundle->klass;
  SEXP package = bundle->package;
  SEXP sfunc = bundle->sfunc;
  int len = (int) XLENGTH(klass), match = 0, i;
  void (*OutBytes)(R_outpstream_t, void *, int) = stream->OutBytes;

  for (i = 0; i < len; i++) {
    if (Rf_inherits(x, CHAR(STRING_ELT(klass, i)))) {
      match = 1;
      break;
    }
  }

  if (!match)
    return R_NilValue;

  SEXP call;
  PROTECT(call = Rf_lcons(VECTOR_ELT(sfunc, i), Rf_cons(x, R_NilValue)));
  if (!R_ToplevelExec(nano_eval_safe, call) || TYPEOF(nano_eval_res) != RAWSXP) {
    UNPROTECT(1);
    return R_NilValue;
  }
  UNPROTECT(1);

  // write out PERSISTSXP manually
  uint64_t size = (uint64_t) XLENGTH(nano_eval_res);
  char size_string[21];
  snprintf(size_string, sizeof(size_string), "%020" PRIu64, size);

  // should be const but OutBytes uses non-const pointer even though it should be const
  static int int_0 = 0;
  static int int_1 = 1;
  static int int_20 = 20;
  static int int_charsxp = CHARSXP;
  static int int_persistsxp = 247;

  // OutInteger(stream, PERSISTSXP);              // Total bytes
  OutBytes(stream, &int_persistsxp, sizeof(int)); // 4
  // OutStringVec(stream, t, ref_table);
  OutBytes(stream, &int_0, sizeof(int));          // 8
  OutBytes(stream, &int_1, sizeof(int));          // 12
  OutBytes(stream, &int_charsxp, sizeof(int));    // 16
  OutBytes(stream, &int_20, sizeof(int));         // 20
  OutBytes(stream, &size_string[0], 20);          // 40

  // write out binary serialization blob
  unsigned char *dest = RAW(nano_eval_res);
  while (size > SAKURA_CHUNK_SIZE) {
    OutBytes(stream, dest, SAKURA_CHUNK_SIZE);
    dest += SAKURA_CHUNK_SIZE;
    size -= SAKURA_CHUNK_SIZE;
  }
  OutBytes(stream, dest, (int) size);

  nano_write_string(stream, STRING_ELT(klass, i));
  nano_write_string(stream, STRING_ELT(package, i));

  return R_BlankScalarString; // this will write the PERSISTSXP again

}

static SEXP nano_unserialize_hook(SEXP x, SEXP bundle_xptr) {

  sakura_unserial_bundle *bundle = (sakura_unserial_bundle *) R_ExternalPtrAddr(bundle_xptr);
  R_inpstream_t stream = bundle->stream;
  void (*InBytes)(R_inpstream_t, void *, int) = stream->InBytes;

  const char *size_string = CHAR(STRING_ELT(x, 0));
  uint64_t size = (uint64_t) strtoull(size_string, NULL, 10);

  SEXP raw, class_name, package_name, name, ns, call, out;
  PROTECT(raw = Rf_allocVector(RAWSXP, (R_xlen_t) size));
  unsigned char *dest = RAW(raw);
  while (size > SAKURA_CHUNK_SIZE) {
    InBytes(stream, dest, SAKURA_CHUNK_SIZE);
    dest += SAKURA_CHUNK_SIZE;
    size -= SAKURA_CHUNK_SIZE;
  }
  InBytes(stream, dest, (int) size);

  PROTECT(class_name = nano_read_string(stream));
  PROTECT(package_name = nano_read_string(stream));

  // read in the automatic trailing PERSISTSXP bytes and discard them
  char discard[SAKURA_PERSIST_DISCARD];
  InBytes(stream, discard, SAKURA_PERSIST_DISCARD);

  PROTECT(name = Rf_mkString("sakura"));
  PROTECT(ns = R_FindNamespace(name));
  PROTECT(call = Rf_lcons(
    Rf_install(".sakura_dispatch_unserialize"),
    Rf_cons(
      raw,
      Rf_cons(class_name, Rf_cons(package_name, R_NilValue))
    )
  ));
  out = Rf_eval(call, ns);

  UNPROTECT(6);
  return out;

}

static void sakura_serialize_stream(
  R_outpstream_t output_stream,
  R_pstream_data_t data,
  void (*outbytes)(R_outpstream_t, void *, int),
  SEXP object,
  SEXP config
) {

  if (config == R_NilValue) {

    R_InitOutPStream(
      output_stream,
      data,
      R_pstream_binary_format,
      SAKURA_SERIAL_VER,
      NULL,
      outbytes,
      NULL,
      R_NilValue
    );

    R_Serialize(object, output_stream);

  } else {

    sakura_serial_bundle bundle;
    R_SetExternalPtrAddr(sakura_bundle, &bundle);

    sakura_serialize_init(
      sakura_bundle,
      output_stream,
      data,
      VECTOR_ELT(config, 0),
      VECTOR_ELT(config, 1),
      VECTOR_ELT(config, 2),
      outbytes
    );

    R_Serialize(object, output_stream);
    R_SetExternalPtrAddr(sakura_bundle, NULL);

  }

}

static SEXP sakura_unserialize_stream(
  R_inpstream_t input_stream,
  R_pstream_data_t data,
  void (*inbytes)(R_inpstream_t, void *, int)
) {

  sakura_unserial_bundle bundle;
  SEXP out;
  R_SetExternalPtrAddr(sakura_bundle, &bundle);

  sakura_unserialize_init(
    sakura_bundle,
    input_stream,
    data,
    inbytes
  );

  out = R_Unserialize(input_stream);
  R_SetExternalPtrAddr(sakura_bundle, NULL);

  return out;

}

static const char *sakura_file_path(SEXP file) {

  if (TYPEOF(file) != STRSXP || XLENGTH(file) != 1 || STRING_ELT(file, 0) == NA_STRING) {
    Rf_error("`file` must be a character string");
  }

  return R_ExpandFileName(CHAR(STRING_ELT(file, 0)));

}

// C API functions -------------------------------------------------------------

void sakura_serialize_init(
  SEXP bundle_xptr,
  R_outpstream_t stream,
  R_pstream_data_t data,
  SEXP klass,
  SEXP package,
  SEXP sfunc,
  void (*outbytes)(R_outpstream_t, void *, int)
) {

  sakura_serial_bundle *bundle = (sakura_serial_bundle *) R_ExternalPtrAddr(bundle_xptr);

  bundle->klass = klass;
  bundle->package = package;
  bundle->sfunc = sfunc;
  bundle->stream = stream;
  R_InitOutPStream(
    stream,
    data,
    R_pstream_binary_format,
    SAKURA_SERIAL_VER,
    NULL,
    outbytes,
    nano_serialize_hook,
    bundle_xptr
  );

}

void sakura_unserialize_init(
  SEXP bundle_xptr,
  R_inpstream_t stream,
  R_pstream_data_t data,
  void (*inbytes)(R_inpstream_t, void *, int)
) {

  sakura_unserial_bundle *bundle = (sakura_unserial_bundle *) R_ExternalPtrAddr(bundle_xptr);

  bundle->stream = stream;
  R_InitInPStream(
    stream,
    data,
    R_pstream_any_format,
    NULL,
    inbytes,
    nano_unserialize_hook,
    bundle_xptr
  );

}

void sakura_serialize(nano_buf *buf, SEXP object, SEXP config) {

  buf->buf = R_Calloc(SAKURA_INIT_BUFSIZE, unsigned char);
  buf->len = SAKURA_INIT_BUFSIZE;
  buf->cur = 0;

  struct R_outpstream_st output_stream;

  sakura_serialize_stream(
    &output_stream,
    (R_pstream_data_t) buf,
    nano_write_bytes,
    object,
    config
  );

}

SEXP sakura_unserialize(unsigned char *buf, size_t sz) {

  nano_buf nbuf;
  nbuf.buf = buf;
  nbuf.len = sz;
  nbuf.cur = 0;

  struct R_inpstream_st input_stream;

  return sakura_unserialize_stream(
    &input_stream,
    (R_pstream_data_t) &nbuf,
    nano_read_bytes
  );

}

// R API functions -------------------------------------------------------------

SEXP sakura_r_serialize(SEXP object, SEXP config) {

  nano_buf buf;
  sakura_serialize(&buf, object, config);

  SEXP out = Rf_allocVector(RAWSXP, buf.cur);
  memcpy(RAW(out), buf.buf, buf.cur);
  R_Free(buf.buf);

  return out;

}

SEXP sakura_r_unserialize(SEXP object) {

  return sakura_unserialize(RAW(object), XLENGTH(object));

}

SEXP sakura_r_save_rds(SEXP object, SEXP file, SEXP config) {

  const char *path = sakura_file_path(file);
  sakura_gz_file gz_file;
  sakura_save_rds_data save_data;

  gz_file.file = gzopen(path, "wb");
  if (gz_file.file == NULL) {
    Rf_error("failed to open file '%s' for writing", path);
  }

  save_data.cleanup.path = path;
  save_data.cleanup.file = &gz_file;
  save_data.object = object;
  save_data.config = config;

  R_UnwindProtect(
    sakura_save_rds_impl,
    &save_data,
    sakura_gz_cleanup_close,
    &save_data.cleanup,
    NULL
  );

  return R_NilValue;

}

SEXP sakura_r_read_rds(SEXP file) {

  const char *path = sakura_file_path(file);
  sakura_gz_file gz_file;
  sakura_read_rds_data read_data;

  gz_file.file = gzopen(path, "rb");
  if (gz_file.file == NULL) {
    Rf_error("failed to open file '%s' for reading", path);
  }

  read_data.cleanup.path = path;
  read_data.cleanup.file = &gz_file;

  return R_UnwindProtect(
    sakura_read_rds_impl,
    &read_data,
    sakura_gz_cleanup_close,
    &read_data.cleanup,
    NULL
  );

}
