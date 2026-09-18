import SwiftUI

public struct RulesManagerView: View {
    @ObservedObject var rulesEngine: RulesEngine
    @Environment(\.dismiss) private var dismiss
    
    @State private var newRuleName: String = ""
    @State private var newRuleTarget: RuleMetricTarget = .cpuUsage
    @State private var newRuleOp: RuleOperator = .greaterThan
    @State private var newRuleThreshold: Double = 80.0
    @State private var newRuleSustainedSeconds: Int = 10
    @State private var newRuleThermal: String = "Serious"
    @State private var isAddingRule = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Title Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rules & Sustained Alerts")
                        .font(.headline)
                    Text("Alerts trigger only when a condition holds over time, eliminating spike noise.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            // Rules List
            List {
                ForEach(rulesEngine.rules) { rule in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { _ in rulesEngine.toggleRule(id: rule.id) }
                        ))
                        .labelsHidden()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(rule.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if rule.isTriggered {
                                    Text("TRIGGERED")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.2))
                                        .foregroundStyle(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(ruleDescription(rule))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            rulesEngine.deleteRule(id: rule.id)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            // Add Rule Footer
            if isAddingRule {
                VStack(alignment: .leading, spacing: 10) {
                    Text("New Rule Definition")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    HStack {
                        TextField("Rule Name", text: $newRuleName)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("Target", selection: $newRuleTarget) {
                            ForEach(RuleMetricTarget.allCases) { target in
                                Text(target.rawValue).tag(target)
                            }
                        }
                    }
                    
                    HStack {
                        Picker("Condition", selection: $newRuleOp) {
                            ForEach(RuleOperator.allCases) { op in
                                Text(op.rawValue).tag(op)
                            }
                        }
                        .frame(width: 80)
                        
                        if newRuleTarget == .thermalPressure {
                            Picker("Thermal State", selection: $newRuleThermal) {
                                Text("Fair").tag("Fair")
                                Text("Serious").tag("Serious")
                                Text("Critical").tag("Critical")
                            }
                        } else {
                            TextField("Threshold", value: $newRuleThreshold, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Hold for:")
                                .font(.caption)
                            TextField("Seconds", value: $newRuleSustainedSeconds, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            Text("sec")
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            isAddingRule = false
                        }
                        Spacer()
                        Button("Save Rule") {
                            let r = AlertRule(
                                name: newRuleName.isEmpty ? "\(newRuleTarget.rawValue) Rule" : newRuleName,
                                isEnabled: true,
                                target: newRuleTarget,
                                comparison: newRuleOp,
                                thresholdValue: newRuleThreshold,
                                thermalThreshold: newRuleThermal,
                                sustainedSeconds: newRuleSustainedSeconds
                            )
                            rulesEngine.addRule(r)
                            newRuleName = ""
                            isAddingRule = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                HStack {
                    Button {
                        isAddingRule = true
                    } label: {
                        Label("Add New Rule", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 480, height: 420)
    }
    
    private func ruleDescription(_ rule: AlertRule) -> String {
        let conditionStr: String
        if rule.target == .thermalPressure {
            conditionStr = "state is \(rule.thermalThreshold)"
        } else {
            conditionStr = "\(rule.comparison.rawValue) \(String(format: "%.0f", rule.thresholdValue))"
        }
        return "\(rule.target.rawValue) \(conditionStr) for at least \(rule.sustainedSeconds)s continuous"
    }
}
