import SwiftUI

struct AutoProcessingSettingsView: View {
    @EnvironmentObject var authService: AuthService

    @State private var isEnabled: Bool = false
    @State private var selectedInterval: ProcessingInterval = .every4Hours
    @State private var isLoading: Bool = true
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showUpgradePrompt: Bool = false
    @State private var nextScheduledRun: String = ""
    @State private var isSaving: Bool = false

    private var userTier: String {
        authService.currentUser?.subscriptionTier ?? "free"
    }

    private var isProUser: Bool {
        userTier == "pro"
    }

    private var isUltimateUser: Bool {
        userTier == "ultimate"
    }

    private var isPremiumUser: Bool {
        isProUser || isUltimateUser
    }

    var body: some View {
        if !isPremiumUser {
            PremiumFeatureGate(
                feature: "Smart Processing",
                description: "Automatically process your saved content on a schedule with AI-powered summaries.",
                icon: "sparkles.rectangle.stack",
                requiredTier: "Pro"
            )
        } else {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading schedule...")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Settings
                        VStack(spacing: 20) {
                            // Enable/Disable Toggle
                            enableToggleSection

                            if isEnabled && isPremiumUser {
                                if isProUser {
                                    proScheduleSection
                                } else if isUltimateUser {
                                    ultimateScheduleSection
                                }

                                // Next Run Info
                                if !nextScheduledRun.isEmpty {
                                    nextRunSection
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Saving indicator
                        if isSaving {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .navigationBarTitle("Smart Processing", displayMode: .inline)
        .onAppear {
            loadCurrentSchedule()
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptView()
        }
        } // end else (premium check)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(.primary)

            Text("Smart Processing")
                .font(.title2)
                .fontWeight(.bold)

            Text(headerDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }

    private var headerDescription: String {
        if isUltimateUser {
            return "Configure how often your saved content is automatically processed"
        } else if isProUser {
            return "Your saved content is processed 3 times daily at optimal times"
        } else {
            return "Automatically process and summarize your saved content on a schedule"
        }
    }

    // MARK: - Enable Toggle Section

    private var enableToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Smart Processing")
                        .font(.headline)
                    Text(tierBadgeText)
                        .font(.caption)
                        .foregroundColor(tierBadgeColor)
                }
            }
            .disabled(isSaving || !isPremiumUser)
            .onChange(of: isEnabled) { newValue in
                if newValue && !isPremiumUser {
                    showUpgradePrompt = true
                    isEnabled = false
                } else if isPremiumUser {
                    // Auto-save on toggle change for all premium users
                    if isProUser {
                        saveProSchedule()
                    } else if isUltimateUser {
                        saveSchedule()
                    }
                }
            }

            if !isPremiumUser {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.secondary)
                    Text("Requires Pro or Ultimate subscription")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var tierBadgeText: String {
        switch userTier {
        case "ultimate": return "Ultimate feature"
        case "pro": return "Pro feature"
        default: return "Premium feature"
        }
    }

    private var tierBadgeColor: Color {
        switch userTier {
        case "ultimate": return .purple
        case "pro": return .orange
        default: return .secondary
        }
    }

    // MARK: - Pro Schedule Section (Read-only)

    private var proScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Processing Schedule")
                    .font(.headline)
                Spacer()
                Text("Fixed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(6)
            }

            Text("Your saved content is automatically processed at these times:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ProcessingWindowRow(icon: "sunrise.fill", time: "7:30 AM", label: "Morning", color: .orange)
                ProcessingWindowRow(icon: "sun.max.fill", time: "1:30 PM", label: "Afternoon", color: .yellow)
                ProcessingWindowRow(icon: "sunset.fill", time: "7:30 PM", label: "Evening", color: .purple)
            }

            Text("Times are in your local timezone")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Ultimate Schedule Section (Configurable)

    private var ultimateScheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Processing Interval")
                    .font(.headline)
                Spacer()
                Text("Configurable")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)
            }

            Text("Choose how often your saved content is processed:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Interval Picker
            VStack(spacing: 8) {
                ForEach(ProcessingInterval.allCases) { interval in
                    IntervalOptionRow(
                        interval: interval,
                        isSelected: selectedInterval == interval,
                        onSelect: {
                            selectedInterval = interval
                            // Auto-save when interval changes
                            saveSchedule()
                        }
                    )
                }
            }

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Processing starts at midnight and repeats at your selected interval")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Next Run Section

    private var nextRunSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.primary)
                Text("Next Scheduled Run")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(nextScheduledRun)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - API Calls

    private func loadCurrentSchedule() {
        isLoading = true

        Task {
            do {
                let schedule = try await ProcessingService.shared.getSchedule()
                await MainActor.run {
                    isEnabled = schedule.enabled
                    if let intervalHours = schedule.intervalHours,
                       let interval = ProcessingInterval(rawValue: intervalHours) {
                        selectedInterval = interval
                    }
                    if let nextRun = schedule.nextRun {
                        nextScheduledRun = formatNextRun(nextRun)
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    // No existing schedule, use defaults
                    isLoading = false
                }
            }
        }
    }

    private func saveProSchedule() {
        isSaving = true

        Task {
            do {
                let timezone = TimeZone.current.identifier

                let request = SetProcessingScheduleRequest(
                    enabled: isEnabled,
                    frequency: nil,
                    preferredTime: nil,
                    timezone: isEnabled ? timezone : nil,
                    intervalHours: nil
                )

                let response = try await ProcessingService.shared.setSchedule(request: request)

                await MainActor.run {
                    isSaving = false

                    if let nextRun = response.schedule?.nextRun {
                        nextScheduledRun = formatNextRun(nextRun)
                    } else if !isEnabled {
                        nextScheduledRun = ""
                    }

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func saveSchedule() {
        guard isUltimateUser else {
            if isProUser {
                saveProSchedule()
            } else {
                showUpgradePrompt = true
            }
            return
        }

        isSaving = true

        Task {
            do {
                let timezone = TimeZone.current.identifier

                let request = SetProcessingScheduleRequest(
                    enabled: isEnabled,
                    frequency: isEnabled ? "interval" : nil,
                    preferredTime: nil,
                    timezone: isEnabled ? timezone : nil,
                    intervalHours: isEnabled ? selectedInterval.rawValue : nil
                )

                let response = try await ProcessingService.shared.setSchedule(request: request)

                await MainActor.run {
                    isSaving = false

                    if let nextRun = response.schedule?.nextRun {
                        nextScheduledRun = formatNextRun(nextRun)
                    }

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func formatNextRun(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct ProcessingWindowRow: View {
    let icon: String
    let time: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(time)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

struct IntervalOptionRow: View {
    let interval: ProcessingInterval
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(interval.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)

                    Text(interval.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.purple)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.purple.opacity(0.1) : Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Placeholder for upgrade prompt view
struct UpgradePromptView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("Premium Feature")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Smart Processing is available for Pro and Ultimate subscribers. Upgrade to automatically process and summarize your saved content on a schedule.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pro")
                        .font(.headline)
                        .foregroundColor(.orange)

                    VStack(spacing: 8) {
                        FeatureRow(icon: "clock.fill", text: "3x daily processing (morning, afternoon, evening)")
                        FeatureRow(icon: "bell.fill", text: "Push notifications when ready")
                    }

                    Divider()
                        .padding(.vertical, 8)

                    Text("Ultimate")
                        .font(.headline)
                        .foregroundColor(.purple)

                    VStack(spacing: 8) {
                        FeatureRow(icon: "slider.horizontal.3", text: "Configurable intervals (2-12 hours)")
                        FeatureRow(icon: "star.fill", text: "Priority processing")
                        FeatureRow(icon: "bell.badge.fill", text: "Advanced notification controls")
                    }
                }
                .padding()

                Button(action: {
                    // TODO: Navigate to subscription/upgrade flow
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("View Plans")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlassProminentButtonStyle())
                .padding(.horizontal)

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Maybe Later")
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct AutoProcessingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AutoProcessingSettingsView()
            .environmentObject(AuthService())
    }
}
