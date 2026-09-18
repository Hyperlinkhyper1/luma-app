#ifndef RUNNER_NATIVE_WEBVIEW_H_
#define RUNNER_NATIVE_WEBVIEW_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <wrl.h>

#include <WebView2.h>

#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

// Hosts WebView2 in real child windows laid over the Flutter view.
//
// The webview_windows package renders WebView2 off-screen and screen-captures
// every frame into a Flutter texture, and relays each mouse move through a
// platform channel. For a WebGL game that capped out near 13 fps and froze on
// every drag. A windowed WebView2 presents straight to the screen and takes
// input directly, at the cost of nothing Flutter draws being able to cover it;
// the Dart side hides the window whenever it is not the top-most content.
class NativeWebviewManager {
 public:
  NativeWebviewManager(flutter::BinaryMessenger* messenger, HWND parent,
                       HWND flutter_view);
  ~NativeWebviewManager();

  // Popups and IME placement need to know when the top-level window moved.
  void OnParentMoved();

 private:
  struct View {
    HWND host = nullptr;
    Microsoft::WRL::ComPtr<ICoreWebView2Controller> controller;
    Microsoft::WRL::ComPtr<ICoreWebView2> webview;
    RECT bounds{0, 0, 0, 0};
    bool visible = false;
    bool destroyed = false;
  };

  using MethodResult = flutter::MethodResult<flutter::EncodableValue>;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<MethodResult> result);
  void WithEnvironment(const std::wstring& user_data_folder,
                       std::function<void(ICoreWebView2Environment*)> ready);
  void CreateController(int64_t id, const std::wstring& url);
  void ApplyBounds(View& view);
  void ApplyVisibility(View& view);
  void Emit(const std::string& method, int64_t id, const std::string& data);
  void Destroy(int64_t id);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND parent_;
  std::map<int64_t, std::shared_ptr<View>> views_;
  int64_t next_id_ = 1;
  Microsoft::WRL::ComPtr<ICoreWebView2Environment> environment_;
  bool environment_pending_ = false;
  HRESULT environment_error_ = S_OK;
  std::vector<std::function<void(ICoreWebView2Environment*)>> waiting_;
};

#endif  // RUNNER_NATIVE_WEBVIEW_H_
