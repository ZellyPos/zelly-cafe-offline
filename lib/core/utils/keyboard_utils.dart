import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';

/// Windows touch klaviaturasini (TabTip / IPTip) yopish uchun yordamchi sinf.
class KeyboardUtils {
  /// Flutter focusini ham olib, Windows touch klaviaturasini ham yopadi.
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
    _closeWindowsTouchKeyboard();
  }

  static void _closeWindowsTouchKeyboard() {
    try {
      // Windows versiyasiga qarab touch keyboard turli window class nomlarda bo'ladi
      for (final className in [
        'IPTIP_Main_Window', // Windows 8/10
        'IPTip_Main_Window', // Windows 10 ba'zi versiyalar
        'Microsoft.Windows.InputApp', // Windows 11
      ]) {
        final classNamePtr = className.toNativeUtf16();
        try {
          final hwnd = FindWindowEx(0, 0, classNamePtr, nullptr);
          if (hwnd != 0) {
            // Klaviatura oynasini yopish uchun SC_CLOSE yuboramiz
            PostMessage(hwnd, WM_SYSCOMMAND, SC_CLOSE, 0);
            return;
          }
        } finally {
          free(classNamePtr);
        }
      }
    } catch (_) {
      // Win32 xatoligi — klaviatura oddiy unfocus bilan yopiladi
    }
  }
}
