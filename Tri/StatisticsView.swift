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
    @State private var showSummary = false
    @State private var selectedHistoryStart: Date?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                title: "Statistics",
                buttonSystemName: "lasso.badge.sparkles",
                buttonAction: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSummary.toggle()
                    }
                }
            )
            
            if showSummary {
                summaryText
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }

            HStack(alignment: .top, spacing: 12) {
                dailyAverageCard
                weeklyWorkoutsCard
            }
            .padding(.horizontal, 20)

            let isMonthPeriod = period == .sixMonths || period == .oneYear
            let isShortPeriod = period == .oneWeek || period == .oneMonth
            let points = dataPoints
            let chartPoints = clampedPoints
            let firstWorkoutMonth = isMonthPeriod ? firstVisibleMonthWithData(in: chartPoints) : nil
            let firstWorkoutDay = firstWorkoutDayStart
            let shortSplit: (pre: [StatPoint], post: [StatPoint]) = {
                if isShortPeriod {
                    if let firstWorkoutDay = firstWorkoutDay {
                        return (
                            chartPoints.filter { $0.date < firstWorkoutDay },
                            chartPoints.filter { $0.date >= firstWorkoutDay }
                        )
                    }
                    return (chartPoints, [])
                }
                return ([], chartPoints)
            }()
            let preShortPoints = shortSplit.pre
            let postShortPoints = shortSplit.post
            let hasWorkoutToday = store.workouts.contains { Calendar.current.isDateInToday($0.date) }
            let shouldHideTodayPoint = isShortPeriod && !hasWorkoutToday && chartPoints.count >= 2
            let solidLinePoints = shouldHideTodayPoint ? Array(chartPoints.dropLast(1)) : chartPoints
            let trimmedPreShortPoints = shouldHideTodayPoint ? preShortPoints.filter { !isToday($0.date) } : preShortPoints
            let trimmedPostShortPoints = shouldHideTodayPoint ? postShortPoints.filter { !isToday($0.date) } : postShortPoints
            let bridgeShortPoints: [StatPoint] = {
                guard let lastPre = trimmedPreShortPoints.last,
                      let firstPost = trimmedPostShortPoints.first else {
                    return []
                }
                return [lastPre, firstPost]
            }()
            let interactionPoints = shouldHideTodayPoint ? points.filter { !isToday($0.date) } : points

            VStack(alignment: .leading, spacing: 12) {
                Text("Track Progress")
                    .font(.system(size: 18, weight: .bold, design: .serif))

                workoutChart(
                    points: points,
                    chartPoints: chartPoints,
                    isMonthPeriod: isMonthPeriod,
                    isShortPeriod: isShortPeriod,
                    trimmedPreShortPoints: trimmedPreShortPoints,
                    trimmedPostShortPoints: trimmedPostShortPoints,
                    bridgeShortPoints: bridgeShortPoints,
                    solidLinePoints: solidLinePoints,
                    shouldHideTodayPoint: shouldHideTodayPoint,
                    interactionPoints: interactionPoints,
                    firstWorkoutMonth: firstWorkoutMonth,
                    firstWorkoutDay: firstWorkoutDay
                )

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
                selectedHistoryStart = nil
            }

                historySection

                Spacer()
            }
            .padding(.bottom, 120)
        }
        .appBackground()
    }

    // MARK: - Chart

    @ViewBuilder
    private func workoutChart(
        points: [StatPoint],
        chartPoints: [StatPoint],
        isMonthPeriod: Bool,
        isShortPeriod: Bool,
        trimmedPreShortPoints: [StatPoint],
        trimmedPostShortPoints: [StatPoint],
        bridgeShortPoints: [StatPoint],
        solidLinePoints: [StatPoint],
        shouldHideTodayPoint: Bool,
        interactionPoints: [StatPoint],
        firstWorkoutMonth: Date?,
        firstWorkoutDay: Date?
    ) -> some View {
        Chart {
            chartContent(
                isMonthPeriod: isMonthPeriod,
                isShortPeriod: isShortPeriod,
                trimmedPreShortPoints: trimmedPreShortPoints,
                trimmedPostShortPoints: trimmedPostShortPoints,
                bridgeShortPoints: bridgeShortPoints,
                solidLinePoints: solidLinePoints
            )

            if let selectedPoint, isInteracting,
               !(shouldHideTodayPoint && Calendar.current.isDateInToday(selectedPoint.date)) {
                PointMark(
                    x: .value("Date", selectedPoint.date),
                    y: .value("Distance", selectedPoint.value)
                )
                .symbolSize(55)
                .foregroundStyle(Color.black)
            }
        }
        .chartLegend(.hidden)
        .chartForegroundStyleScale { (series: String) -> Color in
            if series == "post" || series == "solid" {
                return Color.black
            }
            return Color.black.opacity(0.6)
        }
        .chartXAxis {
            chartXAxis(points: points, shouldHideTodayPoint: shouldHideTodayPoint)
        }
        .chartYAxis {
            chartYAxis()
        }
        .chartYScale(domain: 0...(points.map { $0.value }.max() ?? 1) * 1.2)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ZStack {
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard let plotAnchor = proxy.plotFrame else { return }
                                    let plotFrame = geometry[plotAnchor]
                                    let x = value.location.x - plotFrame.origin.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedPoint = closestPoint(to: date, in: interactionPoints)
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
                       !(shouldHideTodayPoint && Calendar.current.isDateInToday(selectedPoint.date)),
                       let plotAnchor = proxy.plotFrame,
                       let xPosition = proxy.position(forX: selectedPoint.date),
                       let yPosition = proxy.position(forY: selectedPoint.value) {
                        let plotFrame = geometry[plotAnchor]
                        VStack(spacing: 4) {
                            Text(selectedPoint.displayLabel)
                                .font(.system(size: 12, weight: .semibold))
                            Text(selectedPointValueText(for: selectedPoint, firstWorkoutMonth: firstWorkoutMonth, firstWorkoutDay: firstWorkoutDay))
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
                            y: plotFrame.origin.y + max(12, yPosition - 34)
                        )
                    }
                }
            }
        }
        .frame(height: 240)
    }

    @ChartContentBuilder
    private func chartContent(
        isMonthPeriod: Bool,
        isShortPeriod: Bool,
        trimmedPreShortPoints: [StatPoint],
        trimmedPostShortPoints: [StatPoint],
        bridgeShortPoints: [StatPoint],
        solidLinePoints: [StatPoint]
    ) -> some ChartContent {
        if isMonthPeriod {
            ForEach(solidLinePoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Distance", point.value))
                    .foregroundStyle(by: .value("Series", "solid"))
                    .interpolationMethod(.monotone)
            }
        } else if isShortPeriod {
            ForEach(trimmedPreShortPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Distance", point.value))
                    .foregroundStyle(by: .value("Series", "pre"))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                    .interpolationMethod(.monotone)
            }
            ForEach(trimmedPostShortPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Distance", point.value))
                    .foregroundStyle(by: .value("Series", "solid"))
                    .interpolationMethod(.monotone)
            }
            ForEach(bridgeShortPoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Distance", point.value))
                    .foregroundStyle(by: .value("Series", "bridge"))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                    .interpolationMethod(.monotone)
            }
        } else {
            ForEach(solidLinePoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Distance", point.value))
                    .foregroundStyle(by: .value("Series", "solid"))
                    .interpolationMethod(.monotone)
            }
        }
    }

    @AxisContentBuilder
    private func chartXAxis(points: [StatPoint], shouldHideTodayPoint: Bool) -> some AxisContent {
        switch period {
        case .oneWeek:
            AxisMarks(values: points.map { $0.date }) { value in
                AxisGridLine()
                AxisValueLabel {
                    if shouldHideTodayPoint, isToday(value.as(Date.self)) {
                        EmptyView()
                    } else {
                        Text(axisLabel(for: value.as(Date.self)))
                            .offset(x: xAxisLabelOffset(for: .oneWeek))
                    }
                }
            }
        case .oneMonth:
            let axisDates = oneMonthAxisDates(points: points, tickCount: 5)
            AxisMarks(values: axisDates) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self),
                       isOneMonthAxisEnd(date, axisDates: axisDates) || (shouldHideTodayPoint && isToday(date)) {
                        EmptyView()
                    } else {
                        Text(axisLabel(for: value.as(Date.self)))
                            .offset(x: xAxisLabelOffset(for: .oneMonth))
                    }
                }
            }
        case .sixMonths:
            AxisMarks(values: points.map { $0.date }) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(axisLabel(for: value.as(Date.self)))
                        .offset(x: xAxisLabelOffset(for: .sixMonths))
                }
            }
        case .oneYear:
            AxisMarks(values: points.map { $0.date }) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(axisLabel(for: value.as(Date.self)))
                        .offset(x: xAxisLabelOffset(for: .oneYear))
                }
            }
        }
    }

    @AxisContentBuilder
    private func chartYAxis() -> some AxisContent {
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

    // MARK: - Stat Cards

    private var dailyAverageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calories Burned")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .offset(y: -2)
                Text(totalCaloriesBurned.formatted())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.65))
                Text("Daily avg: \(Int(dailyAverageCalories).formatted()) cal")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }

    private var weeklyWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Workouts")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .frame(maxWidth: .infinity, alignment: .center)
            Text("\(weeklyWorkoutCount)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                statIconCount(type: .swim, count: weeklyWorkoutCount(for: .swim))
                statIconCount(type: .bike, count: weeklyWorkoutCount(for: .bike))
                statIconCount(type: .run, count: weeklyWorkoutCount(for: .run))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Data

    private var dataPoints: [StatPoint] {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .oneWeek:
            guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return [] }
            return aggregateByDay(from: start, days: 7)
        case .oneMonth:
            guard let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) else { return [] }
            return aggregateByDay(from: start, days: 30)
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

    private func xAxisLabelOffset(for period: StatsPeriod) -> CGFloat {
        switch period {
        case .oneWeek:   return -10
        case .oneMonth:  return -11
        case .sixMonths: return -11
        case .oneYear:   return -9
        }
    }

    private func closestPoint(to date: Date, in points: [StatPoint]) -> StatPoint? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }

    private func oneMonthAxisDates(points: [StatPoint], tickCount: Int) -> [Date] {
        guard let first = points.first?.date, let last = points.last?.date, tickCount > 1 else { return [] }
        let start = Calendar.current.startOfDay(for: first)
        let end = Calendar.current.startOfDay(for: last)
        let totalInterval = end.timeIntervalSince(start)
        if totalInterval <= 0 { return [start] }
        let step = totalInterval / Double(tickCount - 1)
        return (0..<tickCount).map { index in
            start.addingTimeInterval(step * Double(index))
        }
    }

    private func isOneMonthAxisEnd(_ date: Date, axisDates: [Date]) -> Bool {
        guard let end = axisDates.last else { return false }
        return abs(date.timeIntervalSince(end)) < 1
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
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

    private func firstVisibleMonthWithData(in points: [StatPoint]) -> Date? {
        points.first { $0.value > 0 }?.date
    }

    private var firstWorkoutDayStart: Date? {
        guard let firstWorkoutDate = store.workouts.map(\.date).min() else { return nil }
        return Calendar.current.startOfDay(for: firstWorkoutDate)
    }

    private func selectedPointValueText(for point: StatPoint, firstWorkoutMonth: Date?, firstWorkoutDay: Date?) -> String {
        if (period == .sixMonths || period == .oneYear),
           let firstWorkoutMonth,
           point.date < firstWorkoutMonth {
            return "n/a"
        }
        if period == .oneWeek || period == .oneMonth {
            guard let firstWorkoutDay else { return "n/a" }
            if point.date < firstWorkoutDay {
                return "n/a"
            }
        }
        return "\(String(format: "%.1f", point.value)) mi"
    }

    // MARK: - Summary Text

    private var summaryText: some View {
        let todayWorkouts = store.workouts
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
        let totalCalories = todayWorkouts.reduce(0.0) { $0 + $1.calories }
        let totalMinutes = Int(todayWorkouts.reduce(0.0) { $0 + $1.duration } / 60.0)
        let formattedDuration = formattedWorkoutDuration(minutes: totalMinutes)

        let summaryBase: Text = {
            if todayWorkouts.isEmpty {
                return Text("\(greetingText), you haven't logged a workout yet today. Add one to see your stats summary.")
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            let recent = Array(todayWorkouts.prefix(2))
            let moreCount = max(0, todayWorkouts.count - recent.count)
            let workoutText = workoutSummaryText(for: recent, moreCount: moreCount)
            let parts: [Text] = [
                Text("\(greetingText), you've burned ")
                    .foregroundStyle(Color.black.opacity(0.5)),
                Text(Image(systemName: "flame.fill"))
                    .foregroundStyle(Color.black),
                Text(" \(Int(totalCalories))")
                    .foregroundStyle(Color.black)
                    .fontWeight(.bold),
                Text(" calories")
                    .foregroundStyle(Color.black)
                    .fontWeight(.bold),
                Text(" today. ")
                    .foregroundStyle(Color.black.opacity(0.5)),
                Text("Your recent workouts include ")
                    .foregroundStyle(Color.black.opacity(0.5)),
                workoutText,
                Text(". Total workout time of ")
                    .foregroundStyle(Color.black.opacity(0.5)),
                Text(formattedDuration)
                    .foregroundStyle(Color.black)
                    .fontWeight(.bold),
                Text(".")
                    .foregroundStyle(Color.black.opacity(0.5))
            ]
            return concatText(parts)
        }()

        return summaryBase
            .font(.system(size: 15, weight: .semibold, design: .serif))
            .lineSpacing(6)
            .frame(maxWidth: 340, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.leading)
    }

    private func concatText(_ parts: [Text]) -> Text {
        guard var result = parts.first else { return Text("") }
        for part in parts.dropFirst() {
            result = result + part
        }
        return result
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private func workoutSummaryText(for workouts: [Workout], moreCount: Int) -> Text {
        guard let first = workouts.first else {
            return Text("your workouts").foregroundStyle(Color.black.opacity(0.5))
        }
        var text = workoutDetailText(for: first)
        if workouts.count > 1, let second = workouts.dropFirst().first {
            let connector = moreCount > 0 ? ", " : " and "
            text = text + Text(connector).foregroundStyle(Color.black.opacity(0.5))
            text = text + workoutDetailText(for: second)
        }
        if moreCount > 0 {
            text = text + Text(", and ").foregroundStyle(Color.black.opacity(0.5))
            text = text + Text("\(moreCount)")
                .foregroundStyle(Color.black)
                .fontWeight(.bold)
            text = text + Text(" more").foregroundStyle(Color.black.opacity(0.5))
        }
        return text
    }

    private func workoutDetailText(for workout: Workout) -> Text {
        let distance = workout.distanceString
        return Text(Image(systemName: workout.type.systemImage))
            .foregroundStyle(Color.black)
            .fontWeight(.bold)
            + Text(" \(distance) \(workout.type.rawValue.lowercased())")
                .foregroundStyle(Color.black)
                .fontWeight(.bold)
    }

    private func formattedWorkoutDuration(minutes: Int) -> String {
        if minutes < 90 {
            return "\(minutes) minutes"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        let hourLabel = hours == 1 ? "hour" : "hours"
        if remaining == 0 {
            return "\(hours) \(hourLabel)"
        }
        let minuteLabel = remaining == 1 ? "minute" : "minutes"
        return "\(hours) \(hourLabel) and \(remaining) \(minuteLabel)"
    }

    // MARK: - Weekly Stats

    private var dailyAverageCalories: Double {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        let todayStart = calendar.startOfDay(for: Date())
        let hasWorkoutToday = store.workouts.contains { calendar.isDate($0.date, inSameDayAs: todayStart) }
        let end = hasWorkoutToday ? (calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart) : todayStart
        let days = calendar.dateComponents([.day], from: weekStart, to: end).day ?? 0
        guard days > 0 else { return 0 }
        let calories = store.workouts
            .filter { $0.date >= weekStart && $0.date < end }
            .reduce(0.0) { $0 + $1.calories }
        return calories / Double(days)
    }

    private var totalCaloriesBurned: Int {
        Int(weeklyWorkouts().reduce(0) { $0 + $1.calories })
    }

    private var weeklyWorkoutCount: Int {
        weeklyWorkouts().count
    }

    private func weeklyWorkoutCount(for type: WorkoutType) -> Int {
        weeklyWorkouts().filter { $0.type == type }.count
    }

    private func weeklyWorkouts() -> [Workout] {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return store.workouts.filter { $0.date >= weekStart }
    }

    // MARK: - Period Story

    private var historySection: some View {
        let slices = historySlices
        let activeSelection = selectedHistoryStart ?? slices.last?.start
        let maxDistance = slices.map(\.totalDistanceMiles).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.system(size: 18, weight: .bold, design: .serif))

            if slices.isEmpty {
                Text("No history yet")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(slices) { slice in
                            historyCard(slice: slice, isSelected: slice.start == activeSelection, maxDistance: maxDistance)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedHistoryStart = slice.start
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                if let selected = selectedHistorySlice(from: slices) {
                    Text(selected.detailLabel)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var historyTableSection: some View {
        let slices = historySlices
        let maxDistance = slices.map(\.totalDistanceMiles).max() ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.system(size: 18, weight: .bold, design: .serif))

            if slices.isEmpty {
                Text("No history yet")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                HStack {
                    Text("Period")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Distance")
                        .frame(width: 80, alignment: .trailing)
                    Text("Workouts")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Color.black.opacity(0.6))

                VStack(spacing: 10) {
                    ForEach(slices) { slice in
                        historyTableRow(slice: slice, maxDistance: maxDistance)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var historySlices: [HistorySlice] {
        let calendar = Calendar.current
        let now = Date()
        switch period {
        case .oneWeek:
            guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return [] }
            return (0..<7).compactMap { offset in
                let dayStart = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                return historySlice(start: dayStart, end: dayEnd, label: dayLabel(for: dayStart))
            }
        case .oneMonth:
            guard let start = calendar.date(byAdding: .day, value: -27, to: calendar.startOfDay(for: now)) else { return [] }
            return (0..<4).compactMap { offset in
                let weekStart = calendar.date(byAdding: .day, value: offset * 7, to: start) ?? start
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                let rangeEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
                return historySlice(start: weekStart, end: weekEnd, label: weekRangeLabel(from: weekStart, to: rangeEnd))
            }
        case .sixMonths:
            guard let start = calendar.date(byAdding: .month, value: -5, to: startOfMonth(now)) else { return [] }
            return (0..<6).compactMap { offset in
                let monthStart = calendar.date(byAdding: .month, value: offset, to: start) ?? start
                guard let interval = calendar.dateInterval(of: .month, for: monthStart) else { return nil }
                return historySlice(start: interval.start, end: interval.end, label: monthLabel(for: interval.start))
            }
        case .oneYear:
            guard let start = calendar.date(byAdding: .month, value: -9, to: startOfQuarter(now)) else { return [] }
            return (0..<4).compactMap { offset in
                let quarterStart = calendar.date(byAdding: .month, value: offset * 3, to: start) ?? start
                let quarterEnd = calendar.date(byAdding: .month, value: 3, to: quarterStart) ?? quarterStart
                return historySlice(start: quarterStart, end: quarterEnd, label: quarterLabel(for: quarterStart))
            }
        }
    }

    private func selectedHistorySlice(from slices: [HistorySlice]) -> HistorySlice? {
        if let selectedHistoryStart {
            return slices.first { $0.start == selectedHistoryStart } ?? slices.last
        }
        return slices.last
    }

    private func historySlice(start: Date, end: Date, label: String) -> HistorySlice {
        let workouts = store.workouts.filter { $0.date >= start && $0.date < end }
        let totalDistanceMiles = workouts.reduce(0.0) { $0 + distanceInMiles($1) }
        let totalCalories = workouts.reduce(0.0) { $0 + $1.calories }
        return HistorySlice(
            start: start,
            end: end,
            label: label,
            sessionCount: workouts.count,
            totalDistanceMiles: totalDistanceMiles,
            totalCalories: totalCalories
        )
    }

    private func historyCard(slice: HistorySlice, isSelected: Bool, maxDistance: Double) -> some View {
        let ratio = maxDistance > 0 ? slice.totalDistanceMiles / maxDistance : 0
        let barWidth = max(12, ratio * 60)

        return VStack(alignment: .leading, spacing: 8) {
            Text(slice.label)
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundStyle(Color.black.opacity(0.7))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 60, height: 6)
                Capsule()
                    .fill(Color.black.opacity(isSelected ? 0.85 : 0.65))
                    .frame(width: barWidth, height: 6)
            }

            Text("\(formatMiles(slice.totalDistanceMiles)) mi")
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundStyle(Color.black)

            Text("\(slice.sessionCount) workouts")
                .font(.system(size: 11, weight: .medium, design: .serif))
                .foregroundStyle(Color.black.opacity(0.5))
        }
        .padding(12)
        .frame(width: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.black.opacity(1) : Color.black.opacity(0.1), lineWidth: 1)
        )
    }

    private func historyTableRow(slice: HistorySlice, maxDistance: Double) -> some View {
        let ratio = maxDistance > 0 ? slice.totalDistanceMiles / maxDistance : 0
        let barWidth = max(20, ratio * 80)

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(slice.label)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: barWidth, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(formatMiles(slice.totalDistanceMiles))")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(width: 80, alignment: .trailing)

            Text("\(slice.sessionCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black)
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func formatMiles(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE - M/d"
        return formatter.string(from: date)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM ''yy"
        return formatter.string(from: date)
    }

    private func weekRangeLabel(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startLabel = formatter.string(from: start)
        let endLabel = formatter.string(from: end)
        return "\(startLabel)-\(endLabel)"
    }

    private func startOfQuarter(_ date: Date) -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let quarter = (month - 1) / 3
        let quarterMonth = quarter * 3 + 1
        var components = calendar.dateComponents([.year], from: date)
        components.month = quarterMonth
        components.day = 1
        return calendar.date(from: components) ?? date
    }

    private func quarterLabel(for start: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: start)
        let quarter = (month - 1) / 3 + 1
        return "Q\(quarter)"
    }

    // MARK: - Dismiss Helpers

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

    // MARK: - Subviews

    private func statIconCount(type: WorkoutType, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: type.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.65))
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
        }
    }
}

// MARK: - Supporting Types

private struct HistorySlice: Identifiable {
    var id: Date { start }
    let start: Date
    let end: Date
    let label: String
    let sessionCount: Int
    let totalDistanceMiles: Double
    let totalCalories: Double

    var detailLabel: String {
        "Distance: \(String(format: "%.1f", totalDistanceMiles)) mi | Workouts: \(sessionCount) | Calories: \(Int(totalCalories).formatted()) cal"
    }
}

enum StatsPeriod: CaseIterable {
    case oneWeek
    case oneMonth
    case sixMonths
    case oneYear

    var label: String {
        switch self {
        case .oneWeek:    return "1W"
        case .oneMonth:   return "1M"
        case .sixMonths:  return "6M"
        case .oneYear:    return "1Y"
        }
    }
}

struct StatPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
    let label: String

    var displayLabel: String { label }
}
