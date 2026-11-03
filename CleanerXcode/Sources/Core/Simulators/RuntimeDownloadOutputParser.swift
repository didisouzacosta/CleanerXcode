//
//  RuntimeDownloadOutputParser.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation

/// Reads a line of `xcodebuild -downloadPlatform` as a download step (C34). The output is not
/// documented: the real sample in the tests pins the format ("Downloading <runtime>: 0,7% (27,3 MB of
/// 3,76 GB)"), the numbers follow the user's locale, and a line it does not recognize gives `nil`, so
/// the card falls back to the indeterminate progress of the C30.
nonisolated enum RuntimeDownloadOutputParser {

    // MARK: - Private Properties

    private static let downloadingPrefix = "Downloading "
    private static let payloadSeparator = ": "

    // MARK: - Public Methods

    static func event(from line: String) -> RuntimeDownloadEvent? {
        let text = normalized(line)

        if text.hasPrefix("Finding content") {
            return .preparing
        }

        if text.hasPrefix("Done downloading") || text.hasPrefix("Beginning asset import") {
            return .installing
        }

        if text.hasPrefix("Done importing") {
            return .completed
        }

        guard text.hasPrefix(downloadingPrefix), let payload = payload(of: text) else { return nil }

        guard !payload.isEmpty, !payload.hasPrefix("Preparing") else { return .preparing }

        return progress(in: payload)
    }

    /// A number written with a decimal comma or point and optional thousands separators: with both
    /// marks, the single last one is the decimal; a lone mark followed by exactly 3 digits groups
    /// thousands ("1,234"); otherwise it is the decimal ("3,76"). Anything but digits gives `nil`.
    static func number(from text: String) -> Double? {
        let cleaned = text.filter { !" '\u{2019}".contains($0) }
        let marks = cleaned.filter(isMark)

        var integerPart = Substring(cleaned)
        var fractionPart: Substring = ""

        if let last = cleaned.lastIndex(where: isMark) {
            let mark = cleaned[last]

            var isDecimal = marks.count == 1 && cleaned.distance(from: last, to: cleaned.endIndex) != 4

            if Set(marks).count == 2 {
                guard marks.count(where: { $0 == mark }) == 1 else { return nil }

                isDecimal = true
            }

            if isDecimal {
                integerPart = cleaned[..<last]
                fractionPart = cleaned[cleaned.index(after: last)...]
            }
        }

        let digits = integerPart.filter { !isMark($0) }

        guard
            !digits.isEmpty,
            digits.allSatisfy(\.isASCIIDigit),
            fractionPart.allSatisfy(\.isASCIIDigit)
        else { return nil }

        return Double(fractionPart.isEmpty ? digits : "\(digits).\(fractionPart)")
    }

    // MARK: - Private Methods

    private static func isMark(_ character: Character) -> Bool {
        character == "," || character == "."
    }

    /// No-break spaces become spaces, and the ends are trimmed.
    private static func normalized(_ line: String) -> String {
        line
            .replacing("\u{00A0}", with: " ")
            .replacing("\u{202F}", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// What follows the last ": " (the runtime's name can hold parentheses); empty when the line
    /// ends at the colon.
    private static func payload(of text: String) -> String? {
        if let range = text.ranges(of: payloadSeparator).last {
            return String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        return text.hasSuffix(":") ? "" : nil
    }

    /// "0,7% (27,3 MB of 3,76 GB)": the percentage, then two amounts with units; the word between
    /// them is ignored, so a translated "of" still works.
    private static func progress(in payload: String) -> RuntimeDownloadEvent? {
        guard
            let percentSign = payload.firstIndex(of: "%"),
            let percent = number(from: payload[..<percentSign].trimmingCharacters(in: .whitespaces)),
            let open = payload[percentSign...].firstIndex(of: "("),
            let close = payload.lastIndex(of: ")"),
            open < close
        else { return nil }

        let amounts = amounts(in: payload[payload.index(after: open)..<close])

        guard
            let received = amounts.first,
            let total = amounts.last,
            amounts.count >= 2,
            total > 0,
            received <= total * 1.01,
            (0...100).contains(percent)
        else { return nil }

        guard percent < 100 else { return .installing }

        return .downloading(RuntimeDownloadAmount(
            fraction: min(percent / 100, 1),
            receivedBytes: Int64(received.rounded()),
            totalBytes: Int64(total.rounded())
        ))
    }

    /// Each number followed by a known unit, in bytes. Number tokens in a row form one number, so
    /// "1 234,5 MB" is read whole.
    private static func amounts(in text: Substring) -> [Double] {
        var amounts: [Double] = []

        var pending: [Substring] = []

        for token in text.split(separator: " ") {
            if token.first?.isASCIIDigit == true {
                pending.append(token)
                continue
            }

            guard !pending.isEmpty else { continue }

            guard let value = number(from: pending.joined(separator: " ")), let unit = multiplier(of: token) else {
                return []
            }

            amounts.append(value * unit)
            pending = []
        }

        return amounts
    }

    /// By the first letter: k, m, g, t, p; b ("B", "bytes") and o ("o", "octets") count bytes.
    private static func multiplier(of unit: Substring) -> Double? {
        switch unit.first?.lowercased() {
        case "k": 1e3
        case "m": 1e6
        case "g": 1e9
        case "t": 1e12
        case "p": 1e15
        case "b", "o": 1
        default: nil
        }
    }

}

nonisolated private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
