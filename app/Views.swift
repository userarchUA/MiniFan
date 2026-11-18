import SwiftUI
import AppKit

// MARK: - Theme
enum Theme {
    static let cyan = Color(red: 0.27, green: 0.84, blue: 1.0)
    static let violet = Color(red: 0.58, green: 0.42, blue: 1.0)
    static let green = Color(red: 0.30, green: 0.90, blue: 0.62)
    static let amber = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let orange = Color(red: 1.0, green: 0.55, blue: 0.25)
    static let red = Color(red: 1.0, green: 0.32, blue: 0.38)
    static let card = Color.white.opacity(0.055)
    static let stroke = Color.white.opacity(0.09)
    static let dim = Color.white.opacity(0.55)
    static let accent = LinearGradient(gradient: Gradient(colors: [Color(red: 0.27, green: 0.84, blue: 1.0), Color(red: 0.58, green: 0.42, blue: 1.0)]),
                                       startPoint: .leading, endPoint: .trailing)

    static func tempColor(_ t: Double) -> Color {
        if t < 50 { return green }
        if t < 65 { return cyan }
        if t < 78 { return amber }
        if t < 88 { return orange }
        return red
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - Reusable pieces
struct Card<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .kerning(1.2)
                    .foregroundColor(Theme.dim)
            }
            content
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(subtitle).font(.system(size: 13, design: .rounded)).foregroundColor(Theme.dim)
        }
    }
}

struct Pill: View {
    let text: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(selected ? Color.white : Theme.dim)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(pillBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    var pillBackground: some View {
        ZStack {
            if selected {
                Capsule().fill(Theme.accent)
            } else {
                Capsule().fill(Color.white.opacity(0.07))
            }
        }
    }
}

struct NiceSwitch: View {
    let isOn: Binding<Bool>
    var body: some View {
        ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
            Capsule().fill(isOn.wrappedValue ? Theme.cyan.opacity(0.85) : Color.white.opacity(0.14)).frame(width: 42, height: 24)
            Circle().fill(Color.white).frame(width: 18, height: 18).padding(.horizontal, 3)
        }
        .animation(.easeOut(duration: 0.15))
        .onTapGesture { self.isOn.wrappedValue.toggle() }
    }
}

struct SwitchRow: View {
    let title: String
    let detail: String
    let isOn: Binding<Bool>
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Text(detail).font(.system(size: 11)).foregroundColor(Theme.dim)
            }
            Spacer()
            NiceSwitch(isOn: isOn)
        }
    }
}

struct SliderRow: View {
    let title: String
    let detail: String
    let valueText: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Spacer()
                Text(valueText).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundColor(Theme.cyan)
            }
            Slider(value: value, in: range, step: step).accentColor(Theme.cyan)
            Text(detail).font(.system(size: 11)).foregroundColor(Theme.dim)
        }
    }
}

struct LineShape: Shape {
    let values: [Double]
    let lo: Double
    let hi: Double
    let closed: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if values.count < 2 { return p }
        let span = max(0.001, hi - lo)
        for (i, v) in values.enumerated() {
            let x = r.minX + r.width * CGFloat(i) / CGFloat(values.count - 1)
            let frac = min(1.0, max(0.0, (v - lo) / span))
            let y = r.maxY - r.height * CGFloat(frac)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        if closed {
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
        return p
    }
}

struct RPMGauge: View {
    let value: Double
    let maxValue: Double
    let caption: String
    let animated: Bool
    var frac: Double { return min(1, max(0, value / max(1, maxValue))) }
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: CGFloat(0.75 * frac))
                .stroke(AngularGradient(gradient: Gradient(colors: [Theme.cyan, Theme.violet, Theme.red]),
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(animated ? Animation.easeOut(duration: 0.6) : nil)
            VStack(spacing: 2) {
                Text(String(Int(value))).font(.system(size: 50, weight: .bold, design: .rounded)).foregroundColor(.white)
                Text("RPM").font(.system(size: 12, weight: .semibold, design: .rounded)).kerning(2).foregroundColor(Theme.dim)
                Text(caption).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.cyan).padding(.top, 4)
            }
        }
        .frame(width: 230, height: 230)
    }
}

