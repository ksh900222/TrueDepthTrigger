import SwiftUI
import AVFoundation
import CoreBluetooth
import Metal
import MetalKit

struct ContentView: View {
    @StateObject private var app = TriggerApp()

    private var displayMinBinding: Binding<Double> {
        Binding(
            get: { app.displayMin },
            set: { newValue in
                app.displayMin = min(max(0.15, newValue), app.displayMax)
                app.pushUniforms()
            }
        )
    }

    private var displayMaxBinding: Binding<Double> {
        Binding(
            get: { app.displayMax },
            set: { newValue in
                app.displayMax = max(min(2.00, newValue), app.displayMin)
                app.pushUniforms()
            }
        )
    }

    private var detectMinBinding: Binding<Double> {
        Binding(
            get: { app.detectMin },
            set: { newValue in
                app.detectMin = min(max(0.15, newValue), app.detectMax)
            }
        )
    }

    private var detectMaxBinding: Binding<Double> {
        Binding(
            get: { app.detectMax },
            set: { newValue in
                app.detectMax = max(min(2.00, newValue), app.detectMin)
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            CameraPreview(session: app.session)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if app.renderer.isReady && app.isRunning {
                MetalDepthView(renderer: app.renderer)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.status)
                            .font(.headline)
                        Text(app.depthReady
                             ? String(format: "최소  %.2f m", app.minMeters)
                             : "거리 측정 대기 중")
                        Text(app.depthReady
                             ? String(format: "최대  %.2f m", app.maxMeters)
                             : " ")
                        Text(app.inRange ? "검출 범위 안 → True 전송" : "검출 범위 밖")
                            .foregroundStyle(app.inRange ? .green : .secondary)
                        Text(app.ble.isReadyToSend ? "전송 준비됨" : "localhost.localdomain 대기")
                            .font(.caption)
                        Text(String(format: "표시  %.2f ~ %.2f m", app.displayMin, app.displayMax))
                            .font(.caption)
                        Text(String(format: "검출  %.2f ~ %.2f m", app.detectMin, app.detectMax))
                            .font(.caption)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Spacer()

                    Button(app.isRunning ? "실행 종료" : "다시 시작") {
                        if app.isRunning { app.stop() } else { app.start() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(app.isRunning ? .red : .green)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("표시 범위")
                        .font(.headline)

                    Stepper(value: displayMinBinding, in: 0.15...2.00, step: 0.01) {
                        Text(String(format: "하한  %.2f m", app.displayMin))
                    }

                    Slider(value: displayMinBinding, in: 0.15...2.00, step: 0.01)

                    Stepper(value: displayMaxBinding, in: 0.15...2.00, step: 0.01) {
                        Text(String(format: "상한  %.2f m", app.displayMax))
                    }

                    Slider(value: displayMaxBinding, in: 0.15...2.00, step: 0.01)

                    Divider()

                    HStack {
                        Text("검출 범위")
                            .font(.headline)
                        Spacer()
                        Button(app.isEditingDetect ? "완료" : "설정") {
                            app.isEditingDetect.toggle()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(app.isEditingDetect ? .orange : .blue)
                    }

                    if app.isEditingDetect {
                        Text("이 범위 안에 들어오면 True를 보냅니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Stepper(value: detectMinBinding, in: 0.15...2.00, step: 0.01) {
                            Text(String(format: "하한  %.2f m", app.detectMin))
                        }

                        Slider(value: detectMinBinding, in: 0.15...2.00, step: 0.01)

                        Stepper(value: detectMaxBinding, in: 0.15...2.00, step: 0.01) {
                            Text(String(format: "상한  %.2f m", app.detectMax))
                        }

                        Slider(value: detectMaxBinding, in: 0.15...2.00, step: 0.01)
                    } else {
                        Text(String(format: "%.2f ~ %.2f m", app.detectMin, app.detectMax))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Text("BLE 기기")
                        .font(.headline)

                    Text("찾을 이름")
                        .font(.caption)
                    TextField("localhost.localdomain", text: $app.ble.targetName)
                        .textFieldStyle(.roundedBorder)

                    if app.ble.devices.isEmpty {
                        Text("'\(app.ble.targetName)' 을 찾지 못했습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("기기 선택", selection: Binding(
                            get: { app.ble.selectedID },
                            set: { newValue in
                                app.ble.selectedID = newValue
                                app.ble.useSelected()
                            }
                        )) {
                            ForEach(app.ble.devices) { device in
                                Text(device.name).tag(device.id as UUID?)
                            }
                        }
                    }

                    HStack {
                        Button("목록 새로고침") { app.ble.refresh() }
                        Button("이 기기 사용") { app.ble.useSelected() }
                            .disabled(app.ble.selectedID == nil)
                    }
                    .buttonStyle(.bordered)

                    HStack {
                        Text("투명도")
                        Slider(value: $app.opacity, in: 0.25...1.0)
                    }

                    Picker("회전", selection: $app.rotation) {
                        Text("0°").tag(0)
                        Text("90° 반시계").tag(1)
                        Text("180°").tag(2)
                        Text("90° 시계").tag(3)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
                .allowsHitTesting(true)
            }
            .padding()
        }
        .onChange(of: app.opacity) { _ in app.pushUniforms() }
        .onChange(of: app.rotation) { _ in app.pushUniforms() }
        .onAppear { app.start() }
        .onDisappear { app.stop() }
    }
}

struct BLEDeviceItem: Identifiable, Hashable {
    let id: UUID
    let name: String
}

final class TriggerApp: NSObject, ObservableObject {
    let session = AVCaptureSession()
    let renderer = DepthMetalRenderer()
    @Published var ble = BLEClient()

    @Published var status = "준비 중"
    @Published var minMeters: Double = 0
    @Published var maxMeters: Double = 0
    @Published var depthReady = false
    @Published var inRange = false
    @Published var isRunning = false
    @Published var displayMin: Double = 0.25
    @Published var displayMax: Double = 0.80
    @Published var detectMin: Double = 0.25
    @Published var detectMax: Double = 0.80
    @Published var isEditingDetect = false
    @Published var opacity: Float = 0.85
    @Published var rotation: Int = 0

    private let queue = DispatchQueue(label: "depth")
    private let depthOutput = AVCaptureDepthDataOutput()
    private var lastSend = Date.distantPast
    private var lastText = Date.distantPast
    private var configured = false

    var displayStart: Float { Float(min(displayMin, displayMax)) }
    var displayEnd: Float { Float(max(displayMin, displayMax)) }
    var detectStart: Float { Float(min(detectMin, detectMax)) }
    var detectEnd: Float { Float(max(detectMin, detectMax)) }

    func pushUniforms() {
        renderer.nearLimit = displayStart
        renderer.farLimit = displayEnd
        renderer.opacity = opacity
        renderer.rotation = Int32(rotation)
    }

    func start() {
        pushUniforms()
        ble.refresh()
        Task {
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            guard ok else {
                await MainActor.run { status = "카메라 권한이 필요합니다" }
                return
            }
            await setupCamera()
        }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
        DispatchQueue.main.async {
            self.isRunning = false
            self.status = "정지됨"
        }
    }

    @MainActor
    private func setupCamera() {
        if session.isRunning {
            isRunning = true
            status = renderer.isReady ? "측정 중" : renderer.errorMessage
            return
        }
        if !renderer.isReady { status = renderer.errorMessage }

        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(
            .builtInTrueDepthCamera,
            for: .video,
            position: .front
        ) else {
            status = "TrueDepth 카메라가 없습니다"
            session.commitConfiguration()
            return
        }

        if !configured {
            if let best = device.formats
                .filter({ !$0.supportedDepthDataFormats.isEmpty })
                .max(by: {
                    CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                    < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
                }) {
                try? device.lockForConfiguration()
                device.activeFormat = best
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                if let depthFormat = best.supportedDepthDataFormats.max(by: {
                    CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                    < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
                }) {
                    device.activeDepthDataFormat = depthFormat
                }
                device.unlockForConfiguration()
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) { session.addInput(input) }
            } catch {
                status = "카메라를 열 수 없습니다"
                session.commitConfiguration()
                return
            }

            depthOutput.isFilteringEnabled = false
            depthOutput.alwaysDiscardsLateDepthData = true
            depthOutput.setDelegate(self, callbackQueue: queue)
            if session.canAddOutput(depthOutput) { session.addOutput(depthOutput) }
            if let connection = depthOutput.connection(with: .depthData) {
                connection.isEnabled = true
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .landscapeRight
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            configured = true
        }

        session.commitConfiguration()
        queue.async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.status = self.renderer.isReady ? "측정 중" : self.renderer.errorMessage
            }
        }
    }
}

extension TriggerApp: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        let map = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        renderer.updateDepth(map)

        let lo = detectStart
        let hi = detectEnd
        guard let range = minMaxDepth(map) else { return }
        let inside = range.min >= lo && range.min <= hi
        let now = Date()

        if now.timeIntervalSince(lastText) > 0.10 {
            lastText = now
            DispatchQueue.main.async {
                self.minMeters = Double(range.min)
                self.maxMeters = Double(range.max)
                self.depthReady = true
                self.inRange = inside
            }
        }

        guard inside, ble.isReadyToSend else { return }
        guard now.timeIntervalSince(lastSend) > 1.0 else { return }
        lastSend = now
        ble.sendTrue()
    }

