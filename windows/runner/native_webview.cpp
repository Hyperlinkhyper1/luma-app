#include "native_webview.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <variant>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace {

const wchar_t kHostClass[] = L"LUMA_NATIVE_WEBVIEW_HOST";

std::wstring Wide(const std::string& text) {
  if (text.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                 static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      out.data(), size);
  return out;
}

std::string Narrow(const wchar_t* text) {
  if (!text || !*text) return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr,
                                 nullptr);
  std::string out(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, out.data(), size, nullptr,
                      nullptr);
  out.resize(size - 1);
  return out;
}

const flutter::EncodableValue* Arg(const flutter::EncodableMap& map,
                                   const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

std::optional<int64_t> IntArg(const flutter::EncodableMap& map,
                              const char* key) {
  auto value = Arg(map, key);
  if (!value) return std::nullopt;
  if (auto v = std::get_if<int32_t>(value)) return *v;
  if (auto v = std::get_if<int64_t>(value)) return *v;
  if (auto v = std::get_if<double>(value)) return static_cast<int64_t>(*v);
  return std::nullopt;
}

std::string StringArg(const flutter::EncodableMap& map, const char* key) {
  auto value = Arg(map, key);
  if (!value) return std::string();
  if (auto v = std::get_if<std::string>(value)) return *v;
  return std::string();
}

bool BoolArg(const flutter::EncodableMap& map, const char* key) {
  auto value = Arg(map, key);
  if (!value) return false;
  if (auto v = std::get_if<bool>(value)) return *v;
  return false;
}

void RegisterHostClass() {
  static bool registered = false;
  if (registered) return;
  WNDCLASSW window_class{};
  window_class.lpfnWndProc = DefWindowProcW;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kHostClass;
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&window_class);
  registered = true;
}

}  // namespace

NativeWebviewManager::NativeWebviewManager(flutter::BinaryMessenger* messenger,
                                           HWND parent, HWND flutter_view)
    : parent_(parent) {
  // Without this the Flutter view paints over its new sibling.
  SetWindowLongPtr(flutter_view, GWL_STYLE,
                   GetWindowLongPtr(flutter_view, GWL_STYLE) | WS_CLIPSIBLINGS);
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "luma/native_webview",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

NativeWebviewManager::~NativeWebviewManager() {
  channel_->SetMethodCallHandler(nullptr);
  std::vector<int64_t> ids;
  for (const auto& entry : views_) ids.push_back(entry.first);
  for (auto id : ids) Destroy(id);
}

void NativeWebviewManager::OnParentMoved() {
  for (auto& entry : views_) {
    if (entry.second->controller) {
      entry.second->controller->NotifyParentWindowPositionChanged();
    }
  }
}

void NativeWebviewManager::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<MethodResult> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) {
    result->Error("bad_args", "Expected a map of arguments.");
    return;
  }
  const auto& method = call.method_name();
  if (method == "create") {
    RegisterHostClass();
    int64_t id = next_id_++;
    auto view = std::make_shared<View>();
    view->host = CreateWindowExW(
        0, kHostClass, L"", WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS, 0,
        0, 0, 0, parent_, nullptr, GetModuleHandle(nullptr), nullptr);
    if (!view->host) {
      result->Error("host_failed", "Could not create the webview window.");
      return;
    }
    SetWindowPos(view->host, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    views_[id] = view;
    auto url = Wide(StringArg(*args, "url"));
    WithEnvironment(Wide(StringArg(*args, "userDataFolder")),
                    [this, id, url](ICoreWebView2Environment* environment) {
                      if (!environment) {
                        Emit("error", id,
                             "Microsoft Edge WebView2 Runtime is not "
                             "available. Install it, then reopen this page.");
                        return;
                      }
                      CreateController(id, url);
                    });
    result->Success(flutter::EncodableValue(id));
    return;
  }

  auto id = IntArg(*args, "id");
  auto found = id ? views_.find(*id) : views_.end();
  if (found == views_.end()) {
    result->Success();
    return;
  }
  auto& view = *found->second;
  if (method == "setBounds") {
    view.bounds = RECT{static_cast<LONG>(IntArg(*args, "x").value_or(0)),
                       static_cast<LONG>(IntArg(*args, "y").value_or(0)),
                       static_cast<LONG>(IntArg(*args, "x").value_or(0) +
                                         IntArg(*args, "width").value_or(0)),
                       static_cast<LONG>(IntArg(*args, "y").value_or(0) +
                                         IntArg(*args, "height").value_or(0))};
    ApplyBounds(view);
  } else if (method == "setVisible") {
    view.visible = BoolArg(*args, "visible");
    ApplyVisibility(view);
  } else if (method == "post") {
    if (view.webview) {
      view.webview->PostWebMessageAsString(
          Wide(StringArg(*args, "data")).c_str());
    }
  } else if (method == "focus") {
    if (view.controller) {
      view.controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
    }
  } else if (method == "reload") {
    if (view.webview) view.webview->Reload();
  } else if (method == "dispose") {
    Destroy(*id);
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

void NativeWebviewManager::WithEnvironment(
    const std::wstring& user_data_folder,
    std::function<void(ICoreWebView2Environment*)> ready) {
  if (environment_) {
    ready(environment_.Get());
    return;
  }
  if (FAILED(environment_error_)) {
    ready(nullptr);
    return;
  }
  waiting_.push_back(std::move(ready));
  if (environment_pending_) return;
  environment_pending_ = true;
  HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
      nullptr, user_data_folder.empty() ? nullptr : user_data_folder.c_str(),
      nullptr,
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [this](HRESULT error, ICoreWebView2Environment* environment) {
            environment_pending_ = false;
            if (FAILED(error) || !environment) {
              environment_error_ = FAILED(error) ? error : E_FAIL;
            } else {
              environment_ = environment;
            }
            auto waiting = std::move(waiting_);
            waiting_.clear();
            for (auto& callback : waiting) callback(environment_.Get());
            return S_OK;
          })
          .Get());
  if (FAILED(hr)) {
    environment_pending_ = false;
    environment_error_ = hr;
    auto waiting = std::move(waiting_);
    waiting_.clear();
    for (auto& callback : waiting) callback(nullptr);
  }
}

