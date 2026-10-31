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

    // MARK: - Private Methods

    private func localized(_ key: String, count: Int, locale: String) -> String {
        guard
            let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return "missing \(locale)" }

        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String.localizedStringWithFormat(format, count)
    }

}
