import Foundation
import ScreenAlignCore

struct UserDefaultsCalibrationStore: CalibrationStore {
    private let key = "edgeCalibrations"
    private let defaults = UserDefaults.standard

    func load() -> [EdgeCalibration] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([EdgeCalibration].self, from: data)) ?? []
    }

    func save(_ calibrations: [EdgeCalibration]) {
        guard let data = try? JSONEncoder().encode(calibrations) else { return }
        defaults.set(data, forKey: key)
    }
}