void NativeWebviewManager::CreateController(int64_t id,
                                            const std::wstring& url) {
  auto found = views_.find(id);
  if (found == views_.end()) return;
  auto view = found->second;
  environment_->CreateCoreWebView2Controller(
      view->host,
      Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
          [this, id, view, url](HRESULT error,
                                ICoreWebView2Controller* controller) {
            if (view->destroyed) {
              if (controller) controller->Close();
              return S_OK;
            }
            if (FAILED(error) || !controller) {
              Emit("error", id, "The WebView2 control could not be created.");
              return S_OK;
            }
            view->controller = controller;
            controller->get_CoreWebView2(&view->webview);
            ComPtr<ICoreWebView2Controller2> controller2;
            if (SUCCEEDED(controller->QueryInterface(
                    IID_PPV_ARGS(&controller2)))) {
              COREWEBVIEW2_COLOR background{255, 0xdb, 0xe9, 0xe5};
              controller2->put_DefaultBackgroundColor(background);
            }
            ComPtr<ICoreWebView2Settings> settings;
            if (SUCCEEDED(view->webview->get_Settings(&settings))) {
              settings->put_AreDefaultContextMenusEnabled(FALSE);
              settings->put_IsZoomControlEnabled(FALSE);
              settings->put_IsStatusBarEnabled(FALSE);
#ifdef NDEBUG
              settings->put_AreDevToolsEnabled(FALSE);
#endif
            }
            EventRegistrationToken token;
            view->webview->add_WebMessageReceived(
                Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                    [this, id](ICoreWebView2*,
                               ICoreWebView2WebMessageReceivedEventArgs* args) {
                      LPWSTR message = nullptr;
                      if (SUCCEEDED(args->TryGetWebMessageAsString(&message))) {
                        Emit("message", id, Narrow(message));
                        CoTaskMemFree(message);
                      }
                      return S_OK;
                    })
                    .Get(),
                &token);
            view->webview->add_NavigationCompleted(
                Callback<ICoreWebView2NavigationCompletedEventHandler>(
                    [this, id](ICoreWebView2*,
                               ICoreWebView2NavigationCompletedEventArgs* args) {
                      BOOL success = TRUE;
                      args->get_IsSuccess(&success);
                      if (!success) {
                        Emit("error", id, "The page could not be loaded.");
                      }
                      return S_OK;
                    })
                    .Get(),
                &token);
            view->webview->add_ProcessFailed(
                Callback<ICoreWebView2ProcessFailedEventHandler>(
                    [this, id](ICoreWebView2*,
                               ICoreWebView2ProcessFailedEventArgs*) {
                      Emit("error", id, "The page stopped responding.");
                      return S_OK;
                    })
                    .Get(),
                &token);
            view->webview->add_NewWindowRequested(
                Callback<ICoreWebView2NewWindowRequestedEventHandler>(
                    [](ICoreWebView2*,
                       ICoreWebView2NewWindowRequestedEventArgs* args) {
                      args->put_Handled(TRUE);
                      return S_OK;
                    })
                    .Get(),
                &token);
            ApplyBounds(*view);
            ApplyVisibility(*view);
            view->webview->Navigate(url.c_str());
            return S_OK;
          })
          .Get());
}

void NativeWebviewManager::ApplyBounds(View& view) {
  const auto& b = view.bounds;
  MoveWindow(view.host, b.left, b.top, b.right - b.left, b.bottom - b.top,
             TRUE);
  if (view.controller) {
    view.controller->put_Bounds(
        RECT{0, 0, b.right - b.left, b.bottom - b.top});
  }
}

void NativeWebviewManager::ApplyVisibility(View& view) {
  bool show = view.visible && view.bounds.right > view.bounds.left &&
              view.bounds.bottom > view.bounds.top;
  ShowWindow(view.host, show ? SW_SHOWNA : SW_HIDE);
  if (view.controller) view.controller->put_IsVisible(show ? TRUE : FALSE);
}

void NativeWebviewManager::Emit(const std::string& method, int64_t id,
                                const std::string& data) {
  channel_->InvokeMethod(
      method, std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                  {flutter::EncodableValue("id"), flutter::EncodableValue(id)},
                  {flutter::EncodableValue("data"),
                   flutter::EncodableValue(data)},
              }));
}

void NativeWebviewManager::Destroy(int64_t id) {
  auto found = views_.find(id);
  if (found == views_.end()) return;
  auto view = found->second;
  views_.erase(found);
  view->destroyed = true;
  if (view->controller) view->controller->Close();
  view->controller = nullptr;
  view->webview = nullptr;
  if (view->host) DestroyWindow(view->host);
  view->host = nullptr;
}
