//
//  OutputLineSplitterTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 03/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Standard output split into lines as it arrives (C34): `xcodebuild` redraws its progress with
/// `\r`, so a line ends at "\n", "\r" or "\r\n", and a line cut between two reads waits for the rest.
struct OutputLineSplitterTests {

    // MARK: - Public Methods

    @Test(arguments: [
        ("a\nb\n", ["a", "b"]),
        ("a\rb\r", ["a", "b"]),
        ("a\r\nb\r\n", ["a", "b"]),
        ("a\r\r\nb", ["a"]),
        ("\r\n\n\ra\n\n", ["a"]),
    ])
    func splitsAtNewlinesAndReturnsAndDropsEmptyLines(text: String, lines: [String]) {
        var splitter = OutputLineSplitter()

        #expect(splitter.append(Data(text.utf8)) == lines)
    }

    @Test
    func keepsALineCutBetweenTwoReadsUntilItEnds() {
        var splitter = OutputLineSplitter()

        #expect(splitter.append(Data("Downloading 0,1% (3,6".utf8)).isEmpty)
        #expect(splitter.append(Data(" MB of 3,76 GB)\rDone".utf8)) == ["Downloading 0,1% (3,6 MB of 3,76 GB)"])
        #expect(splitter.finish() == ["Done"])
        #expect(splitter.finish().isEmpty, "The partial line is handed over once.")
    }

    @Test
    func finishingWithNothingPendingHandsNothingOver() {
        var splitter = OutputLineSplitter()

        _ = splitter.append(Data("a\n".utf8))

        #expect(splitter.finish().isEmpty)
    }

    @Test
    func rebuildsACharacterCutBetweenTwoReads() throws {
        var splitter = OutputLineSplitter()

        let bytes = Array("Instalação\n".utf8)
        let cut = try #require(bytes.firstIndex(of: 0xC3)) + 1

        let first = splitter.append(Data(bytes[..<cut]))
        let second = splitter.append(Data(bytes[cut...]))

        #expect(first.isEmpty)
        #expect(second == ["Instalação"])
    }

    @Test
    func replacesInvalidBytesInsteadOfFailing() {
        var splitter = OutputLineSplitter()

        #expect(splitter.append(Data([0x61, 0xFF, 0x62, 0x0A])) == ["a\u{FFFD}b"])
    }

    @Test
    func aLineLongerThanTheLimitIsHandedOverAndTheBufferEmptied() {
        var splitter = OutputLineSplitter()

        let limit = OutputLineSplitter.maximumLineLength

        let lines = splitter.append(Data(repeating: 0x78, count: 20 * 1_024))

        #expect(limit == 16_384)
        #expect(lines.map(\.utf8.count) == [limit])
        #expect(splitter.finish().map(\.utf8.count) == [20 * 1_024 - limit])
        #expect(splitter.append(Data("next\n".utf8)) == ["next"])
    }

    @Test
    func keepsTheTrailingSpacesThatPadARedrawnLine() {
        var splitter = OutputLineSplitter()

        #expect(splitter.append(Data("0,7% (26 MB of 3,76 GB)  \r".utf8)) == ["0,7% (26 MB of 3,76 GB)  "])
    }

    /// The real output ends with "Download was cancelled." and no newline: only `finish()` hands it over.
    @Test
    func theRealOutputSplitsIntoItsLines() throws {
        var splitter = OutputLineSplitter()

        let sample = try RuntimeDownloadOutputFixture.tvOSSample()

        let lines = splitter.append(sample)

        #expect(lines.count == 28)
        #expect(lines.first == "Finding content...")
        #expect(lines.last?.hasPrefix("Downloading tvOS 27.2 Simulator") == true)
        #expect(splitter.finish() == ["Download was cancelled."])
    }

    /// Guards the copy of the real sample: an editor that rewrote the `\r` would break the tests.
    @Test
    func theRealSampleIsCopiedByteForByte() throws {
        let sample = try RuntimeDownloadOutputFixture.tvOSSample()

        #expect(sample.count == RuntimeDownloadOutputFixture.byteCount)
        #expect(sample.count { $0 == 0x0D } == RuntimeDownloadOutputFixture.carriageReturnCount)
        #expect(sample.count { $0 == 0x0A } == RuntimeDownloadOutputFixture.newlineCount)
    }

}
