//
//  StatisticsView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var period: StatsPeriod = .oneMonth
    @State private var selectedPoint: StatPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .padding(.horizontal, 20)
                .padding(.top, 12)

            let points = dataPoints
            VStack(alignment: .leading, spacing: 12) {
                Text("Track Progress")
                    .font(.system(size: 18, weight: .bold, design: .serif))

                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Distance", point.value)
                    )
                    .foregroundStyle(Color.black)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            Text(axisLabel(for: value.as(Date.self)))
                        }
                    }
                }
                .chartYScale(domain: 0...(points.map { $0.value }.max() ?? 1) * 1.2)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        ZStack {
                            Rectangle().fill(Color.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let plotFrame = geometry[proxy.plotAreaFrame]
                                            let x = value.location.x - plotFrame.origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                selectedPoint = closestPoint(to: date, in: points)
                                            }
                                        }
                                )

                            if let selectedPoint,
                               let xPosition = proxy.position(forX: selectedPoint.date),
                               let yPosition = proxy.position(forY: selectedPoint.value) {
                                let plotFrame = geometry[proxy.plotAreaFrame]
                                VStack(spacing: 4) {
                                    Text(selectedPoint.displayLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("\(String(format: "%.1f", selectedPoint.value)) mi")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                                )
                                .position(
                                    x: plotFrame.origin.x + xPosition,
                                    y: plotFrame.origin.y + max(12, yPosition - 28)
                                )
                            }
                        }
                    }
                }
                .frame(height: 240)

                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Average Calories")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("1000")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("cal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly Workout Average")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                Text("8")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                HStack(spacing: 16) {
                    statIconCount(type: .swim, count: 2)
                    statIconCount(type: .bike, count: 3)
                    statIconCount(type: .run, count: 3)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var dataPoints: [StatPoint] {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .oneMonth:
            guard let start = calendar.date(byAdding: .day, value: -29, to: now) else { return [] }
            return aggregate(by: .day, from: start, to: now)
        case .sixMonths:
            guard let start = calendar.date(byAdding: .month, value: -5, to: now) else { return [] }
            return aggregate(by: .month, from: start, to: now)
        case .oneYear:
            guard let start = calendar.date(byAdding: .year, value: -1, to: now) else { return [] }
            return aggregate(by: .month, from: start, to: now)
        case .all:
            guard let earliest = store.workouts.map({ $0.date }).min() else { return [] }
            return aggregate(by: .year, from: earliest, to: now)
        }
    }

    private func aggregate(by component: Calendar.Component, from start: Date, to end: Date) -> [StatPoint] {
        let calendar = Calendar.current
        var result: [StatPoint] = []
        var date = start
        while date <= end {
            let interval = calendar.dateInterval(of: component, for: date)
            let rangeStart = interval?.start ?? date
            let rangeEnd = interval?.end ?? date
            let total = store.workouts
                .filter { $0.date >= rangeStart && $0.date < rangeEnd }
                .reduce(0) { $0 + $1.distance }
            result.append(StatPoint(date: rangeStart, value: total, label: labelFor(date: rangeStart, component: component)))
            date = calendar.date(byAdding: component, value: 1, to: rangeStart) ?? end.addingTimeInterval(1)
        }
        return result
    }

    private func labelFor(date: Date, component: Calendar.Component) -> String {
        let formatter = DateFormatter()
        switch component {
        case .day:
            formatter.dateFormat = "M/d"
        case .month:
            formatter.dateFormat = "MMM"
        default:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }

    private func axisLabel(for date: Date?) -> String {
        guard let date else { return "" }
        switch period {
        case .oneMonth:
            return labelFor(date: date, component: .day)
        case .sixMonths, .oneYear:
            return labelFor(date: date, component: .month)
        case .all:
            return labelFor(date: date, component: .year)
        }
    }

    private func closestPoint(to date: Date, in points: [StatPoint]) -> StatPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func statIconCount(type: WorkoutType, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: type.systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.6))
    }
}

enum StatsPeriod: CaseIterable {
    case oneMonth
    case sixMonths
    case oneYear
    case all

    var label: String {
        switch self {
        case .oneMonth:
            return "1M"
        case .sixMonths:
            return "6M"
        case .oneYear:
            return "1Y"
        case .all:
            return "ALL"
        }
    }
}

struct StatPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String

    var displayLabel: String { label }
}
