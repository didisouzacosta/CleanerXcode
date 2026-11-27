//
//  LocalizedPluralTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Counts that can be zero read naturally: Portuguese puts 0 in the "one" category, so without a
/// `zero` form it would say "0 simulador depende" (AC18).
struct LocalizedPluralTests {

    // MARK: - Public Methods

    @Test(arguments: [
        ("%lld simulators depend on it", "nenhum simulador depende dele", "no simulators depend on it"),
        (
            "%lld categories finished before cancelling",
            "nenhuma categoria concluída antes de cancelar",
            "no categories finished before cancelling"
        ),
        ("%lld categories cleaned", "nenhuma categoria limpa", "no categories cleaned"),
        ("%lld runtimes", "nenhum runtime", "no runtimes"),
        ("%lld simulators", "nenhum simulador", "no simulators"),
        ("%lld duplicates", "nenhum duplicado", "no duplicates"),
    ])
    func zeroHasItsOwnWording(key: String, portuguese: String, english: String) {
        #expect(localized(key, count: 0, locale: "pt-BR") == portuguese)
        #expect(localized(key, count: 0, locale: "en") == english)
    }

    @Test
    func oneAndManyKeepTheirForms() {
        #expect(localized("%lld simulators depend on it", count: 1, locale: "pt-BR") == "1 simulador depende")
        #expect(localized("%lld simulators depend on it", count: 3, locale: "pt-BR") == "3 simuladores dependem")
        #expect(localized("%lld simulators depend on it", count: 1, locale: "en") == "1 simulator depends on it")
    }

    /// The runtime download sheet and card (C30, A1); these are never used with 0.
    @Test(arguments: [
        ("%lld selected", "1 selecionado", "2 selecionados", "1 selected", "2 selected"),
        (
            "Download %lld runtimes",
            "Baixar 1 runtime",
            "Baixar 2 runtimes",
            "Download 1 runtime",
            "Download 2 runtimes"
        ),
        (
            "%lld runtimes installed",
            "1 runtime instalado",
            "2 runtimes instalados",
            "1 runtime installed",
            "2 runtimes installed"
        ),
    ])
    func runtimeDownloadCountsHaveOneAndManyForms(
        key: String,
        portugueseOne: String,
        portugueseMany: String,
        englishOne: String,
        englishMany: String
    ) {
        #expect(localized(key, count: 1, locale: "pt-BR") == portugueseOne)
        #expect(localized(key, count: 2, locale: "pt-BR") == portugueseMany)
        #expect(localized(key, count: 1, locale: "en") == englishOne)
        #expect(localized(key, count: 2, locale: "en") == englishMany)
    }

    /// The verb agrees with the first number, the runtimes that were not downloaded.
    @Test
    func theFailedRuntimesAgreeWithTheirCount() {
        let key = "%lld of %lld runtimes were not downloaded"

        #expect(localized(key, counts: [1, 3], locale: "pt-BR") == "1 de 3 runtimes não foi baixado")
        #expect(localized(key, counts: [2, 3], locale: "pt-BR") == "2 de 3 runtimes não foram baixados")
        #expect(localized(key, counts: [1, 3], locale: "en") == "1 of 3 runtimes was not downloaded")
        #expect(localized(key, counts: [2, 3], locale: "en") == "2 of 3 runtimes were not downloaded")
    }

    // MARK: - Private Methods

    private func localized(_ key: String, counts: [Int], locale: String) -> String {
        guard
            let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return "missing \(locale)" }

        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String.localizedStringWithFormat(format, counts[0], counts[1])
    }

    private func localized(_ key: String, count: Int, locale: String) -> String {
        guard
            let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return "missing \(locale)" }

        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String.localizedStringWithFormat(format, count)
    }

}
