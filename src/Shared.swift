import Foundation

let supportDir = "/Library/Application Support/MiniFan"
let configPath = supportDir + "/config.json"
let statusPath = supportDir + "/status.json"

// MARK: - SMC wrapper
final class SMC {
    static let shared = SMC()
    let ok: Bool
    private init() { ok = (smc_open() == 0) }

    func raw(_ key: String) -> (bytes: [UInt8], type: String, size: Int)? {
        var buf = [UInt8](repeating: 0, count: 32)
        var size: UInt32 = 0
        var t = [CChar](repeating: 0, count: 5)
        if smc_read(key, &buf, &size, &t) != 0 { return nil }
        return (buf, String(cString: t), Int(size))
    }

    func value(_ key: String) -> Double? {
        guard let r = raw(key) else { return nil }
        return SMC.decode(r.bytes, r.size, r.type)
    }

    static func decode(_ b: [UInt8], _ size: Int, _ type: String) -> Double? {
        if size < 1 { return nil }
        func be(_ n: Int) -> UInt64 {
            var v: UInt64 = 0
            var i = 0
            while i < n && i < size { v = (v << 8) | UInt64(b[i]); i += 1 }
            return v
        }
        if type == "sp78" {
            if size < 2 { return nil }
            return Double(Int16(bitPattern: UInt16(be(2)))) / 256.0
        }
        if type == "fpe2" {
            if size < 2 { return nil }
            return Double(be(2)) / 4.0
        }
        if type == "flt " {
            if size < 4 { return nil }
            let u = UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
            return Double(Float(bitPattern: u))
        }
        if type == "ui8 " || type == "ui16" || type == "ui32" { return Double(be(size)) }
        return nil
    }

    static func encode(_ v: Double, _ type: String) -> [UInt8]? {
        if type == "fpe2" {
            let r = UInt16(max(0.0, min(16383.0, v)) * 4.0)
            return [UInt8(r >> 8), UInt8(r & 0xff)]
        }
        if type == "flt " {
            let u = Float(v).bitPattern
            return [UInt8(u & 0xff), UInt8((u >> 8) & 0xff), UInt8((u >> 16) & 0xff), UInt8((u >> 24) & 0xff)]
        }
        if type == "ui16" {
            let r = UInt16(max(0.0, min(65535.0, v)))
            return [UInt8(r >> 8), UInt8(r & 0xff)]
        }
        if type == "ui8 " { return [UInt8(max(0.0, min(255.0, v)))] }
        return nil
    }

    @discardableResult
    func write(_ key: String, _ v: Double) -> Bool {
        var t = [CChar](repeating: 0, count: 5)
        var sz: UInt32 = 0
        if smc_key_info(key, &sz, &t) != 0 { return false }
        guard let bytes = SMC.encode(v, String(cString: t)) else { return false }
        return smc_write(key, bytes, UInt32(bytes.count)) == 0
    }

    func keyCount() -> Int { return Int(value("#KEY") ?? 0) }

    func key(at i: Int) -> String? {
        var k = [CChar](repeating: 0, count: 5)
        if smc_key_at(UInt32(i), &k) != 0 { return nil }
        return String(cString: k)
    }
}

// MARK: - Sensors & fans
struct SensorInfo { let key: String; let name: String }

let sensorNames: [String: String] = [
    "TC0D": "CPU Die", "TC0H": "CPU Heatsink", "TC0P": "CPU Proximity", "TCXC": "CPU PECI",
    "TC0C": "CPU Core 1", "TC1C": "CPU Core 2", "TC2C": "CPU Core 3", "TC3C": "CPU Core 4",
    "TCSA": "CPU System Agent", "TG0D": "GPU Die", "TG0H": "GPU Heatsink", "TG0P": "GPU Proximity",
    "TA0P": "Ambient", "TM0P": "Memory Proximity", "TM0S": "Memory Slot",
    "TN0P": "Northbridge Prox.", "TN0D": "Northbridge Die", "TN0H": "Northbridge Heatsink",
    "Th0H": "Drive Heatsink", "TH0P": "Drive Proximity", "Tp0P": "Power Supply Prox.",
    "TW0P": "Wi-Fi Proximity", "TO0P": "Optical Drive"
]

func discoverSensors() -> [SensorInfo] {
    let smc = SMC.shared
    var out: [SensorInfo] = []
    let n = min(smc.keyCount(), 3000)
    var i = 0
    while i < n {
        if let k = smc.key(at: i), k.hasPrefix("T"), let r = smc.raw(k) {
            if r.type == "sp78" || r.type == "flt " {
                if let v = SMC.decode(r.bytes, r.size, r.type), v > 1, v < 130 {
                    out.append(SensorInfo(key: k, name: sensorNames[k] ?? k))
                }
            }
        }
        i += 1
    }
    out.sort { $0.name < $1.name }
    return out
}