// MARK: - Root, sidebar
struct RootView: View {
    @ObservedObject var m: Model
    var body: some View {
        ZStack {
            Background(lite: m.lite)
            HStack(spacing: 0) {
                SidebarView(m: m)
                Rectangle().fill(Theme.stroke).frame(width: 1)
                PageView(m: m)
            }
        }
        .frame(minWidth: 960, minHeight: 660)
    }
}

struct Background: View {
    let lite: Bool
    var body: some View {
        ZStack {
            if !lite { VisualEffect() }
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.11).opacity(lite ? 1.0 : 0.78),
                                                       Color(red: 0.10, green: 0.07, blue: 0.18).opacity(lite ? 1.0 : 0.78)]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct PageView: View {
    @ObservedObject var m: Model
    var body: some View {
        Group {
            if m.page == 0 { DashboardView(m: m) }
            else if m.page == 1 { CurveView(m: m) }
            else if m.page == 2 { SensorsView(m: m) }
            else { SettingsView(m: m) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NavItem: View {
    let icon: String
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon).font(.system(size: 16)).frame(width: 22)
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundColor(selected ? Color.white : Theme.dim)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(navBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    var navBackground: some View {
        ZStack {
            if selected {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Theme.cyan.opacity(0.35), lineWidth: 1)
            }
        }
    }
}

struct SidebarView: View {
    @ObservedObject var m: Model
    let items: [(String, String)] = [("◎", "Dashboard"), ("∿", "Fan Curve"), ("≋", "Sensors"), ("⚙︎", "Settings")]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent).frame(width: 36, height: 36)
                    Text("✺").font(.system(size: 20)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MiniFan").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text(m.modelName).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.dim)
                }
            }
            .padding(.top, 36)
            .padding(.bottom, 22)
            ForEach(0..<items.count, id: \.self) { i in
                NavItem(icon: self.items[i].0, title: self.items[i].1, selected: self.m.page == i) { self.m.page = i }
            }
            Spacer()
            ServiceChip(m: m)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .frame(width: 214)
    }
}

struct ServiceChip: View {
    @ObservedObject var m: Model
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(m.daemonRunning ? Theme.green : Theme.red).frame(width: 8, height: 8)
            Text(m.daemonRunning ? "Service running" : "Service not running")
                .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(Theme.dim)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
    }
}

// MARK: - Dashboard
struct ProfileBar: View {
    @ObservedObject var m: Model
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Presets.names, id: \.self) { n in
                Pill(text: Presets.title(n), selected: self.m.activeProfile == n) { self.m.applyProfile(n) }
            }
            if m.activeProfile == "custom" {
                Pill(text: "Custom", selected: true) {}
            }
            Spacer()
        }
    }
}

struct DaemonBanner: View {
    @ObservedObject var m: Model
    var body: some View {
        Group {
            if !m.daemonRunning || !m.saveError.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Text("⚠︎").font(.system(size: 22)).foregroundColor(Theme.amber)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Фоновая служба не запущена").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                        Text("Показания видны, но вентилятором управляет только служба. В папке проекта выполни:  sudo ./install.sh")
                            .font(.system(size: 12)).foregroundColor(Theme.dim)
                        if !m.saveError.isEmpty {
                            Text(m.saveError).font(.system(size: 12)).foregroundColor(Theme.red)
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.amber.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.amber.opacity(0.35), lineWidth: 1))
            }
        }
    }
}

