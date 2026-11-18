import Foundation
import AppKit
import SwiftUI

struct SensorReading: Identifiable { let id: String; let name: String; var value: Double }
struct FanReading: Identifiable { let id: Int; var rpm: Double; var minRPM: Double; var maxRPM: Double }

final class Model: ObservableObject {
    static let agentPath = NSHomeDirectory() + "/Library/LaunchAgents/com.minifan.app.plist"

    @Published var sensors: [SensorReading] = []
    @Published var fans: [FanReading] = []
    @Published var status: DaemonStatus? = nil
    @Published var tempHistory: [Double] = []
    @Published var rpmHistory: [Double] = []
    @Published var saveError: String = ""
    @Published var page: Int = 0

    @Published var config: Config = Config() {
        didSet { if !loading && config != oldValue { scheduleSave() } }
    }
    @Published var useFahrenheit: Bool = UserDefaults.standard.bool(forKey: "useF") {
        didSet { UserDefaults.standard.set(useFahrenheit, forKey: "useF") }
    }
    @Published var lite: Bool = UserDefaults.standard.bool(forKey: "lite") {
        didSet { UserDefaults.standard.set(lite, forKey: "lite") }
    }
    @Published var showMenuBar: Bool = (UserDefaults.standard.object(forKey: "showMenuBar") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showMenuBar, forKey: "showMenuBar"); onSettingsChanged?() }
    }
    @Published var launchAtLogin: Bool = FileManager.default.fileExists(atPath: Model.agentPath) {
        didSet { setLaunchAgent(launchAtLogin) }
    }

    var onTick: (() -> Void)?
    var onSettingsChanged: (() -> Void)?
    let sensorInfo: [SensorInfo]
    let nFans: Int
    let modelName: String
    private var loading = false
    private var saveWork: DispatchWorkItem?
    private var timer: Timer?

    init() {
        let ok = SMC.shared.ok
        sensorInfo = ok ? discoverSensors() : []
        nFans = ok ? max(1, fanCount()) : 1
        modelName = marketingName()
        loadConfig()
        tick()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: derived values
    var effectiveKeys: [String] { return config.sensors.isEmpty ? defaultSensorKeys(sensorInfo) : config.sensors }

    var primaryTemp: Double? {
        let keys = effectiveKeys
        let vals = sensors.filter { keys.contains($0.id) }.map { $0.value }
        if let m = vals.max() { return m }
        if let s = status, s.temp > 0 { return s.temp }
        return nil
    }

    var primaryName: String {
        let keys = effectiveKeys
        let sel = sensors.filter { keys.contains($0.id) }
        if let best = sel.max(by: { $0.value < $1.value }) { return best.name }
        return "No sensor"
    }

    var rpmNow: Double { return fans.first?.rpm ?? 0 }
    var rpmMin: Double { return fans.first?.minRPM ?? 1800 }
    var rpmMax: Double { return fans.first?.maxRPM ?? 5500 }

    var daemonRunning: Bool {
        guard let s = status else { return false }
        return Date().timeIntervalSince1970 - s.ts < 5
    }

    var activeProfile: String { return config.mode == "auto" ? "auto" : config.profile }

    func rpmFor(percent: Double) -> Int { return Int(rpmMin + percent / 100.0 * (rpmMax - rpmMin)) }

    func tempNumber(_ c: Double) -> String {
        return String(Int((useFahrenheit ? c * 9.0 / 5.0 + 32.0 : c).rounded()))
    }
    func temp(_ c: Double) -> String { return tempNumber(c) + (useFahrenheit ? "°F" : "°C") }

    // MARK: polling
    func tick() {
        let smc = SMC.shared
        var list: [SensorReading] = []
        for s in sensorInfo {
            if let v = smc.value(s.key), v > 0, v < 140 { list.append(SensorReading(id: s.key, name: s.name, value: v)) }
        }
        sensors = list
        var fl: [FanReading] = []
        for i in 0..<nFans {
            let ac = smc.value("F\(i)Ac") ?? 0
            let mn = smc.value("F\(i)Mn") ?? 1800
            let mx = smc.value("F\(i)Mx") ?? 5500
            fl.append(FanReading(id: i, rpm: ac, minRPM: mn, maxRPM: max(mx, mn + 100)))
        }
        fans = fl
        status = readStatus()
        if let t = primaryTemp { tempHistory.append(t); if tempHistory.count > 150 { tempHistory.removeFirst() } }
        rpmHistory.append(rpmNow); if rpmHistory.count > 150 { rpmHistory.removeFirst() }
        onTick?()
    }

    func readStatus() -> DaemonStatus? {
        guard let d = FileManager.default.contents(atPath: statusPath) else { return nil }
        return try? JSONDecoder().decode(DaemonStatus.self, from: d)
    }

    // MARK: config
    func loadConfig() {
        loading = true
        if let d = FileManager.default.contents(atPath: configPath),
           var c = try? JSONDecoder().decode(Config.self, from: d) {
            c.sanitize()
            config = c
        }
        loading = false
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: w)
    }

    private func save() {
        var c = config
        c.sanitize()
        let enc = JSONEncoder()
        enc.outputFormatting = .prettyPrinted
        do {
            let data = try enc.encode(c)
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            saveError = ""
        } catch {
            saveError = "Не удалось сохранить настройки. Установи службу: sudo ./install.sh"
        }
    }

    func bind(_ kp: WritableKeyPath<Config, Double>) -> Binding<Double> {
        return Binding<Double>(get: { self.config[keyPath: kp] }, set: { self.config[keyPath: kp] = $0 })
    }

    func applyProfile(_ n: String) {
        var c = config
        c.profile = n
        if n == "auto" {
            c.mode = "auto"
        } else if n == "max" {
            c.mode = "constant"; c.constantPercent = 100
        } else if n == "custom" {
            c.mode = "curve"
        } else {
            c.mode = "curve"
            c.curve = Presets.curve(n)
            c.hysteresis = n == "silent" ? 4 : 3
            c.rampDown = n == "silent" ? 2.5 : (n == "performance" ? 8 : 4)
            c.rampUp = n == "silent" ? 12 : (n == "performance" ? 35 : 20)
        }
        config = c
    }

    func setMode(_ mode: String) {
        var c = config
        c.mode = mode
        c.profile = mode == "auto" ? "auto" : "custom"
        config = c
    }

    func setCurve(_ pts: [CurvePoint]) {
        var c = config
        c.curve = pts
        c.profile = "custom"
        config = c
    }

    func addPoint() {
        var c = config.curve
        if c.count >= 12 { return }
        var best = 0
        var gap = -1.0
        for i in 0..<(c.count - 1) {
            let g = c[i + 1].t - c[i].t
            if g > gap { gap = g; best = i }
        }
        if gap < 3 { return }
        let t = ((c[best].t + c[best + 1].t) / 2).rounded()
        c.insert(CurvePoint(t: t, p: interpCurve(c, t).rounded()), at: best + 1)
        setCurve(c)
    }

    func removePoint(_ i: Int) {
        var c = config.curve
        if c.count <= 2 || i < 0 || i >= c.count { return }
        c.remove(at: i)
        setCurve(c)
    }

    func toggleSensor(_ key: String) {
        var keys = effectiveKeys
        if let i = keys.firstIndex(of: key) {
            if keys.count > 1 { keys.remove(at: i) }
        } else {
            keys.append(key)
        }
        var c = config
        c.sensors = keys
        config = c
    }

    private func setLaunchAgent(_ on: Bool) {
        if on {
            let plist: [String: Any] = ["Label": "com.minifan.app",
                                        "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
                                        "RunAtLoad": true]
            let dir = (Model.agentPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            _ = (plist as NSDictionary).write(toFile: Model.agentPath, atomically: true)
        } else {
            try? FileManager.default.removeItem(atPath: Model.agentPath)
        }
    }
}
