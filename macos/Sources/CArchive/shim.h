// SPDX-License-Identifier: AGPL-3.0-or-later
// Stable libarchive 3 C ABI used by the macOS system library. Xcode's public SDK
// ships libarchive.tbd but omits its headers; only the required declarations live here.
// Reference: https://github.com/apple-oss-distributions/libarchive
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
struct archive;
struct archive_entry;
#define ARCHIVE_OK 0
#define ARCHIVE_EOF 1
struct archive *archive_read_new(void);
int archive_read_free(struct archive *);
int archive_read_support_format_zip(struct archive *);
int archive_read_open_memory(struct archive *, const void *, size_t);
int archive_read_next_header(struct archive *, struct archive_entry **);
ssize_t archive_read_data(struct archive *, void *, size_t);
const char *archive_entry_pathname_utf8(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
int archive_entry_is_encrypted(struct archive_entry *);
const char *archive_entry_symlink(struct archive_entry *);
const char *archive_entry_hardlink(struct archive_entry *);
