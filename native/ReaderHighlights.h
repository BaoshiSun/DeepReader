// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once
#include <string>
#include <vector>
class EngineBase;
struct HighlightPart { int page; RectF rect; };
bool ReaderHasHighlight(EngineBase*, const std::vector<HighlightPart>&, const std::string& id);
bool ReaderSetHighlight(EngineBase*, const std::vector<HighlightPart>&, const std::string& id,
    const std::string& text, bool enabled);
