import SwiftUI

// MARK: - COPPA Compliance Checklist View
struct COPPAComplianceChecklistView: View {
    let team: Team
    @Environment(\.presentationMode) var presentationMode
    @State private var checklistItems: [COPPAChecklistItem] = []
    @State private var completedItems: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Progress Bar
                progressSection
                
                // Checklist
                List {
                    ForEach(COPPACategory.allCases, id: \.self) { category in
                        let categoryItems = checklistItems.filter { $0.category == category }
                        if !categoryItems.isEmpty {
                            Section(category.rawValue) {
                                ForEach(categoryItems) { item in
                                    ChecklistItemView(
                                        item: item,
                                        isCompleted: completedItems.contains(item.id),
                                        onToggle: { toggleItem(item) }
                                    )
                                }
                            }
                        }
                    }
                    
                    complianceSummarySection
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("COPPA Compliance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadChecklistItems()
                evaluateCompliance()
            }
        }
    }
    
    // MARK: - View Sections
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("COPPA Compliance Checklist")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Ensure your team management meets privacy requirements")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Compliance Progress")
                    .font(.headline)
                Spacer()
                Text("\(completedItems.count)/\(checklistItems.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(isFullyCompliant ? .green : .orange)
            }
            
            ProgressView(value: Double(completedItems.count), total: Double(checklistItems.count))
                .progressViewStyle(LinearProgressViewStyle(tint: isFullyCompliant ? .green : .orange))
            
            Text(complianceStatusText)
                .font(.caption)
                .foregroundColor(isFullyCompliant ? .green : .orange)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var complianceSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: isFullyCompliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isFullyCompliant ? .green : .orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isFullyCompliant ? "COPPA Compliant" : "Action Required")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isFullyCompliant ? .green : .orange)
                        
                        Text(isFullyCompliant ? "Your team management meets COPPA requirements" : "Complete remaining items for full compliance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if isFullyCompliant {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Implied consent model implemented")
                        Text("✅ Coach responsibility acknowledged")
                        Text("✅ Parent notification completed")
                        Text("✅ Privacy protections in place")
                        Text("✅ Data minimization practices followed")
                        Text("✅ Automatic data deletion configured")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Compliance Summary")
        }
    }
    
    // MARK: - Computed Properties
    private var isFullyCompliant: Bool {
        return completedItems.count == checklistItems.count
    }
    
    private var complianceStatusText: String {
        if isFullyCompliant {
            return "✅ Fully COPPA Compliant"
        } else {
            let remaining = checklistItems.count - completedItems.count
            return "⚠️ \(remaining) item\(remaining == 1 ? "" : "s") remaining"
        }
    }
    
    // MARK: - Helper Functions
    private func loadChecklistItems() {
        checklistItems = COPPAComplianceManager.shared.getCOPPAComplianceChecklist()
    }
    
    private func evaluateCompliance() {
        // Automatically mark items as completed based on team settings
        for item in checklistItems {
            switch item.category {
            case .coachResponsibility:
                if team.privacySettings.coachDataResponsibility {
                    completedItems.insert(item.id)
                }
            case .dataMinimization:
                // Always true for Coach Caddie's design
                completedItems.insert(item.id)
            case .dataRetention:
                // Always true - automatic deletion is built-in
                completedItems.insert(item.id)
            case .dataUse:
                // Always true - no commercial use
                completedItems.insert(item.id)
            case .parentNotification:
                // This needs to be manually checked by coach
                break
            case .parentRights:
                // Always true - coach contact info is available
                completedItems.insert(item.id)
            }
        }
    }
    
    private func toggleItem(_ item: COPPAChecklistItem) {
        if completedItems.contains(item.id) {
            completedItems.remove(item.id)
        } else {
            completedItems.insert(item.id)
        }
    }
}

// MARK: - Checklist Item View
struct ChecklistItemView: View {
    let item: COPPAChecklistItem
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}
