#ifndef RUNNER_NATIVE_WEBVIEW_REGION_H_
#define RUNNER_NATIVE_WEBVIEW_REGION_H_

#include <windows.h>

#include <vector>

struct NativeWebviewOcclusion {
  RECT bounds;
  LONG radius_x;
  LONG radius_y;
};

inline void ApplyNativeWebviewRegion(
    HWND host, const RECT& bounds,
    const std::vector<NativeWebviewOcclusion>& occlusions) {
  if (occlusions.empty()) {
    SetWindowRgn(host, nullptr, TRUE);
    return;
  }
  HRGN region = CreateRectRgn(0, 0, bounds.right - bounds.left,
                            bounds.bottom - bounds.top);
  if (!region) return;
  for (const auto& occlusion : occlusions) {
    const auto& r = occlusion.bounds;
    HRGN cutout = CreateRoundRectRgn(r.left, r.top, r.right + 1, r.bottom + 1,
                                    occlusion.radius_x * 2,
                                    occlusion.radius_y * 2);
    if (!cutout) continue;
    CombineRgn(region, region, cutout, RGN_DIFF);
    DeleteObject(cutout);
  }
  if (!SetWindowRgn(host, region, TRUE)) DeleteObject(region);
}

#endif