struct GaugeCard: View {
    @ObservedObject var m: Model
    var caption: String {
        if let s = m.status, s.manual, s.rpm > 0 { return "target \(Int(s.rpm)) rpm" }
        return "system auto"
    }
    var body: some View {
        Card("Fan") {
            VStack(spacing: 10) {
                RPMGauge(value: m.rpmNow, maxValue: m.rpmMax, caption: caption, animated: !m.lite)
                HStack {
                    stat("MIN", String(Int(m.rpmMin)))
                    Spacer()
                    stat("MODE", m.config.mode.uppercased())
                    Spacer()
                    stat("MAX", String(Int(m.rpmMax)))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    func stat(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white)
            Text(k).font(.system(size: 10, weight: .semibold, design: .rounded)).kerning(1.5).foregroundColor(Theme.dim)
        }
    }
}

struct MiniBar: View {
    let name: String
    let text: String
    let value: Double
    var body: some View {
        HStack(spacing: 10) {
            Text(name).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.dim).frame(width: 130, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Theme.tempColor(self.value)).frame(width: g.size.width * CGFloat(min(1.0, max(0.02, self.value / 110.0))))
                }
            }
            .frame(height: 6)
            Text(text).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.white).frame(width: 52, alignment: .trailing)
        }
    }
}

