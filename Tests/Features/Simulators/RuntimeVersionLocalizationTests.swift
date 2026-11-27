//
//  RuntimeVersionLocalizationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The texts of the runtime versions are translated, and the sheet's old message is gone (C35, AC18).
struct RuntimeVersionLocalizationTests {

    // MARK: - Public Methods

    @Test(arguments: [
        ("%@ (Xcode)", "27.2 (Xcode)"),
        ("Xcode version", "Versão do Xcode"),
        ("%@ version", "Versão do iOS"),
        ("Loading earlier versions…", "Carregando versões anteriores…"),
        (
            "Earlier versions are unavailable right now. You can still download the version that matches Xcode.",
            "As versões anteriores não estão disponíveis agora. Você ainda pode baixar a versão do Xcode."
        ),
        (
            """
            Earlier versions help you test on older systems. If Xcode doesn't accept a version, the download \
            fails without downloading anything.
            """,
            "Versões anteriores servem para testar em sistemas mais antigos. Se o Xcode não aceitar uma versão, "
                + "o download falha sem baixar nada."
        ),
        ("Not available for the selected Xcode", "Indisponível para o Xcode selecionado"),
        (
            """
            Choose the platforms and, if you want, an earlier version. CleanerXcode downloads one at a time. \
            Each one is several GB.
            """,
            "Escolha as plataformas e, se quiser, uma versão anterior. O CleanerXcode baixa uma de cada vez. "
                + "Cada uma tem vários GB."
        ),
    ])
    func theVersionTextsAreTranslated(key: String, portuguese: String) {
        let argument = key == "%@ (Xcode)" ? "27.2" : "iOS"

        #expect(localized(key, argument: argument, locale: "pt-BR") == portuguese)

        // "27.2 (Xcode)" reads the same in both languages.
        if key != "%@ (Xcode)" {
            #expect(localized(key, argument: argument, locale: "en") != portuguese)
        }
    }

    @Test
    func theOldMessageIsGone() {
        let key = """
        Choose the platforms. CleanerXcode downloads the runtime that matches the selected Xcode, one at a \
        time. Each one is several GB.
        """

        #expect(localized(key, argument: "", locale: "pt-BR") == key)
    }

    // MARK: - Private Methods

    private func localized(_ key: String, argument: String, locale: String) -> String {
        guard
            let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return "missing \(locale)" }

        let format = bundle.localizedString(forKey: key, value: nil, table: nil)

        return format.contains("%@") ? String.localizedStringWithFormat(format, argument) : format
    }

}
