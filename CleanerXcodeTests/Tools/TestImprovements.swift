//
//  TestImprovements.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

func waitUntil(
    _ condition: @escaping () -> Bool,
    whileWaiting: @escaping () -> Void = {}
) {
    repeat {
        whileWaiting()
    } while !condition()
}
