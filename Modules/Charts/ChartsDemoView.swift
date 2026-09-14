//
//  ChartsDemoView.swift
//
//  PRO feature — Swift Charts.
//  Self-contained: delete the `Modules/Charts` folder and flip
//  `featureFlags.charts` off to remove this feature entirely.
//

import SwiftUI
import Charts

// MARK: - Sample data

/// A single labelled data point. Replace `ChartSample` with your own model.
struct ChartPoint: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: Double
}

enum ChartSample {
    /// 7-day series (e.g. daily active users).
    static let weekly: [ChartPoint] = [
        .init(label: "Mon", value: 32),
        .init(label: "Tue", value: 48),
        .init(label: "Wed", value: 41),
        .init(label: "Thu", value: 67),
        .init(label: "Fri", value: 59),
        .init(label: "Sat", value: 85),
        .init(label: "Sun", value: 73)
    ]

    /// Category breakdown (e.g. revenue by plan).
    static let categories: [ChartPoint] = [
        .init(label: "Free", value: 120),
        .init(label: "Pro", value: 86),
        .init(label: "Team", value: 54),
        .init(label: "Lifetime", value: 38)
    ]

    static var total: Double { weekly.reduce(0) { $0 + $1.value } }
    static var peak: Double { weekly.map(\.value).max() ?? 0 }
    static var average: Double { weekly.isEmpty ? 0 : total / Double(weekly.count) }
}

// MARK: - Chart kinds

private enum ChartKind: String, CaseIterable, Identifiable {
    case line = "Line"
    case bar = "Bar"
    case area = "Area"
    var id: String { rawValue }
}

// MARK: - View

struct ChartsDemoView: View {
    @State private var kind: ChartKind = .line

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                statsRow

                Picker("Chart style", selection: $kind) {
                    ForEach(ChartKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                chartCard

                categoryCard
            }
            .padding(DS.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Text("charts.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: DS.Spacing.md) {
            stat(title: "charts.stat.total", value: "\(Int(ChartSample.total))", systemImage: "sum")
            stat(title: "charts.stat.peak", value: "\(Int(ChartSample.peak))", systemImage: "arrow.up.right")
            stat(title: "charts.stat.avg", value: "\(Int(ChartSample.average))", systemImage: "chart.bar.fill")
        }
    }

    private func stat(title: LocalizedStringKey, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Image(systemName: systemImage)
                .foregroundColor(DS.accent)
            Text(value)
                .appFont(.title2)
            Text(title)
                .appFont(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardContent(padding: DS.Spacing.md)
    }

    // MARK: Main chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("charts.weekly.title")
                .appFont(.headline)
            Text("charts.weekly.subtitle")
                .appFont(.footnote)
                .foregroundColor(.secondary)

            Chart(ChartSample.weekly) { point in
                switch kind {
                case .line:
                    LineMark(x: .value("Day", point.label), y: .value("Value", point.value))
                        .foregroundStyle(DS.accent)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Day", point.label), y: .value("Value", point.value))
                        .foregroundStyle(DS.accent)
                case .bar:
                    BarMark(x: .value("Day", point.label), y: .value("Value", point.value))
                        .foregroundStyle(DS.primary.gradient)
                        .cornerRadius(DS.Radius.xs)
                case .area:
                    AreaMark(x: .value("Day", point.label), y: .value("Value", point.value))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DS.accent.opacity(0.5), DS.accent.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", point.label), y: .value("Value", point.value))
                        .foregroundStyle(DS.accent)
                        .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 220)
            .animation(.easeInOut(duration: DS.Motion.normal), value: kind)
        }
        .dsCardContent()
    }

    // MARK: Category breakdown

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("charts.breakdown.title")
                .appFont(.headline)

            Chart(ChartSample.categories) { point in
                BarMark(
                    x: .value("Value", point.value),
                    y: .value("Category", point.label)
                )
                .foregroundStyle(DS.primary.gradient)
                .cornerRadius(DS.Radius.xs)
                .annotation(position: .trailing) {
                    Text("\(Int(point.value))")
                        .appFont(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 200)
        }
        .dsCardContent()
    }
}

#Preview {
    NavigationStack { ChartsDemoView() }
}
