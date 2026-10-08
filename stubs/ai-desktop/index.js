"use strict";
// Linux replacement for the proprietary @hf-designer/ai-desktop native module, which only
// ships darwin/win32 binaries. The main process only calls PhotoApi.loadJpgImage, and only
// on macOS, so every method reports "not supported" and callers fall back to their
// generic code paths.
Object.defineProperty(exports, "__esModule", { value: true });

const LogLevel = { TRACE: 1, DEBUG: 2, INFO: 3, WARN: 4, ERR: 5, CRITICAL: 6, OFF: 0 };
for (const [name, value] of Object.entries(LogLevel)) LogLevel[value] = name;
exports.LogLevel = LogLevel;

class PhotoApi {
  constructor() {
    return new Proxy(this, {
      get(target, prop) {
        if (prop in target || typeof prop === "symbol") return target[prop];
        return (...args) => {
          const onError = args.reverse().find((a) => typeof a === "function");
          const message = `ai-desktop: ${String(prop)} is not available on Linux`;
          if (onError) onError(message);
          return Promise.reject(new Error(message));
        };
      },
    });
  }
}
exports.PhotoApi = PhotoApi;
