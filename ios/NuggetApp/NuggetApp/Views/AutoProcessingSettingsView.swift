import SwiftUI

struct AutoProcessingSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode

    @State private var isEnabled: Bool = false
    @State private var frequency: ProcessingFrequency = .daily
    @State private var preferredTime: Date = Date()
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showUpgradePrompt: Bool = false
    @State private var nextScheduledRun: String = ""
    @State private var isSaving: Bool = false

    enum ProcessingFrequency: String, CaseIterable {
        case daily = "Daily"
        case twiceDaily = "Twice Daily"
        case weekly = "Weekly"

        var apiValue: String {
            switch self {
            case .daily: return "daily"
            case .twiceDaily: return "twice_daily"
            case .weekly: return "weekly"
            }
        }

        static func from(_ apiValue: String) -> ProcessingFrequency {
            switch apiValue {
            case "daily": return .daily
            case "twice_daily": return .twiceDaily
            case "weekly": return .weekly
            default: return .daily
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)

                            Text("Auto-Processing")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Automatically process and summarize your saved nuggets on a schedule")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)

                        // Settings
                        VStack(spacing: 20) {
                            // Enable/Disable Toggle
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $isEnabled) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Enable Auto-Processing")
                                            .font(.headline)
                                        Text("Premium feature")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .disabled(isSaving || !isPremiumUser())
                                .onChange(of: isEnabled) { newValue in
                                    if newValue && !isPremiumUser() {
                                        showUpgradePrompt = true
                                        isEnabled = false
                                    }
                                }

                                if !isPremiumUser() {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(.yellow)
                                        Text("Requires Premium subscription")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)

                            if isEnabled {
                                // Frequency Picker
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Frequency")
                                        .font(.headline)

                                    Picker("Frequency", selection: $frequency) {
                                        ForEach(ProcessingFrequency.allCases, id: \.self) { freq in
                                            Text(freq.rawValue).tag(freq)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())

                                    Text(frequencyDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)

                                // Time Picker
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Preferred Time")
                                        .font(.headline)

                                    DatePicker(
                                        "Processing Time",
                                        selection: $preferredTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .labelsHidden()

                                    Text("Nuggets will be processed at this time in your local timezone")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)

                                // Next Run Info
                                if !nextScheduledRun.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "clock")
                                                .foregroundColor(.blue)
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
                            }
                        }
                        .padding(.horizontal)

                        // Save Button
                        Button(action: saveSchedule) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Save Schedule")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isPremiumUser() ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isSaving || !isPremiumUser())
                        .padding(.horizontal)
                        .padding(.top, 8)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitle("Auto-Processing", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
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
        }
    }

    private var frequencyDescription: String {
        switch frequency {
        case .daily:
            return "Processes your nuggets once per day at your preferred time"
        case .twiceDaily:
            return "Processes your nuggets twice per day (12 hours apart)"
        case .weekly:
            return "Processes your nuggets once per week on Monday"
        }
    }

    private func isPremiumUser() -> Bool {
        let tier = authService.currentUser?.subscriptionTier ?? "free"
        return tier == "plus" || tier == "pro"
    }

    private func loadCurrentSchedule() {
        // In a real implementation, this would fetch the current schedule from the API
        // For now, we'll use default values
        isLoading = true

        // TODO: Implement API call to fetch current schedule
        // This would call GET /v1/processing/schedule or similar

        isLoading = false
    }

    private func saveSchedule() {
        guard isPremiumUser() else {
            showUpgradePrompt = true
            return
        }

        isSaving = true

        Task {
            do {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                let timeString = timeFormatter.string(from: preferredTime)

                let timezone = TimeZone.current.identifier

                let request = SetProcessingScheduleRequest(
                    enabled: isEnabled,
                    frequency: isEnabled ? frequency.apiValue : nil,
                    preferredTime: isEnabled ? timeString : nil,
                    timezone: isEnabled ? timezone : nil
                )

                let response = try await ProcessingService.shared.setSchedule(request: request)

                await MainActor.run {
                    isSaving = false

                    if let nextRun = response.schedule?.nextRun {
                        nextScheduledRun = formatNextRun(nextRun)
                    }

                    // Show success feedback
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

// Placeholder for upgrade prompt view
struct UpgradePromptView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)

                Text("Premium Feature")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Auto-Processing is available for Premium subscribers. Upgrade to automatically process and summarize your saved content on a schedule.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    FeatureRow(icon: "sparkles", text: "Automatic daily processing")
                    FeatureRow(icon: "brain", text: "Smart category-based grouping")
                    FeatureRow(icon: "bell", text: "Push notifications when ready")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Priority support")
                }
                .padding()

                Button(action: {
                    // TODO: Navigate to subscription/upgrade flow
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Upgrade to Premium")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
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
                .foregroundColor(.blue)
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
