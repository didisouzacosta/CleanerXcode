//
//  OutputLineSplitter.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation

/// Splits a command's output into lines as it arrives (C34). A line ends at "\n", "\r" or "\r\n",
/// because tools such as `xcodebuild` redraw their progress with "\r"; empty lines are dropped. A
/// line cut between two reads waits for the rest, and `finish()` hands over what is left at the end.
nonisolated struct OutputLineSplitter: Sendable {

    // MARK: - Public Properties

    /// A longer run of bytes without a separator is handed over as it is, so memory stays bounded.
    static let maximumLineLength = 16_384

    // MARK: - Private Properties

    private static let newline: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D

    private var pending: [UInt8] = []

    // MARK: - Private Static Methods

    /// Lossy UTF-8: each invalid sequence becomes U+FFFD instead of dropping the line.
    private static func decode(_ bytes: [UInt8]) -> String {
        var decoder = UTF8()
        var iterator = bytes.makeIterator()
        var scalars = String.UnicodeScalarView()

        while true {
            switch decoder.decode(&iterator) {
            case let .scalarValue(scalar):
                scalars.append(scalar)

            case .error:
                scalars.append("\u{FFFD}")

            case .emptyInput:
                return String(scalars)
            }
        }
    }

    // MARK: - Public Methods

    /// The lines completed by `data`. Separators never occur inside a multibyte UTF-8 sequence, so a
    /// character cut between two reads is rebuilt; invalid bytes become U+FFFD.
    mutating func append(_ data: Data) -> [String] {
        var lines: [String] = []

        for byte in data {
            if byte == Self.newline || byte == Self.carriageReturn {
                lines += flush()
                continue
            }

            pending.append(byte)

            if pending.count >= Self.maximumLineLength {
                lines += flush()
            }
        }

        return lines
    }

    /// The last line, when the output did not end with a separator.
    mutating func finish() -> [String] {
        flush()
    }

    // MARK: - Private Methods

    private mutating func flush() -> [String] {
        guard !pending.isEmpty else { return [] }

        defer { pending.removeAll(keepingCapacity: true) }

        return [Self.decode(pending)]
    }

}
