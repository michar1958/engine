// Copyright 2018 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_LIB_UI_CALLBACK_CACHE_H_
#define FLUTTER_LIB_UI_CALLBACK_CACHE_H_

#include <map>
#include <memory>
#include <mutex>
#include <string>

#include "flutter/fml/macros.h"
#include "flutter/fml/synchronization/thread_annotations.h"
#include "third_party/dart/runtime/include/dart_api.h"

#define DART_CALLBACK_INVALID_HANDLE -1

namespace blink {

typedef struct {
  std::string name;
  std::string class_name;
  std::string library_path;
} DartCallbackRepresentation;

class DartCallbackCache {
 public:
  static int64_t GetCallbackHandle(const std::string& name,
                                   const std::string& class_name,
                                   const std::string& library_path)
      FML_LOCKS_EXCLUDED(mutex_);

  static Dart_Handle GetCallback(int64_t handle) FML_LOCKS_EXCLUDED(mutex_);

  static std::unique_ptr<DartCallbackRepresentation> GetCallbackInformation(
      int64_t handle) FML_LOCKS_EXCLUDED(mutex_);

 private:
  static Dart_Handle LookupDartClosure(const std::string& name,
                                       const std::string& class_name,
                                       const std::string& library_path);

  static std::mutex mutex_;

  static std::map<int64_t, DartCallbackRepresentation> cache_
      FML_GUARDED_BY(mutex_);

  FML_DISALLOW_IMPLICIT_CONSTRUCTORS(DartCallbackCache);
};

}  // namespace blink

#endif  // FLUTTER_LIB_UI_CALLBACK_CACHE_H_
