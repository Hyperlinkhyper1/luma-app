#include "../runner/native_webview_region.h"

#include <cassert>
#include <cstdio>

int main() {
  HWND host = CreateWindowExW(0, L"STATIC", L"", WS_POPUP, 0, 0, 500, 400,
                              nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
  assert(host);
  const RECT bounds{100, 50, 600, 450};
  const std::vector<NativeWebviewOcclusion> tooltips{
      {{-60, 100, 180, 140}, 8, 8}, {{300, 200, 380, 240}, 8, 8}};
  ApplyNativeWebviewRegion(host, bounds, tooltips);
  HRGN region = CreateRectRgn(0, 0, 0, 0);
  assert(GetWindowRgn(host, region) != ERROR);
  assert(!PtInRegion(region, 0, 120));
  assert(!PtInRegion(region, 170, 120));
  assert(!PtInRegion(region, 340, 220));
  assert(PtInRegion(region, 300, 200));
  assert(PtInRegion(region, 250, 120));
  assert(PtInRegion(region, 499, 399));

  ApplyNativeWebviewRegion(host, RECT{100, 50, 700, 500}, tooltips);
  assert(GetWindowRgn(host, region) != ERROR);
  assert(PtInRegion(region, 599, 449));
  assert(!PtInRegion(region, 170, 120));

  ApplyNativeWebviewRegion(host, bounds, {});
  assert(GetWindowRgn(host, region) == ERROR);
  DeleteObject(region);
  DestroyWindow(host);
  std::puts("native webview tooltip regions: passed");
}
