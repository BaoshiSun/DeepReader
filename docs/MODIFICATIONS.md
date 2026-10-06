# DeepReader modifications

Version: **DeepReader 1.2.0**, modified **2026-10-06**. First public release: 1.0.0 (2026-10-05).

DeepReader is an independent modification of **SumatraPDF 3.6.1rel**. It is not an official SumatraPDF release and is not endorsed by the upstream project or model providers.

- Adds a native right sidebar for concise contextual AI explanations, saved reading history, document summaries and daily / weekly / monthly reviews.
- Version 1.2.0 adds per-PDF 1–5 star ratings, Reading / Finished status and completion dates, cancellable background archive copies into rating folders, and a searchable, filterable reading list with local totals, opening, export and saved document summaries. Book metadata is stored privately in BookLibrary/, excluded from public archives. Archive copies retain book identity, original PDFs and existing destination files; unsaved annotations must be saved first. These operations require no API or network requests.
- Version 1.1.0 adds a draggable sidebar width and an owned, movable, resizable floating window with Float / Dock switching. Reparents the same controls to retain selections, answers, drafts and active work; saves mode and independent docked/floating sizes in DPI-independent units. Closing the floating window hides the sidebar, while closing its reader destroys both. Existing profiles default to the original docked layout.
- Adds a multiline follow-up field beneath the explanation, with Send / Stop and Ctrl + Enter. Carries the selected passage, source context and current conversation, saves successful turns in the original history record, and preserves drafts on failure. New selections and document changes reset the active conversation.
- Supports Chinese / English UI and responses, with user-supplied provider keys. The default provider is the official DeepSeek API; no developer key is included.
- Opens the sidebar automatically for each reader window, including an empty startup window. Shows a short guide only for a new profile's first launch; Settings can reopen it. Existing profiles skip the guide.
- Adds a draggable, persisted split between selected text and explanation, initially 50/50, and deterministic local reading statistics for document/day/week/month scopes. Summary records include the prepared statistics snapshot.
- The selection/explanation divider uses a thin rule and short centered grip, with hover, drag and keyboard-focus feedback. The full drag hit area is retained without a colored banner or visible instruction text.
- Replaces the context toggle with PDF highlight/unhighlight and an explicit save-annotations button. Annotation locations belong to the captured query, persist across reopening, and do not delete unrelated annotations.
- Changes the product name, title, About page, Windows executable metadata and portable release name to DeepReader. Recolors the application icon green, derived from Alex's CC BY 3.0 original; attribution and component licenses are retained. Edited PNG and multi-resolution ICO assets are included in source/assets/.
- Preserves legacy internal window classes, DDE command names, configuration filenames and encryption entropy for compatibility. These identifiers are not the product name.
- Disables automatic upstream update checks in the clean portable settings. This release is not an installer and does not register itself as the system PDF application.
- Removes the optional UnRAR fallback and its static link dependencies because of UnRAR's field-of-use restriction. The LGPL unarr decoder remains. Some RAR / CBR files that depended on the fallback are no longer supported. PDF reading and AI behavior are unaffected. The original upstream archive is preserved for provenance; its unused UnRAR source retains its own license and is not compiled into DeepReader.

The complete patch is `native/apply-native.py`, plus the C++ sources in `native/`. It applies to the unmodified upstream archive pinned by `native/source-lock.json`. Generated upstream files carry dated modification notices. See `README.md` and `native/README.md` for build and test commands.

The portable release includes `source/upstream/sumatrapdf-3.6.1rel.zip`, the added source files, patch and build scripts. Recipients can rebuild a modified version; there is no activation or signing restriction imposed by DeepReader. General-purpose Microsoft build tools and the Windows SDK are downloaded separately from official sources with pinned hashes.

Copyright 2026 DeepReader contributors for original changes, licensed AGPL-3.0-or-later. Upstream copyrights and individual licenses remain in force. The software is provided without warranty; redistribution and modification are permitted subject to the applicable licenses.