struct TempCard: View {
    @ObservedObject var m: Model
    var body: some View {
        Card("Temperature") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(m.primaryTemp == nil ? "--" : m.tempNumber(m.primaryTemp ?? 0))
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.tempColor(m.primaryTemp ?? 0))
                    Text(m.useFahrenheit ? "°F" : "°C").font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundColor(Theme.dim)
                }
                Text("Control source · " + m.primaryName).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.dim)
                VStack(spacing: 9) {
                    ForEach(Array(m.sensors.prefix(6))) { s in
                        MiniBar(name: s.name, text: self.m.temp(s.value), value: s.value)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HistoryCard: View {
    @ObservedObject var m: Model
    var body: some View {
        Card("History · last 2.5 min") {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    LineShape(values: m.rpmHistory, lo: 0, hi: m.rpmMax, closed: true)
                        .fill(LinearGradient(gradient: Gradient(colors: [Theme.cyan.opacity(0.25), Theme.cyan.opacity(0.0)]), startPoint: .top, endPoint: .bottom))
                    LineShape(values: m.rpmHistory, lo: 0, hi: m.rpmMax, closed: false)
                        .stroke(Theme.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    LineShape(values: m.tempHistory, lo: 20, hi: 100, closed: false)
                        .stroke(Theme.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 150)
                HStack(spacing: 18) {
                    legend(Theme.orange, "Temperature")
                    legend(Theme.cyan, "Fan speed")
                }
            }
        }
    }
    func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t).font(.system(size: 11, design: .rounded)).foregroundColor(Theme.dim)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var m: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Dashboard", subtitle: "Live fan and temperature overview")
                DaemonBanner(m: m)
                ProfileBar(m: m)
                HStack(alignment: .top, spacing: 18) {
                    GaugeCard(m: m).frame(width: 300)
                    TempCard(m: m)
                }
                HistoryCard(m: m)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Curve editor
struct Plot {
    let size: CGSize
    let tMin = 30.0
    let tMax = 100.0
    let padL: CGFloat = 44
    let padR: CGFloat = 62
    let padT: CGFloat = 16
    let padB: CGFloat = 32
    var pw: CGFloat { return size.width - padL - padR }
    var ph: CGFloat { return size.height - padT - padB }
    func x(_ t: Double) -> CGFloat { return padL + CGFloat((t - tMin) / (tMax - tMin)) * pw }
    func y(_ p: Double) -> CGFloat { return padT + ph - CGFloat(p / 100.0) * ph }
    func t(_ x: CGFloat) -> Double { return tMin + Double((x - padL) / pw) * (tMax - tMin) }
    func p(_ y: CGFloat) -> Double { return Double((padT + ph - y) / ph) * 100.0 }
}

struct CurveEditor: View {
    @ObservedObject var m: Model
    @State private var active: Int? = nil

    var body: some View {
        GeometryReader { g in self.canvas(Plot(size: g.size)) }
    }

    func canvas(_ pl: Plot) -> some View {
        let pts = m.config.curve
        return ZStack(alignment: .topLeading) {
            gridLayer(pl)
            curveLayer(pl, pts)
            liveLayer(pl)
            handles(pl, pts)
        }
        .coordinateSpace(name: "plot")
    }

    func gridLayer(_ pl: Plot) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach([30, 40, 50, 60, 70, 80, 90, 100], id: \.self) { t in
                Path { p in
                    p.move(to: CGPoint(x: pl.x(Double(t)), y: pl.padT))
                    p.addLine(to: CGPoint(x: pl.x(Double(t)), y: pl.padT + pl.ph))
                }.stroke(Color.white.opacity(0.06), lineWidth: 1)
                Text(String(t) + "°").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.dim)
                    .position(x: pl.x(Double(t)), y: pl.padT + pl.ph + 16)
            }
            ForEach([0, 20, 40, 60, 80, 100], id: \.self) { v in
                Path { p in
                    p.move(to: CGPoint(x: pl.padL, y: pl.y(Double(v))))
                    p.addLine(to: CGPoint(x: pl.padL + pl.pw, y: pl.y(Double(v))))
                }.stroke(Color.white.opacity(0.06), lineWidth: 1)
                Text(String(v) + "%").font(.system(size: 10, design: .rounded)).foregroundColor(Theme.dim)
                    .position(x: pl.padL - 20, y: pl.y(Double(v)))
                Text(String(self.m.rpmFor(percent: Double(v)))).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.dim.opacity(0.8))
                    .position(x: pl.padL + pl.pw + 30, y: pl.y(Double(v)))
            }
        }
    }

    func curvePath(_ pl: Plot, _ pts: [CurvePoint], closed: Bool) -> Path {
        var path = Path()
        guard let f = pts.first, let l = pts.last else { return path }
        path.move(to: CGPoint(x: pl.x(pl.tMin), y: pl.y(f.p)))
        for pt in pts { path.addLine(to: CGPoint(x: pl.x(pt.t), y: pl.y(pt.p))) }
        path.addLine(to: CGPoint(x: pl.x(pl.tMax), y: pl.y(l.p)))
        if closed {
            path.addLine(to: CGPoint(x: pl.x(pl.tMax), y: pl.y(0)))
            path.addLine(to: CGPoint(x: pl.x(pl.tMin), y: pl.y(0)))
            path.closeSubpath()
        }
        return path
    }

    func curveLayer(_ pl: Plot, _ pts: [CurvePoint]) -> some View {
        let line = curvePath(pl, pts, closed: false)
        let area = curvePath(pl, pts, closed: true)
        return ZStack {
            area.fill(LinearGradient(gradient: Gradient(colors: [Theme.cyan.opacity(0.28), Theme.violet.opacity(0.02)]), startPoint: .top, endPoint: .bottom))
            line.stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    func liveLayer(_ pl: Plot) -> some View {
        Group {
            if m.primaryTemp != nil { self.liveMarker(pl, m.primaryTemp ?? 0) }
        }
    }

    func liveMarker(_ pl: Plot, _ temp: Double) -> some View {
        let tt = min(pl.tMax, max(pl.tMin, temp))
        let pct = interpCurve(m.config.curve, tt)
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: pl.x(tt), y: pl.padT))
                p.addLine(to: CGPoint(x: pl.x(tt), y: pl.padT + pl.ph))
            }.stroke(Theme.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            Circle().fill(Theme.orange).frame(width: 10, height: 10).position(x: pl.x(tt), y: pl.y(pct))
            Text(m.temp(temp) + " → " + String(Int(pct.rounded())) + "%")
                .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(Theme.orange)
                .position(x: min(pl.padL + pl.pw - 40, max(pl.padL + 40, pl.x(tt))), y: pl.padT + 8)
        }
    }

    func handles(_ pl: Plot, _ pts: [CurvePoint]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<pts.count, id: \.self) { i in
                self.handle(pl, i, pts[i])
            }
        }
    }

    func handle(_ pl: Plot, _ i: Int, _ pt: CurvePoint) -> some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 16, height: 16)
            Circle().stroke(Theme.cyan, lineWidth: 3).frame(width: 16, height: 16)
            if active == i {
                Text(m.temp(pt.t) + " → " + String(Int(pt.p)) + "% · " + String(m.rpmFor(percent: pt.p)) + " rpm")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .fixedSize()
                    .offset(x: 0, y: -26)
            }
        }
        .frame(width: 24, height: 24)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("plot"))
                .onChanged { v in
                    self.active = i
                    self.move(i, v.location, pl)
                }
                .onEnded { _ in self.active = nil }
        )
        .contextMenu {
            Button("Remove point") { self.m.removePoint(i) }
        }
        .position(x: pl.x(pt.t), y: pl.y(pt.p))
    }

    func move(_ i: Int, _ loc: CGPoint, _ pl: Plot) {
        var c = m.config.curve
        if i >= c.count { return }
        let lo = i > 0 ? c[i - 1].t + 1 : pl.tMin
        let hi = i < c.count - 1 ? c[i + 1].t - 1 : pl.tMax
        let t = min(hi, max(lo, pl.t(loc.x).rounded()))
        let p = min(100.0, max(0.0, pl.p(loc.y).rounded()))
        c[i] = CurvePoint(t: t, p: p)
        m.setCurve(c)
    }
}

