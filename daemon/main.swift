import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
func log(_ s: String) { print("minifand: " + s) }

let smc = SMC.shared
if !smc.ok { log("cannot open AppleSMC"); exit(1) }

let nFans = max(1, fanCount())
let hasFS = smc.raw("FS! ") != nil
var hwMin: [Double] = []
var hwMax: [Double] = []
var origMin: [Double] = []
for i in 0..<nFans {
    let mn = smc.value("F\(i)Mn") ?? 1800
    let mx = smc.value("F\(i)Mx") ?? 5500
    hwMin.append(mn); origMin.append(mn); hwMax.append(max(mx, mn + 100))
}
let sensorList = discoverSensors()
log("fans: \(nFans), forced-mode key: \(hasFS), sensors: \(sensorList.count)")

var cfg = Config()
var cfgMTime: Date? = nil
var manual = false
var curPct: Double? = nil
var effTemp: Double? = nil
var lastTick = Date.distantPast
var lastTemp = -1.0
var lastRPM = 0.0
var lastErr = ""

func loadConfig() {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
          let mt = attrs[.modificationDate] as? Date else { return }
    if let old = cfgMTime, old == mt { return }
    cfgMTime = mt
    guard let data = FileManager.default.contents(atPath: configPath),
          var c = try? JSONDecoder().decode(Config.self, from: data) else {
        log("bad config, keeping previous"); return
    }
    c.sanitize()
    cfg = c
    log("config loaded, mode = \(c.mode)")
}

func forced(_ on: Bool) {
    if !hasFS { return }
    let want: Double = on ? Double((1 << nFans) - 1) : 0
    if smc.value("FS! ") != want { smc.write("FS! ", want) }
}

func releaseFans() {
    if hasFS {
        forced(false)
    } else {
        for i in 0..<nFans { smc.write("F\(i)Mn", origMin[i]) }
    }
    manual = false
    curPct = nil
}

func applyPercent(_ pct: Double) {
    forced(true)
    for i in 0..<nFans {
        let rpm = hwMin[i] + pct / 100.0 * (hwMax[i] - hwMin[i])
        smc.write(hasFS ? "F\(i)Tg" : "F\(i)Mn", rpm)
        if i == 0 { lastRPM = rpm }
    }
    manual = true
}

func currentPercent() -> Double {
    let a = smc.value("F0Ac") ?? hwMin[0]
    return min(100, max(0, (a - hwMin[0]) / (hwMax[0] - hwMin[0]) * 100))
}

func writeStatus() {
    let st = DaemonStatus(ts: Date().timeIntervalSince1970, pid: Int(getpid()), mode: cfg.mode,
                          pct: curPct ?? -1, rpm: manual ? lastRPM : 0, temp: lastTemp,
                          manual: manual, error: lastErr)
    if let d = try? JSONEncoder().encode(st) {
        try? d.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
    }
}

func tick() {
    loadConfig()
    let now = Date()
    let rawDt = now.timeIntervalSince(lastTick)
    if rawDt < cfg.interval - 0.05 { return }
    lastTick = now
    let dt = min(5.0, rawDt)

    let keys = cfg.sensors.isEmpty ? defaultSensorKeys(sensorList) : cfg.sensors
    var vals: [Double] = []
    for k in keys {
        if let v = smc.value(k), v > 0, v < 130 { vals.append(v) }
    }
    let temp = vals.max()
    lastTemp = temp ?? -1
    lastErr = ""

    var target: Double? = nil
    var immediate = false
    if cfg.mode == "constant" {
        target = cfg.constantPercent
    } else if cfg.mode == "curve" {
        if let t = temp {
            if effTemp == nil || t >= effTemp! || effTemp! - t > cfg.hysteresis { effTemp = t }
            target = interpCurve(cfg.curve, effTemp ?? t)
        } else {
            target = 100; immediate = true
            lastErr = "No valid temperature sensor - fan forced to maximum"
        }
    }
    if var tg = target {
        if !immediate { tg = min(cfg.maxPercent, max(cfg.minPercent, tg)) }
        if let t = temp, t >= cfg.critical { tg = 100; immediate = true }
        if curPct == nil { curPct = currentPercent() }
        var next = tg
        if let c = curPct, !immediate {
            let step = (tg > c ? cfg.rampUp : cfg.rampDown) * dt
            next = tg > c ? min(tg, c + step) : max(tg, c - step)
        }
        curPct = next
        applyPercent(next)
    } else if manual {
        releaseFans()
    }
    writeStatus()
}

signal(SIGTERM, SIG_IGN)
signal(SIGINT, SIG_IGN)
var sigSources: [DispatchSourceSignal] = []
for s in [SIGTERM, SIGINT] {
    let src = DispatchSource.makeSignalSource(signal: s, queue: DispatchQueue.main)
    src.setEventHandler {
        log("stopping, restoring automatic fan control")
        releaseFans()
        exit(0)
    }
    src.resume()
    sigSources.append(src)
}

let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
timer.schedule(deadline: .now(), repeating: .milliseconds(500))
timer.setEventHandler { tick() }
timer.resume()
dispatchMain()
