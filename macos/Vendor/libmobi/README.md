# libmobi 0.12

Copyright Bartek Fabiszewski and contributors; LGPL-3.0-or-later.
See COPYING and AUTHORS. Upstream: https://github.com/bfabiszewski/libmobi

The selected C/header files are unmodified from the commit in ORIGIN.json.
DeepReader supplies include/libmobi.h and SwiftPM configuration in ../../Package.swift.
Only the reader/reconstruction library is built, using system zlib.
Encryption/DRM and OPF generation are disabled. No DRM keys are accepted.

The complete DeepReader source is included in the application (Resources/Source.zip).
Rebuild/relink with a modified library using `swift build` or `bash macos/build.sh`;
no signing key is needed for the ad-hoc signed distribution.
