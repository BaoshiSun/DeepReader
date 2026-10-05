# DeepReader modifications

Release: **DeepReader 1.0.0**, modified **2026-10-05**.

DeepReader is an independent modification of **SumatraPDF 3.6.1rel**. It is not an official SumatraPDF release and is not endorsed by the upstream project or model providers.

- Adds a native right sidebar for concise contextual AI explanations, saved reading history, document summaries and daily / weekly / monthly reviews.
- Adds a multiline follow-up field beneath the explanation, with Send / Stop and Ctrl + Enter. Carries the selected passage, source context and current conversation, saves successful turns in the original history record, and preserves drafts on failure. New selections and document changes reset the active conversation.
- Supports Chinese / English UI and responses, with user-supplied provider keys. The default provider is the official DeepSeek API; no developer key is included.
- Opens the sidebar automatically for each reader window, including an empty startup window. Shows a short guide only for a new profile's first launch; Settings can reopen it. Existing profiles skip the guide.
- Adds a draggable, persisted split between selected text and explanation, initially 50/50, and deterministic local reading statistics for document/day/week/month scopes. Summary records include the prepared statistics snapshot.
- Replaces the context toggle with PDF highlight/unhighlight and an explicit save-annotations button. Annotation locations belong to the captured query, persist across reopening, and do not delete unrelated annotations.
- Changes the product name, title, About page, Windows executable metadata and portable release name to DeepReader. Recolors the application icon green, derived from Alex's CC BY 3.0 original; attribution and component licenses are retained. Edited PNG and multi-resolution ICO assets are included in source/assets/.
- Preserves legacy internal window classes, DDE command names, configuration filenames and encryption entropy for compatibility. These identifiers are not the product name.
- Disables automatic upstream update checks in the clean portable settings. This release is not an installer and does not register itself as the system PDF application.
- Removes the optional UnRAR fallback and its static link dependencies because of UnRAR's field-of-use restriction. The LGPL unarr decoder remains. Some RAR / CBR files that depended on the fallback are no longer supported. PDF reading and AI behavior are unaffected. The original upstream archive is preserved for provenance; its unused UnRAR source retains its own license and is not compiled into DeepReader.

The complete patch is `native/apply-native.py`, plus the C++ sources in `native/`. It applies to the unmodified upstream archive pinned by `native/source-lock.json`. Generated upstream files carry dated modification notices. See `README.md` and `native/README.md` for build and test commands.

The portable release includes `source/upstream/sumatrapdf-3.6.1rel.zip`, the added source files, patch and build scripts. Recipients can rebuild a modified version; there is no activation or signing restriction imposed by DeepReader. General-purpose Microsoft build tools and the Windows SDK are downloaded separately from official sources with pinned hashes.

Copyright 2026 DeepReader contributors for original changes, licensed AGPL-3.0-or-later. Upstream copyrights and individual licenses remain in force. The software is provided without warranty; redistribution and modification are permitted subject to the applicable licenses.
