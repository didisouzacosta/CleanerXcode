//
//  ObservationWaiting.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Observation

/// Waits until `condition` holds, woken by each change of the observable state it reads instead of
/// polling. Use it with `@Test(.timeLimit(…))`, so a condition that never holds fails the test.
func waitUntil(_ condition: @escaping () -> Bool) async {
    while !condition() {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = condition()
            } onChange: {
                continuation.resume()
            }
        }
    }
}
