import Factory
import MabyKit
import StoreKit
import SwiftUI

/// Settings, rebuilt as glass cards rather than a system list so the tab keeps the
/// same material language as the rest of the app.
struct SettingsView: View {
    @Injected(Container.exportService) private var exporter
    @Injected(Container.reminderService) private var reminders

    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var preferences: AppPreferences

    @FetchRequest(fetchRequest: allBabies)
    private var babies: FetchedResults<Baby>

    @State private var showingEditBaby = false
    @State private var showingRemoveBaby = false
    @State private var showingManageSubscription = false
    @State private var exportURL: URL?
    @State private var notificationsDenied = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let release = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "v\(release) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                subscriptionCard
                babyCard
                appearanceCard
                remindersCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .softScrollEdges()
        .sheet(isPresented: $showingEditBaby) { EditBabyDetailsView() }
        .sheet(isPresented: $showingRemoveBaby) {
            RemoveBabyView()
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationCornerRadius(32)
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
        .sheet(item: Binding(
            get: { exportURL.map { ExportedFile(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )) { file in
            ExportShareSheet(url: file.url)
        }
        .alert("Notifications are turned off", isPresented: $notificationsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) { }
        } message: {
            Text("Reminders need notification permission. You can grant it in iOS Settings.")
        }
    }

    // MARK: - Subscription

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: subscriptions.isSubscribed ? "checkmark.seal.fill" : "sparkles")
                    .font(.title3)
                    .foregroundStyle(Palette.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subscriptions.isSubscribed ? "BabyPlus+ is active" : "BabyPlus+")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)

                    Text(subscriptionDetail)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 0)
            }

            if subscriptions.isInBillingRetry {
                Label(
                    "There's a problem with your payment method. Your subscription will lapse unless it's updated.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if subscriptions.isSubscribed {
                Button {
                    showingManageSubscription = true
                } label: {
                    Text("Manage subscription")
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyle()
            } else {
                Button {
                    paywall.present()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("See what's included").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .glassButtonStyle(prominent: true, tint: Palette.gold)

                Button {
                    Task { await subscriptions.restore() }
                } label: {
                    if subscriptions.isRestoring {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Restore purchases").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(Palette.brand)
            }
        }
        .glassCard(subscriptions.isSubscribed ? .tinted(Palette.gold.opacity(0.45)) : .regular)
        .overlay {
            if !subscriptions.isSubscribed {
                ShineOverlay().clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            }
        }
    }

    private var subscriptionDetail: String {
        if subscriptions.isSubscribed {
            if let renewal = subscriptions.renewalDate {
                return "Renews \(renewal.formatted(.dateTime.day().month().year()))"
            }
            return "Thank you for supporting a small app."
        }
        return "Insights, full history, exports, reminders and themes."
    }

    // MARK: - Baby

    private var babyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Baby")

            SettingsRow(
                title: "Edit details",
                subtitle: babies.first?.name ?? "No baby yet",
                systemImage: "person.text.rectangle.fill",
                tint: Palette.brand
            ) { showingEditBaby = true }

            SettingsRow(
                title: "Remove baby",
                subtitle: "Deletes every entry too",
                systemImage: "trash.fill",
                tint: .red
            ) { showingRemoveBaby = true }
        }
        .glassCard()
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Appearance", subtitle: "Tints the glass, the buttons and the charts") {
                if !subscriptions.isSubscribed { ProBadge(compact: true) }
            }

            HStack(spacing: 12) {
                ForEach(AccentTheme.allCases) { theme in
                    AccentSwatch(
                        theme: theme,
                        isSelected: preferences.accent == theme,
                        isLocked: theme.isPremium && !subscriptions.isUnlocked(.themes)
                    ) {
                        if theme.isPremium && !subscriptions.isUnlocked(.themes) {
                            paywall.present(for: .themes)
                        } else {
                            withAnimation(Motion.snappy) { preferences.accent = theme }
                            Haptics.selection()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .glassCard()
    }

    // MARK: - Reminders

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Reminders", subtitle: "Nudges you only when it has been too quiet") {
                if !subscriptions.isSubscribed { ProBadge(compact: true) }
            }

            if subscriptions.isUnlocked(.reminders) {
                ForEach(ReminderService.Kind.allCases) { kind in
                    ReminderToggle(
                        kind: kind,
                        isOn: Binding(
                            get: { preferences.isReminderEnabled(kind) },
                            set: { enable(kind, on: $0) }
                        ),
                        hours: Binding(
                            get: { preferences.reminderInterval(kind) },
                            set: { newValue in
                                preferences.setReminderInterval(kind, hours: newValue)
                                if preferences.isReminderEnabled(kind) {
                                    reminders.schedule(kind, inHours: newValue)
                                }
                            }
                        )
                    )
                }
            } else {
                ProUpsellRow(feature: .reminders)
            }
        }
        .glassCard()
    }

    private func enable(_ kind: ReminderService.Kind, on: Bool) {
        preferences.setReminder(kind, enabled: on)
        guard on else {
            reminders.cancel(kind)
            return
        }

        Task {
            let granted = await reminders.requestAuthorization()
            if granted {
                reminders.schedule(kind, inHours: preferences.reminderInterval(kind))
            } else {
                preferences.setReminder(kind, enabled: false)
                notificationsDenied = true
            }
        }
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Your data", subtitle: "Stored on your device and your private iCloud")

            if subscriptions.isUnlocked(.dataExport) {
                SettingsRow(
                    title: "Export as CSV",
                    subtitle: "Opens the share sheet",
                    systemImage: "square.and.arrow.up.fill",
                    tint: Palette.brand
                ) {
                    exportURL = try? exporter.writeCSV(babyName: babies.first?.name)
                    if exportURL != nil { Haptics.success() }
                }
            } else {
                ProUpsellRow(feature: .dataExport)
            }
        }
        .glassCard()
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(spacing: 10) {
            Text("BabyPlus \(version)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkSoft)

            Text("Made with \(Image(systemName: "heart.fill")) by Hussein, while using BabyPlus.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            HStack(spacing: 16) {
                Link("Privacy", destination: URL(string: "https://github.com/h-elbeheiry/babyplus/blob/main/PRIVACY.md")!)
                Text("·").foregroundStyle(Palette.inkSoft)
                Link("Source", destination: URL(string: "https://github.com/h-elbeheiry/babyplus")!)
            }
            .font(.caption)
            .tint(Palette.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - Rows

private struct SettingsRow: View {
    let title: LocalizedStringKey
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

private struct AccentSwatch: View {
    let theme: AccentTheme
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.color)
                    .frame(width: 34, height: 34)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(isSelected ? Palette.ink.opacity(0.5) : .clear, lineWidth: 2)
                    .frame(width: 44, height: 44)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct ReminderToggle: View {
    let kind: ReminderService.Kind
    @Binding var isOn: Bool
    @Binding var hours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isOn.animation(Motion.snappy)) {
                Text(kind.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.brand)

            if isOn {
                HStack {
                    Text("After \(hours.formatted(.number.precision(.fractionLength(hours == hours.rounded() ? 0 : 1)))) h")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 74, alignment: .leading)

                    Slider(value: $hours, in: 1...8, step: 0.5)
                        .tint(Palette.brand)
                }
                .transition(.rise)
            }
        }
    }
}

// MARK: - Sharing

private struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

#if DEBUG
#Preview {
    ZStack {
        AuroraBackground()
        SettingsView()
            .mockedDependencies()
            .environmentObject(SubscriptionService())
            .environmentObject(PaywallPresenter())
            .environmentObject(AppPreferences())
    }
}
#endif
