/*
 * Copyright 2026, gRPC Authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

struct MissingPKIFileError: Error, CustomStringConvertible {
  var path: String

  var description: String {
    "Expected to find \(path), but it doesn't exist. Run `swift run tls-hello-world generate` "
      + "to create the demo certificates (with matching --pki-directory/--client-id options, "
      + "if you passed any)."
  }
}

func requirePKIFilesExist(_ paths: [URL]) throws {
  for path in paths where !FileManager.default.fileExists(atPath: path.path) {
    throw MissingPKIFileError(path: path.path)
  }
}
