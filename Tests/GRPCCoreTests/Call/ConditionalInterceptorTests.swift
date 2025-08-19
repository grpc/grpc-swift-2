/*
 * Copyright 2024, gRPC Authors All rights reserved.
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

import GRPCCore
import Testing

@Suite("ConditionalInterceptor")
struct ConditionalInterceptorTests {
  @Test(
    "Applies to all, services and methods",
    arguments: [
      (
        .all,
        [.fooBar, .fooBaz, .barFoo, .barBaz],
        []
      ),
      (
        .services([ServiceDescriptor(package: "pkg", service: "foo")]),
        [.fooBar, .fooBaz],
        [.barFoo, .barBaz]
      ),
      (
        .methods([.barFoo]),
        [.barFoo],
        [.fooBar, .fooBaz, .barBaz]
      ),
    ] as [(ConditionalInterceptor<any Sendable>.Subject, [MethodDescriptor], [MethodDescriptor])]
  )
  @available(gRPCSwift 2.0, *)
  func appliesTo(
    target: ConditionalInterceptor<any Sendable>.Subject,
    applicableMethods: [MethodDescriptor],
    notApplicableMethods: [MethodDescriptor]
  ) {
    for applicableMethod in applicableMethods {
      #expect(target.applies(to: applicableMethod))
    }

    for notApplicableMethod in notApplicableMethods {
      #expect(!target.applies(to: notApplicableMethod))
    }
  }

  @Test(
    "Applies to only and allExcluding",
    arguments: [
      (
        .only(services: [.foo], methods: [.barFoo]),
        [.fooBar, .fooBaz, .barFoo],
        [.barBaz]
      ),
      (
        .allExcluding(services: [.foo], methods: [.barFoo]),
        [.barBaz],
        [.fooBar, .fooBaz, .barFoo]
      ),
    ] as [(ConditionalInterceptor<any Sendable>.Subject, [MethodDescriptor], [MethodDescriptor])]
  )
  @available(gRPCSwift 2.2, *)
  func appliesToOnlyAndAllExcluding(
    target: ConditionalInterceptor<any Sendable>.Subject,
    applicableMethods: [MethodDescriptor],
    notApplicableMethods: [MethodDescriptor]
  ) {
    for applicableMethod in applicableMethods {
      #expect(target.applies(to: applicableMethod))
    }

    for notApplicableMethod in notApplicableMethods {
      #expect(!target.applies(to: notApplicableMethod))
    }
  }

  @Test("Applies to all matching")
  @available(gRPCSwift 2.2, *)
  func appliesToAllMatching() {
    let target = ConditionalInterceptor<any Sendable>.Subject.allMatching { descriptor in
      descriptor.method == "baz"
    }
    let applicableMethods: [MethodDescriptor] = [.fooBaz, .barBaz]
    let notApplicableMethods: [MethodDescriptor] = [.fooBar, .barFoo]

    for applicableMethod in applicableMethods {
      #expect(target.applies(to: applicableMethod))
    }

    for notApplicableMethod in notApplicableMethods {
      #expect(!target.applies(to: notApplicableMethod))
    }
  }
}

@available(gRPCSwift 2.2, *)
extension ServiceDescriptor {
  fileprivate static let foo = Self(fullyQualifiedService: "pkg.foo")
  fileprivate static let bar = Self(fullyQualifiedService: "pkg.bar")
}

@available(gRPCSwift 2.0, *)
extension MethodDescriptor {
  fileprivate static let fooBar = Self(fullyQualifiedService: "pkg.foo", method: "bar")
  fileprivate static let fooBaz = Self(fullyQualifiedService: "pkg.foo", method: "baz")
  fileprivate static let barFoo = Self(fullyQualifiedService: "pkg.bar", method: "foo")
  fileprivate static let barBaz = Self(fullyQualifiedService: "pkg.bar", method: "baz")
}