    private func minMaxDepth(_ map: CVPixelBuffer) -> (min: Float, max: Float)? {
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let stride = CVPixelBufferGetBytesPerRow(map)
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        var minV = Float.greatestFiniteMagnitude
        var maxV: Float = 0
        for y in Swift.stride(from: 0, to: height, by: 4) {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: Float.self)
            for x in Swift.stride(from: 0, to: width, by: 4) {
                let v = row[x]
                guard v.isFinite, v >= 0.15, v <= 2.0 else { continue }
                if v < minV { minV = v }
                if v > maxV { maxV = v }
            }
        }
        guard minV.isFinite, maxV > 0 else { return nil }
        return (minV, maxV)
    }
}

final class BLEClient: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789ABC0001")
    static let charUUID = CBUUID(string: "12345678-1234-5678-1234-56789ABC0002")

    @Published var isReadyToSend = false
    @Published var devices: [BLEDeviceItem] = []
    @Published var selectedID: UUID? = nil
    @Published var targetName: String = "localhost.localdomain"

    private var central: CBCentralManager!
    private var found: [UUID: CBPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?

    private let connectedQueryServices: [CBUUID] = [
        CBUUID(string: "12345678-1234-5678-1234-56789ABC0001"),
        CBUUID(string: "1800"),
        CBUUID(string: "1801"),
        CBUUID(string: "180A"),
        CBUUID(string: "180F")
    ]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func refresh() {
        guard central.state == .poweredOn else { return }
        devices.removeAll()
        found.removeAll()
        isReadyToSend = false
        characteristic = nil

        let connected = central.retrieveConnectedPeripherals(withServices: connectedQueryServices)
        for p in connected {
            addIfMatches(p, advertisedName: p.name)
        }

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func useSelected() {
        guard let selectedID, let target = found[selectedID] else { return }
        central.stopScan()
        peripheral = target
        target.delegate = self
        if target.state == .connected {
            target.discoverServices(nil)
        } else {
            central.connect(target)
        }
    }

    func sendTrue() {
        guard let peripheral, let characteristic else { return }
        let data = Data([1])
        let type: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: characteristic, type: type)
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func addIfMatches(_ peripheral: CBPeripheral, advertisedName: String?) {
        let name = (peripheral.name ?? advertisedName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let want = normalized(targetName)
        let n = normalized(name)
        guard n == want || n.contains(want) || want.contains(n) else { return }

        found[peripheral.identifier] = peripheral
        if devices.contains(where: { $0.id == peripheral.identifier }) { return }
        devices.append(BLEDeviceItem(id: peripheral.identifier, name: name))
        if selectedID == nil {
            selectedID = peripheral.identifier
        }
    }
}

extension BLEClient: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { refresh() }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        addIfMatches(peripheral, advertisedName: advertised)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isReadyToSend = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isReadyToSend = false
        characteristic = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        if let service = services.first(where: { $0.uuid == Self.serviceUUID }) {
            peripheral.discoverCharacteristics([Self.charUUID], for: service)
        } else {
            services.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let match = service.characteristics?.first(where: { $0.uuid == Self.charUUID }) {
            characteristic = match
            isReadyToSend = true
            return
        }
        if characteristic == nil,
           let writable = service.characteristics?.first(where: {
               $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
           }) {
            characteristic = writable
            isReadyToSend = true
        }
    }
}

final class DepthMetalRenderer: NSObject, MTKViewDelegate {
    private(set) var isReady = false
    private(set) var errorMessage = "Metal 초기화 중"
    var nearLimit: Float = 0.25
    var farLimit: Float = 0.80
    var opacity: Float = 0.85
    var rotation: Int32 = 0

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?
    private var depthTexture: MTLTexture?
    private let lock = NSLock()

    private let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;
    struct VOut { float4 position [[position]]; float2 uv; };
    struct Uniforms { float nearLimit; float farLimit; float opacity; int rotation; };
    vertex VOut vertex_main(uint vid [[vertex_id]]) {
        float2 positions[3] = { float2(-1.0,-1.0), float2(3.0,-1.0), float2(-1.0,3.0) };
        VOut out;
        out.position = float4(positions[vid], 0.0, 1.0);
        out.uv = positions[vid] * 0.5 + 0.5;
        out.uv.y = 1.0 - out.uv.y;
        return out;
    }
    float2 rotateUV(float2 uv, int rotation) {
        if (rotation == 1) return float2(uv.y, 1.0 - uv.x);
        if (rotation == 2) return float2(1.0 - uv.x, 1.0 - uv.y);
        if (rotation == 3) return float2(1.0 - uv.y, uv.x);
        return uv;
    }
    float3 depthColor(float t) {
        float3 c0 = float3(0.80, 0.00, 0.15);
        float3 c1 = float3(1.00, 0.40, 0.00);
        float3 c2 = float3(1.00, 0.92, 0.10);
        float3 c3 = float3(0.10, 0.80, 0.25);
        float3 c4 = float3(0.00, 0.65, 1.00);
        float3 c5 = float3(0.20, 0.05, 0.85);
        if (t < 0.2) return mix(c0, c1, t / 0.2);
        if (t < 0.4) return mix(c1, c2, (t - 0.2) / 0.2);
        if (t < 0.6) return mix(c2, c3, (t - 0.4) / 0.2);
        if (t < 0.8) return mix(c3, c4, (t - 0.6) / 0.2);
        return mix(c4, c5, (t - 0.8) / 0.2);
    }
    fragment float4 fragment_main(VOut in [[stage_in]],
                                 constant Uniforms &u [[buffer(0)]],
                                 texture2d<float> depthTex [[texture(0)]]) {
        constexpr sampler samp(address::clamp_to_edge, filter::nearest);
        float d = depthTex.sample(samp, rotateUV(in.uv, u.rotation)).r;
        if (!isfinite(d) || d < u.nearLimit || d > u.farLimit) return float4(0.0);
        float t = saturate((d - u.nearLimit) / max(u.farLimit - u.nearLimit, 0.001));
        return float4(depthColor(t), u.opacity);
    }
    """

    struct Uniforms {
        var nearLimit: Float
        var farLimit: Float
        var opacity: Float
        var rotation: Int32
    }

    override init() {
        super.init()
        guard let device = MTLCreateSystemDefaultDevice() else {
            errorMessage = "Metal 장치를 못 찾았습니다. 앱을 전체 실행하세요."
            return
        }
        guard let commandQueue = device.makeCommandQueue() else {
            errorMessage = "Metal queue 실패"
            return
        }
        var cache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) != kCVReturnSuccess {
            errorMessage = "Metal texture cache 실패"
            return
        }
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let vertex = library.makeFunction(name: "vertex_main"),
                  let fragment = library.makeFunction(name: "fragment_main") else {
                errorMessage = "셰이더 함수 없음"
                return
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertex
            desc.fragmentFunction = fragment
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipeline = try device.makeRenderPipelineState(descriptor: desc)
            self.device = device
            self.commandQueue = commandQueue
            self.textureCache = cache
            isReady = true
            errorMessage = "Metal 준비됨"
        } catch {
            errorMessage = "셰이더 실패: \(error.localizedDescription)"
        }
    }

    func updateDepth(_ pixelBuffer: CVPixelBuffer) {
        guard isReady, let cache = textureCache else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTex: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil, .r32Float, width, height, 0, &cvTex
        )
        if status == kCVReturnSuccess, let cvTex, let texture = CVMetalTextureGetTexture(cvTex) {
            lock.lock(); depthTexture = texture; lock.unlock()
            return
        }
        guard let device else { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float, width: width, height: height, mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        guard let tex = device.makeTexture(descriptor: desc) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            tex.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: base,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer)
            )
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        lock.lock(); depthTexture = tex; lock.unlock()
    }

    func draw(in view: MTKView) {
        guard isReady,
              let pipeline,
              let commandQueue,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        lock.lock()
        let texture = depthTexture
        lock.unlock()
        var uniforms = Uniforms(nearLimit: nearLimit, farLimit: farLimit, opacity: opacity, rotation: rotation)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        if let texture {
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

struct MetalDepthView: UIViewRepresentable {
    let renderer: DepthMetalRenderer
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.delegate = renderer
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isPaused = false
        view.preferredFramesPerSecond = 30
        return view
    }
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.previewLayer.connection?.videoOrientation = .landscapeRight
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
