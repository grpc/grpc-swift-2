/*
 * Copyright 2023, gRPC Authors All rights reserved.
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

private import Synchronization

/// A throttle used to rate-limit retries and hedging attempts.
///
/// gRPC prevents retries and hedging from overloading servers by using a token-based
/// throttling mechanism at the transport level.
///
/// Each client transport maintains a throttle for the server it is connected to, and gRPC records
/// successful and failed RPC attempts. Successful attempts increment the number of tokens
/// by ``tokenRatio`` and failed attempts decrement the available tokens by one. In the context
/// of throttling, a failed attempt is one where the server terminates the RPC with a status code
/// that is retryable or non-fatal (as defined by ``RetryPolicy/retryableStatusCodes`` and
/// ``HedgingPolicy/nonFatalStatusCodes``) or when the client receives a pushback response from
/// the server.
///
/// See also [gRFC A6: client retries](https://github.com/grpc/proposal/blob/0e1807a6e30a1a915c0dcadc873bca92b9fa9720/A6-client-retries.md).
@available(gRPCSwift 2.0, *)
public final class RetryThrottle: Sendable {
  // Note: only three figures after the decimal point from the original token ratio are used so
  //   all computation is done a scaled number of tokens (tokens * 1000). This allows us to do all
  //   computation in integer space.

  /// The number of tokens available, multiplied by 1000.
  private let scaledTokensAvailable: Mutex<Int>
  /// The number of tokens, multiplied by 1000.
  private let scaledTokenRatio: Int
  /// The maximum number of tokens, multiplied by 1000.
  private let scaledMaxTokens: Int
  /// The retry threshold, multiplied by 1000. If ``scaledTokensAvailable`` is above this then
  /// the throttle permits retries.
  private let scaledRetryThreshold: Int

  /// Returns the throttling token ratio.
  ///
  /// The throttle increments the number of tokens it holds by this value for each successful
  /// response. In the context of throttling, a successful response is one that:
  /// - receives metadata from the server, or
  /// - ends with a non-retryable or fatal status code.
  ///
  /// If the response is a pushback response, then it does not count as successful, even if it
  /// meets either of the preceding conditions.
  public var tokenRatio: Double {
    Double(self.scaledTokenRatio) / 1000
  }

  /// The maximum number of tokens the throttle may hold.
  public var maxTokens: Int {
    self.scaledMaxTokens / 1000
  }

  /// The number of tokens the throttle currently has.
  ///
  /// If this value is less than or equal to the retry threshold (defined as `maxTokens / 2`),
  /// then the throttle will not retry RPCs and will disable hedging.
  public var tokens: Double {
    self.scaledTokensAvailable.withLock {
      Double($0) / 1000
    }
  }

  /// Returns whether the throttle permits retries and hedging at this time.
  public var isRetryPermitted: Bool {
    self.scaledTokensAvailable.withLock {
      $0 > self.scaledRetryThreshold
    }
  }

  /// Creates a new throttle with explicit token limits.
  ///
  /// - Parameters:
  ///   - maxTokens: The maximum number of tokens available. Must be in the range `1...1000`.
  ///   - tokenRatio: The number of tokens to increment the available tokens by for successful
  ///       responses. See the documentation on this type for a description of what counts as a
  ///       successful response. Note that the throttle uses only three decimal places from this
  ///       value.
  /// - Precondition: `maxTokens` must be in the range `1...1000`.
  /// - Precondition: `tokenRatio` must be `>= 0.001`.
  public init(maxTokens: Int, tokenRatio: Double) {
    precondition(
      (1 ... 1000).contains(maxTokens),
      "maxTokens must be in the range 1...1000 (is \(maxTokens))"
    )

    let scaledTokenRatio = Int(tokenRatio * 1000)
    precondition(scaledTokenRatio > 0, "tokenRatio must be >= 0.001 (is \(tokenRatio))")

    let scaledTokens = maxTokens * 1000
    self.scaledMaxTokens = scaledTokens
    self.scaledRetryThreshold = scaledTokens / 2
    self.scaledTokenRatio = scaledTokenRatio
    self.scaledTokensAvailable = Mutex(scaledTokens)
  }

  /// Creates a new throttle configured from a retry-throttling policy.
  ///
  /// - Parameter policy: The policy to use to configure the throttle.
  public convenience init(policy: ServiceConfig.RetryThrottling) {
    self.init(maxTokens: policy.maxTokens, tokenRatio: policy.tokenRatio)
  }

  /// Records a success, adding a token to the throttle.
  @usableFromInline
  func recordSuccess() {
    self.scaledTokensAvailable.withLock { value in
      value = min(self.scaledMaxTokens, value &+ self.scaledTokenRatio)
    }
  }

  /// Records a failure, removing tokens from the throttle.
  /// - Returns: Whether the throttle will now limit retries.
  @usableFromInline
  @discardableResult
  func recordFailure() -> Bool {
    self.scaledTokensAvailable.withLock { value in
      value = max(0, value &- 1000)
      return value <= self.scaledRetryThreshold
    }
  }
}
