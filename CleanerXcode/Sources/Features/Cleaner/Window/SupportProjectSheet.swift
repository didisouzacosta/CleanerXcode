//
//  SupportProjectSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

import AppKit
import SwiftUI

/// "Support CleanerXcode" (C31, Figma 18:274): opened by "Support the project" on the success
/// that suggests a donation. "Donate any amount" opens the payment page and logs `donate` through
/// `onDonate`; "Not now" and Esc only close it. Purely visual: the window owns its state.
struct SupportProjectSheet: View {

    // MARK: - Environments

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    // MARK: - Public Properties

    let onDonate: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            SupportAppIcon()

            Text("Support CleanerXcode")
                .font(.system(size: 17, weight: .semibold))

            Text(
                "CleanerXcode is free and open source. Your donation, of any amount, goes a long way to keep the project going — and all of it goes to shelters and hospitals."
            )
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            SupportAmountChip()

            Button(action: donate) {
                Label {
                    Text("Donate any amount")
                } icon: {
                    Image(systemName: "heart.fill")
                        .accessibilityHidden(true)
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.support)
            .controlSize(.large)
            // The frame's 6 pt spacer plus one more 10 pt gap (Figma 18:274).
            .padding(.top, 16)

            Button("Not now", action: close)
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .keyboardShortcut(.cancelAction)

            Text("Secure payment by Stripe, in your browser. The app never sees your payment details.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 28, leading: 28, bottom: 20, trailing: 28))
        .frame(width: 400)
    }

    // MARK: - Private Methods

    private func donate() {
        openURL(Constants.donateURL)
        onDonate()
        dismiss()
    }

    private func close() {
        dismiss()
    }

}

/// The app icon with a pink heart badge on its corner.
private struct SupportAppIcon: View {

    // MARK: - Public Properties

    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 80, height: 80)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Palette.support, in: .circle)
                    .offset(x: 8, y: 8)
            }
            .frame(width: 84, height: 84, alignment: .topLeading)
            .accessibilityHidden(true)
    }

}

/// "Any amount · 100% goes to shelters and hospitals", in pink.
private struct SupportAmountChip: View {

    // MARK: - Public Properties

    var body: some View {
        Label {
            Text("Any amount · 100% goes to shelters and hospitals")
        } icon: {
            Image(systemName: "heart.fill")
                .accessibilityHidden(true)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Palette.support)
        .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .background(Palette.support.opacity(0.1), in: .capsule)
    }

}

#if DEBUG
    #Preview("Support sheet") {
        SupportProjectSheet {}
    }

    #Preview("Dark · Support sheet") {
        SupportProjectSheet {}
            .preferredColorScheme(.dark)
    }
#endif
