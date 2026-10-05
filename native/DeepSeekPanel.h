// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once
struct MainWindow;
void DeepSeekInitialize(MainWindow* win);
void DeepSeekExplain(MainWindow* win);
void DeepSeekToggle(MainWindow* win);
void DeepSeekLayout(MainWindow* win, Rect& available);
void DeepSeekReset(MainWindow* win);
void DeepSeekDestroy(MainWindow* win);
bool DeepSeekPreTranslate(MSG& msg);
