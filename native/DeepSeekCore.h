// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once
#include <string>
#include <vector>
namespace deepseek {
enum Provider { OpenRouter, DeepSeek, Gemini, OpenAI, Claude, Qwen, Kimi, Glm, Doubao, MiniMax, Grok, Mistral, Custom, ProviderCount };
struct PanelPlacement {
    int width = 420, floatingWidth = 440, floatingHeight = 700; // logical pixels (96 DPI)
    bool floating = false;
};
struct Config {
    int provider = DeepSeek;
    bool english = false;
    bool useWorldKnowledge = false;
    bool adultConfirmed = false;
    std::string sharingRecipient;
    bool onboardingSeen = false;
    int lookupSplit = 50;
    PanelPlacement panel;
    std::wstring archiveFolder;
    std::string keys[ProviderCount];
    std::string endpoints[ProviderCount];
    std::string keyEndpoints[ProviderCount]; // Empty legacy bindings mean the official default endpoint.
    std::string models[ProviderCount] = {"openrouter/free","deepseek-flash","gemini-3.8-flash","gpt-4.1-mini","claude-sonnet-5-5","qwen-plus","kimi-k2.6","glm-4.7","","MiniMax-M3","grok-4.7","mistral-small-latest",""};
};
struct Endpoint { std::wstring host, path; unsigned short port = 443; };
Endpoint Service(int provider);
std::string EndpointURL(const Config& config);
bool ParseEndpoint(const std::string& value, Endpoint& endpoint);
const wchar_t* ProviderURL(int provider);
bool KeyMatchesEndpoint(const Config& config);
const char* ProviderName(int provider);
bool FreeModel(const Config& config);
bool ValidModel(const std::string& model);
std::vector<std::wstring> ModelChoices(int provider);
std::string Utf8(const std::wstring& text);
std::wstring Wide(const std::string& text);
std::string JsonString(const std::string& text);
enum class Task { Explain, Followup, Document, Review, Part, Merge };
constexpr size_t FollowupQuestionLimit = 1200, FollowupConversationLimit = 12000;
bool CanFollowup(const std::wstring& conversation, const std::wstring& question);
std::wstring FollowupTranscript(const std::wstring& conversation, const std::wstring& question,
    const std::wstring& answer, bool english, const std::wstring& model, bool useWorldKnowledge = false);
std::string RequestBody(const Config& config, Task task, const std::wstring& data, const std::wstring& selected = L"",
    const std::wstring& conversation = L"", const std::wstring& question = L"");
struct Result { bool ok = false; std::wstring text; std::string model; };
Result Response(const std::string& response, unsigned long status, bool english, int provider = DeepSeek);
std::wstring Context(const std::wstring& before, const std::wstring& selected, const std::wstring& after);
bool ValidKey(const std::string& key);
bool ReadConfig(const std::wstring& path, Config& config);
bool SaveConfig(const std::wstring& path, const Config& config);
std::string Unprotect(const std::string& encrypted);
std::string Protect(const std::string& key);
bool ReadFileText(const std::wstring& path, std::string& data, size_t limit = 512 * 1024);
bool WriteFileAtomic(const std::wstring& path, const std::string& data);
}
