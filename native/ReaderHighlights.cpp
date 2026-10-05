// SPDX-License-Identifier: AGPL-3.0-or-later
#include "utils/BaseUtil.h"
#include "utils/ScopedWin.h"
#include "utils/WinUtil.h"
#include "wingui/UIModels.h"
#include "mupdf/fitz.h"
#include "mupdf/pdf.h"
#include "DocController.h"
#include "EngineBase.h"
#include "Annotation.h"
#include "EngineMupdf.h"
#include "EngineAll.h"
#include "ReaderHighlights.h"

namespace {
bool Name(Annotation* annot,const std::string& id,bool set=false) {
    auto engine=annot->engine;
    auto ctx=engine->Ctx();
    bool ok=false; fz_var(ok);
    ScopedCritSec lock(engine->ctxAccess);
    fz_try(ctx) {
        auto obj=pdf_annot_obj(ctx,annot->pdfannot);
        if (set) { pdf_dict_puts_drop(ctx,obj,"NM",pdf_new_text_string(ctx,id.c_str())); ok=true; }
        else ok=str::Eq(pdf_to_text_string(ctx,pdf_dict_gets(ctx,obj,"NM")),id.c_str());
    }
    fz_catch(ctx) { fz_report_error(ctx); }
    return ok;
}
std::vector<Annotation*> Find(EngineBase* base,const std::vector<HighlightPart>& parts,const std::string& id) {
    std::vector<Annotation*> found;
    if (!base || !EngineSupportsAnnotations(base) || id.empty()) return found;
    auto engine=AsEngineMupdf(base);
    ScopedCritSec lock(&engine->pagesAccess);
    int last=0;
    for (const auto& part:parts) {
        if (part.page==last) continue;
        last=part.page;
        auto page=engine->GetFzPageInfo(part.page,true);
        if (!page) continue;
        for (auto annot:page->annotations)
            if (Type(annot)==AnnotationType::Highlight && Name(annot,id)) found.push_back(annot);
    }
    return found;
}
}
bool ReaderHasHighlight(EngineBase* engine,const std::vector<HighlightPart>& parts,const std::string& id) {
    return !Find(engine,parts,id).empty();
}
bool ReaderSetHighlight(EngineBase* engine,const std::vector<HighlightPart>& parts,const std::string& id,
    const std::string& text,bool enabled) {
    if (!engine || !EngineSupportsAnnotations(engine) || parts.empty() || id.empty()) return false;
    auto existing=Find(engine,parts,id);
    if (!enabled) {
        for (auto annot:existing) DeleteAnnotation(annot);
        return Find(engine,parts,id).empty();
    }
    if (!existing.empty()) return true;
    AnnotCreateArgs args; args.annotType=AnnotationType::Highlight;
    ParseColor(args.col,"#74d69b");
    std::vector<Annotation*> created;
    int last=0;
    for (const auto& part:parts) {
        if (part.page==last) continue;
        last=part.page;
        Vec<RectF> rects;
        for (const auto& r:parts) if (r.page==part.page) rects.Append(r.rect);
        auto annot=EngineMupdfCreateAnnotation(engine,part.page,PointF{},&args);
        if (!annot) break;
        created.push_back(annot);
        SetQuadPointsAsRect(annot,rects); annot->bounds=GetBounds(annot);
        SetContents(annot,("DeepReader: "+text).c_str());
        if (!Name(annot,id,true)) break;
    }
    size_t pages=0; last=0;
    for (const auto& part:parts) if (part.page!=last) { ++pages; last=part.page; }
    // Roll back only this operation if any page could not be annotated.
    if (created.size()!=pages || Find(engine,parts,id).size()!=pages) {
        for (auto annot:created) DeleteAnnotation(annot);
        return false;
    }
    return true;
}
