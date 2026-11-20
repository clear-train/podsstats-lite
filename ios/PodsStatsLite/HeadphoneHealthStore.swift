import Foundation
import HealthKit
import PodsStatsCore

/// 健康数据访问层：只读「耳机音量」，不做任何写入
@MainActor
final class HeadphoneHealthStore: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case requesting
        case loading
        case ready
        case denied
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var sessions: [HeadphoneSession] = []
    @Published private(set) var report: StatsReport?
    @Published private(set) var sampleCount = 0
    @Published var rangeDays: Int = 90
    @Published var gapMinutes: Int = 5

    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var headphoneType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)
    }

    /// 请求授权并加载。授权被拒时 state = .denied，界面给出引导。
    func requestAuthorizationAndLoad() async {
        guard isHealthDataAvailable, let type = headphoneType else {
            state = .failed("此设备不支持健康数据")
            return
        }
        state = .requesting
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
        } catch {
            state = .failed("授权失败：\(error.localizedDescription)")
            return
        }
        await load()
    }

    /// 只刷新数据，不再弹授权框
    func load() async {
        guard let type = headphoneType else { return }
        let status = store.authorizationStatus(for: type)
        // .notDetermined 之外都无法区分「用户拒绝」和「没有数据」，
        // 统一走一次查询，由结果空/权限错误来判断
        if status == .denied {
            state = .denied
            return
        }

        state = .loading
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -rangeDays, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        do {
            let raw = try await fetchSamples(type: type, predicate: predicate)
            sampleCount = raw.count
            guard !raw.isEmpty else {
                sessions = []
                report = StatsEngine.compute(sessions: [], calendar: .current)
                state = .ready
                return
            }
            let options = SessionBuilder.Options(gap: TimeInterval(gapMinutes * 60))
            let built = SessionBuilder.build(from: raw, options: options)
            sessions = built
            report = StatsEngine.compute(
                sessions: built,
                samples: raw,
                calendar: .current,
                options: ["gap": "\(gapMinutes * 60)"]
            )
            state = built.isEmpty ? .ready : .ready
        } catch {
            if (error as NSError).code == HKError.errorAuthorizationDenied.rawValue {
                state = .denied
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func fetchSamples(type: HKQuantityType, predicate: NSPredicate) async throws -> [HeadphoneSample] {
        let unit = HKUnit.decibelAWeightedSoundPressureLevel()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let objects = (samples as? [HKQuantitySample]) ?? []
                let mapped = objects.map { sample in
                    HeadphoneSample(
                        start: sample.startDate,
                        end: sample.endDate,
                        db: sample.quantity.doubleValue(for: unit),
                        kind: .quantity,
                        source: sample.sourceRevision.source.name
                    )
                }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }
}
