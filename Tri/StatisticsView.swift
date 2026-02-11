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
    @State private var period: StatsPeriod = .oneWeek
    @State private var selectedPoint: StatPoint?
    @State private var isInteracting = false
    @State private var dismissTask: DispatchWorkItem?

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

                Chart(clampedPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Distance", point.value)
                    )
                    .foregroundStyle(Color.black)
                    .interpolationMethod(.monotone) // .interpolationMethod(.catmullRom) Changed to remove dip below x-axis
                }
                .chartXAxis {
                    switch period {
                    case .oneWeek:
                        AxisMarks(values: points.map { $0.date }) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                Text(axisLabel(for: value.as(Date.self)))
                            }
                        }
                    case .oneMonth:
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                Text(axisLabel(for: value.as(Date.self)))
                            }
                        }
                    case .sixMonths, .oneYear:
                        AxisMarks(values: points.map { $0.date }) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                Text(axisLabel(for: value.as(Date.self)))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number = value.as(Double.self), number == 0 {
                                Text("0 (mi)")
                            } else if let number = value.as(Double.self) {
                                Text("\(Int(number))")
                            }
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
                                            isInteracting = true
                                            cancelDismiss()
                                        }
                                        .onEnded { _ in
                                            isInteracting = false
                                            scheduleDismiss()
                                        }
                                )

                            if let selectedPoint, isInteracting,
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
            .onChange(of: period) { _, _ in
                selectedPoint = nil
                isInteracting = false
                cancelDismiss()
            }

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
            .padding(.top, 8)

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
            .padding(.top, 6)

            Spacer()
        }
    }

    private var dataPoints: [StatPoint] {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .oneWeek:
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
            return aggregateByDay(from: weekStart, days: 7)
        case .oneMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
            return aggregateByDay(from: monthInterval.start, days: calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30)
        case .sixMonths:
            guard let start = calendar.date(byAdding: .month, value: -5, to: startOfMonth(now)) else { return [] }
            return aggregateByMonth(from: start, months: 6)
        case .oneYear:
            guard let start = calendar.date(byAdding: .month, value: -11, to: startOfMonth(now)) else { return [] }
            return aggregateByMonth(from: start, months: 12)
        }
    }

    private var clampedPoints: [StatPoint] {
        dataPoints.map { point in
            StatPoint(date: point.date, value: max(0, point.value), label: point.label)
        }
    }

    private func aggregateByDay(from start: Date, days: Int) -> [StatPoint] {
        var result: [StatPoint] = []
        var date = start
        for _ in 0..<days {
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            let total = store.workouts
                .filter { $0.date >= date && $0.date < dayEnd }
                .reduce(0) { $0 + distanceInMiles($1) }
            result.append(StatPoint(date: date, value: total, label: labelFor(date: date, component: .day)))
            date = dayEnd
        }
        return result
    }

    private func aggregateByMonth(from start: Date, months: Int) -> [StatPoint] {
        var result: [StatPoint] = []
        var date = start
        for _ in 0..<months {
            guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { break }
            let total = store.workouts
                .filter { $0.date >= interval.start && $0.date < interval.end }
                .reduce(0) { $0 + distanceInMiles($1) }
            result.append(StatPoint(date: interval.start, value: total, label: labelFor(date: interval.start, component: .month)))
            date = Calendar.current.date(byAdding: .month, value: 1, to: interval.start) ?? interval.end
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
        case .oneWeek:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        case .oneMonth:
            return labelFor(date: date, component: .day)
        case .sixMonths, .oneYear:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: date)
            if period == .oneYear {
                return String(label.prefix(1))
            }
            return label
        }
    }

    private func closestPoint(to date: Date, in points: [StatPoint]) -> StatPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func distanceInMiles(_ workout: Workout) -> Double {
        if workout.type == .swim {
            return workout.distance / 1760.0
        }
        return workout.distance
    }

    private func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func scheduleDismiss() {
        cancelDismiss()
        let task = DispatchWorkItem {
            selectedPoint = nil
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func statIconCount(type: WorkoutType, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: type.systemImage)
                .font(.system(size: 16, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.85))
    }
}

enum StatsPeriod: CaseIterable {
    case oneWeek
    case oneMonth
    case sixMonths
    case oneYear

    var label: String {
        switch self {
        case .oneWeek:
            return "1W"
        case .oneMonth:
            return "1M"
        case .sixMonths:
            return "6M"
        case .oneYear:
            return "1Y"
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
