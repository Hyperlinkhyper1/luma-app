#pragma once

#include <windows.h>

namespace luma_apo {

// {35B5D8B3-4DAD-4BDE-815F-03F697E353E5}
constexpr GUID kVoiceEqClsid = {
    0x35b5d8b3, 0x4dad, 0x4bde, {0x81, 0x5f, 0x03, 0xf6, 0x97, 0xe3, 0x53, 0xe5}};

constexpr wchar_t kVoiceEqClsidString[] =
    L"{35B5D8B3-4DAD-4BDE-815F-03F697E353E5}";

constexpr wchar_t kVoiceEqFriendlyName[] = L"luma voice EQ";

}  // namespace luma_apo
