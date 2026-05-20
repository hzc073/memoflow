#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }
  RunnerLog("process_start");

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  const HRESULT co_initialize_result =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  RunnerLog("co_initialize_result=" +
            std::to_string(static_cast<long>(co_initialize_result)));

  int exit_code = EXIT_SUCCESS;

  {
    flutter::DartProject project(L"data");

    std::vector<std::string> command_line_arguments =
        GetCommandLineArguments();

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1360, 860);
    window.SetMinimumSize(Win32Window::Size(960, 640));
    RunnerLog("main_window_create_start");
    if (!window.Create(L"MemoFlow", origin, size)) {
      RunnerLog("main_window_create_failed");
      exit_code = EXIT_FAILURE;
    } else {
      RunnerLog("main_window_create_done");
      window.SetQuitOnClose(true);

      RunnerLog("message_loop_enter");
      ::MSG msg;
      while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
      }
      RunnerLog("message_loop_exit");
    }

    RunnerLog("flutter_scope_exit_start");
  }
  RunnerLog("flutter_scope_exit_done");

  // WebView/CoreMessaging teardown can still have process-level COM work queued
  // after the Flutter engine and window objects are destroyed. Let process exit
  // clean up the COM apartment instead of explicitly uninitializing it here,
  // which avoids a shutdown-time coremessaging.dll APPCRASH on Windows.
  RunnerLog("co_uninitialize_skipped_for_process_exit");
  RunnerLog("terminate_process_start");
  ::TerminateProcess(::GetCurrentProcess(), static_cast<UINT>(exit_code));
  return exit_code;
}