struct CurveView: View {
    @ObservedObject var m: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Fan Curve", subtitle: "Drag points · right-click a point to remove it")
                if m.config.mode != "curve" {
                    HStack {
                        Text("Управление по кривой выключено (режим: " + m.config.mode + ")")
                            .font(.system(size: 13, design: .rounded)).foregroundColor(Theme.amber)
                        Spacer()
                        Pill(text: "Enable curve control", selected: true) { self.m.setMode("curve") }
                    }
                }
                Card {
                    CurveEditor(m: m).frame(height: 390)
                }
                HStack(spacing: 8) {
                    Pill(text: "＋ Add point", selected: false) { self.m.addPoint() }
                    Text("Load preset:").font(.system(size: 12, design: .rounded)).foregroundColor(Theme.dim).padding(.leading, 10)
                    ForEach(["silent", "balanced", "performance"], id: \.self) { n in
                        Pill(text: Presets.title(n), selected: false) { self.m.setCurve(Presets.curve(n)) }
                    }
                    Spacer()
                }
                Text("Вертикальная ось: процент диапазона вентилятора (0% = минимум SMC, 100% = максимум). Справа — примерные обороты.")
                    .font(.system(size: 11)).foregroundColor(Theme.dim)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Sensors
struct SensorRow: View {
    let name: String
    let key: String
    let value: Double
    let used: Bool
    let text: String
    let toggle: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(used ? Theme.cyan : Color.white.opacity(0.10)).frame(width: 22, height: 22)
                    if used { Text("✓").font(.system(size: 13, weight: .bold)).foregroundColor(Color.black) }
                }
            }
            .buttonStyle(PlainButtonStyle())
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                Text(key).font(.system(size: 10, design: .monospaced)).foregroundColor(Theme.dim)
            }
            .frame(width: 200, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Theme.tempColor(self.value)).frame(width: g.size.width * CGFloat(min(1.0, max(0.02, self.value / 110.0))))
                }
            }
            .frame(height: 7)
            Text(text).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(.white).frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

