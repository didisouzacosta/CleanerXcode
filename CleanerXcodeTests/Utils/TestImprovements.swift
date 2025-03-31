//
//  TestImprovements.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

func waitUntil(
    _ condition: @escaping () -> Bool,
    check: @escaping () -> Void = {}
) {
    repeat {
        check()
    } while !condition()
}