func defaultSensorKeys(_ list: [SensorInfo]) -> [String] {
    let keys = list.map { $0.key }
    var out: [String] = []
    let prefs: [[String]] = [["TC0D", "TC0P", "TC0H"], ["TG0D", "TG0P", "TG0H"]]
    for pref in prefs {
        if let k = pref.first(where: { keys.contains($0) }) { out.append(k) }
    }
    if out.isEmpty, let f = list.first(where: { $0.key.hasPrefix("TC") }) { out.append(f.key) }
    if out.isEmpty, let f = list.first { out.append(f.key) }
    return out
}

func fanCount() -> Int { return Int(SMC.shared.value("FNum") ?? 0) }

func hwModel() -> String {
    var size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    if size <= 0 { return "Mac" }
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &buf, &size, nil, 0)
    return String(cString: buf)
}

func marketingName() -> String {
    let m = hwModel()
    if m.hasPrefix("Macmini5") { return "Mac mini (2011)" }
    if m.hasPrefix("Macmini4") { return "Mac mini (2010)" }
    if m.hasPrefix("Macmini6") { return "Mac mini (2012)" }
    if m.hasPrefix("Macmini") { return "Mac mini" }
    return m
}

// MARK: - Config
struct CurvePoint: Codable, Equatable { var t: Double; var p: Double }

struct Config: Codable, Equatable {
    var mode: String = "auto"            // auto | constant | curve
    var profile: String = "auto"         // auto | silent | balanced | performance | max | custom
    var constantPercent: Double = 40
    var sensors: [String] = []           // empty = automatic
    var curve: [CurvePoint] = Presets.curve("balanced")
    var hysteresis: Double = 3
    var rampUp: Double = 20              // % per second
    var rampDown: Double = 4
    var minPercent: Double = 0
    var maxPercent: Double = 100
    var critical: Double = 90
    var interval: Double = 1

    mutating func sanitize() {
        if !["auto", "constant", "curve"].contains(mode) { mode = "auto" }
        constantPercent = min(100, max(0, constantPercent))
        minPercent = min(100, max(0, minPercent))
        maxPercent = min(100, max(minPercent, maxPercent))
        hysteresis = min(15, max(0, hysteresis))
        rampUp = min(100, max(0.5, rampUp))
        rampDown = min(100, max(0.5, rampDown))
        critical = min(105, max(60, critical))
        interval = min(10, max(0.5, interval))
        var c: [CurvePoint] = curve.map { CurvePoint(t: min(110, max(0, $0.t)), p: min(100, max(0, $0.p))) }
        c.sort { $0.t < $1.t }
        if c.count < 2 { c = Presets.curve("balanced") }
        curve = c
    }
}

enum Presets {
    static let names: [String] = ["auto", "silent", "balanced", "performance", "max"]

    static func title(_ n: String) -> String {
        switch n {
        case "auto": return "Auto"
        case "silent": return "Silent"
        case "balanced": return "Balanced"
        case "performance": return "Performance"
        case "max": return "Max"
        default: return "Custom"
        }
    }

    static func curve(_ n: String) -> [CurvePoint] {
        var raw: [(Double, Double)]
        switch n {
        case "silent": raw = [(40, 0), (60, 10), (70, 30), (80, 65), (88, 100)]
        case "performance": raw = [(35, 20), (50, 40), (60, 65), (70, 90), (78, 100)]
        default: raw = [(40, 5), (55, 20), (65, 40), (75, 70), (85, 100)]
        }
        return raw.map { CurvePoint(t: $0.0, p: $0.1) }
    }
}

func interpCurve(_ pts: [CurvePoint], _ t: Double) -> Double {
    let c = pts.sorted { $0.t < $1.t }
    guard let f = c.first, let l = c.last else { return 100 }
    if t <= f.t { return f.p }
    if t >= l.t { return l.p }
    var i = 0
    while i < c.count - 1 {
        let a = c[i], b = c[i + 1]
        if t >= a.t && t <= b.t { return b.t == a.t ? a.p : a.p + (b.p - a.p) * (t - a.t) / (b.t - a.t) }
        i += 1
    }
    return 100
}

struct DaemonStatus: Codable {
    var ts: Double
    var pid: Int
    var mode: String
    var pct: Double
    var rpm: Double
    var temp: Double
    var manual: Bool
    var error: String
}