struct SensorsView: View {
    @ObservedObject var m: Model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Sensors", subtitle: "Отмеченные датчики управляют вентилятором (берётся максимум)")
                Card("All sensors · \(m.sensors.count)") {
                    VStack(spacing: 2) {
                        ForEach(m.sensors) { s in
                            SensorRow(name: s.name, key: s.id, value: s.value, used: self.m.effectiveKeys.contains(s.id),
                                      text: self.m.temp(s.value)) { self.m.toggleSensor(s.id) }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @ObservedObject var m: Model

    var modeBinding: Binding<String> {
        return Binding<String>(get: { self.m.config.mode }, set: { self.m.setMode($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: "Settings", subtitle: "Тонкая настройка поведения вентилятора")
                controlCard
                responseCard
                interfaceCard
                safetyCard
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
    }

    var controlCard: some View {
        Card("Control mode") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("", selection: modeBinding) {
                    Text("Auto (system)").tag("auto")
                    Text("Constant").tag("constant")
                    Text("Curve").tag("curve")
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                SliderRow(title: "Constant speed", detail: "Используется в режиме Constant",
                          valueText: String(Int(m.config.constantPercent)) + "%  ·  " + String(m.rpmFor(percent: m.config.constantPercent)) + " rpm",
                          value: m.bind(\.constantPercent), range: 0...100, step: 1)
            }
        }
    }

    var responseCard: some View {
        Card("Response") {
            VStack(alignment: .leading, spacing: 18) {
                SliderRow(title: "Hysteresis", detail: "Скорость не падает, пока температура не снизится на это значение — нет «дёрганья»",
                          valueText: String(format: "%.1f °C", m.config.hysteresis), value: m.bind(\.hysteresis), range: 0...10, step: 0.5)
                SliderRow(title: "Ramp up", detail: "Как быстро вентилятор разгоняется (процентов диапазона в секунду)",
                          valueText: String(format: "%.0f %%/s", m.config.rampUp), value: m.bind(\.rampUp), range: 1...100, step: 1)
                SliderRow(title: "Ramp down", detail: "Как плавно вентилятор замедляется — меньше значение, тише и ровнее звук",
                          valueText: String(format: "%.1f %%/s", m.config.rampDown), value: m.bind(\.rampDown), range: 0.5...50, step: 0.5)
                SliderRow(title: "Minimum speed", detail: "Нижняя граница для кривой",
                          valueText: String(Int(m.config.minPercent)) + "%", value: m.bind(\.minPercent), range: 0...60, step: 1)
                SliderRow(title: "Maximum speed", detail: "Верхняя граница для кривой (критическая температура всё равно даёт 100%)",
                          valueText: String(Int(m.config.maxPercent)) + "%", value: m.bind(\.maxPercent), range: 40...100, step: 1)
                SliderRow(title: "Critical temperature", detail: "При достижении вентилятор мгновенно уходит на максимум",
                          valueText: String(Int(m.config.critical)) + " °C", value: m.bind(\.critical), range: 70...100, step: 1)
                SliderRow(title: "Update interval", detail: "Как часто служба пересчитывает скорость",
                          valueText: String(format: "%.1f s", m.config.interval), value: m.bind(\.interval), range: 0.5...5, step: 0.5)
            }
        }
    }

    var interfaceCard: some View {
        Card("Interface") {
            VStack(alignment: .leading, spacing: 16) {
                SwitchRow(title: "Fahrenheit", detail: "Показывать температуру в °F", isOn: $m.useFahrenheit)
                SwitchRow(title: "Menu bar item", detail: "Температура и обороты в строке меню + быстрые профили", isOn: $m.showMenuBar)
                SwitchRow(title: "Launch at login", detail: "Открывать MiniFan при входе в систему", isOn: $m.launchAtLogin)
                SwitchRow(title: "Lite mode", detail: "Без прозрачности и анимаций — для слабой графики старого Mac", isOn: $m.lite)
            }
        }
    }

    var safetyCard: some View {
        Card("Safety") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Если датчики недоступны, служба ставит вентилятор на максимум. При остановке службы управление возвращается системе (Auto).")
                    .font(.system(size: 12)).foregroundColor(Theme.dim)
                HStack(spacing: 8) {
                    Pill(text: "Restore automatic control", selected: false) { self.m.applyProfile("auto") }
                    Pill(text: "Reset curve", selected: false) { self.m.setCurve(Presets.curve("balanced")) }
                }
            }
        }
    }
}
