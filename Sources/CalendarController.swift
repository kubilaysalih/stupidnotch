import Cocoa
import Combine
import EventKit

struct CalendarDay: Equatable {
    let date: Date
    let weekday: String
    let dayOfMonth: Int
    let isToday: Bool
}

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let color: NSColor

    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: start)
    }
}

enum CalendarAuthState {
    case notDetermined
    case granted
    case denied
}

final class CalendarController: ObservableObject {
    @Published var monthLabel: String = ""
    @Published var weekStrip: [CalendarDay] = []
    @Published var todayEvents: [CalendarEvent] = []
    @Published var authState: CalendarAuthState = .notDetermined

    var hasCalendarAccess: Bool { authState == .granted }

    private let store = EKEventStore()
    private var refreshTimer: Timer?

    func events(for date: Date) -> [CalendarEvent] {
        guard hasCalendarAccess else { return [] }
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .day, for: date)?.start,
              let end = cal.dateInterval(of: .day, for: date)?.end else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { ev in
                CalendarEvent(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    title: ev.title ?? "(no title)",
                    start: ev.startDate, end: ev.endDate,
                    color: ev.calendar?.color ?? NSColor.systemBlue
                )
            }
    }

    func start() {

        refreshAuthState()
        rebuild()
        if hasCalendarAccess { loadEvents() }
        scheduleRefresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventsChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    func requestAccessFromUser() {
        let completion: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.authState = granted ? .granted : .denied
                self.rebuild()
                if granted { self.loadEvents() }
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in completion(granted) }
        } else {
            store.requestAccess(to: .event) { granted, _ in completion(granted) }
        }
    }

    private func refreshAuthState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status.rawValue {
        case 0: authState = .notDetermined
        case 1, 2: authState = .denied
        case 3, 4: authState = .granted
        default: authState = .denied
        }
    }

    @objc private func eventsChanged() { loadEvents() }

    private func scheduleRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.rebuild()
            self?.refreshAuthState()
            if self?.hasCalendarAccess == true { self?.loadEvents() }
        }
    }

    private func rebuild() {
        let cal = Calendar.current
        let now = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        monthLabel = monthFormatter.string(from: now)

        var days: [CalendarDay] = []
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEEE"
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        for offset in 0..<7 {
            if let d = cal.date(byAdding: .day, value: offset, to: startOfWeek) {
                days.append(CalendarDay(
                    date: d,
                    weekday: weekdayFormatter.string(from: d),
                    dayOfMonth: cal.component(.day, from: d),
                    isToday: cal.isDateInToday(d)
                ))
            }
        }
        weekStrip = days
    }

    private func loadEvents() {
        let cal = Calendar.current
        let now = Date()
        guard let start = cal.dateInterval(of: .day, for: now)?.start,
              let end = cal.dateInterval(of: .day, for: now)?.end else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { ev -> CalendarEvent in
                CalendarEvent(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    title: ev.title ?? "(no title)",
                    start: ev.startDate,
                    end: ev.endDate,
                    color: ev.calendar?.color ?? NSColor.systemBlue
                )
            }
        DispatchQueue.main.async { self.todayEvents = events }
    }
}
