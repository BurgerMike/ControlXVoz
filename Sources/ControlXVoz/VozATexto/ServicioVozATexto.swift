//
//  ServicioVozATexto.swift
//  ControlXVoz
//
//  VozATexto (mecanismo) — multiplataforma
//
import Foundation
import AVFoundation
import Speech


// Tap (hilo de audio) -> actor: necesitamos “cajas” thread-safe
private final class CajaSpeechRequest: @unchecked Sendable {
    var valor: SFSpeechAudioBufferRecognitionRequest?
}

private final class CajaVAD: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var ultimoTiempoConVoz: TimeInterval = 0

    func marcarVoz(_ ahora: TimeInterval) {
        os_unfair_lock_lock(&lock)
        ultimoTiempoConVoz = ahora
        os_unfair_lock_unlock(&lock)
    }

    func leerUltimoTiempoConVoz() -> TimeInterval {
        os_unfair_lock_lock(&lock)
        let v = ultimoTiempoConVoz
        os_unfair_lock_unlock(&lock)
        return v
    }
}

public actor VozATexto {

    private let config: ConfigVozATexto
    private var permisosListos = false
    private var callbacks = CallbacksVozATexto()

    private let audioEngine = AVAudioEngine()
    private var tapInstalado = false

    private var tareaSpeech: SFSpeechRecognitionTask?
    private let cajaRequest = CajaSpeechRequest()

    private let cajaVAD = CajaVAD()
    private var tareaEndpointing: Task<Void, Never>?
    private var tareaTimeout: Task<Void, Never>?

    private var ultimoTexto = ""
    private var cierreIntencional = false

    private(set) var estado: EstadoVozATexto = .inactivo {
        didSet { emitirEstado(estado) }
    }

    public init(config: ConfigVozATexto = .init()) {
        self.config = config
    }

    public func establecerCallbacks(_ callbacks: CallbacksVozATexto) {
        self.callbacks = callbacks
    }

    public func habilitar() {
        permisosListos = true
        if case .inactivo = estado { estado = .listo }
    }

    public func deshabilitar() {
        permisosListos = false
        cierreIntencional = true
        detenerTodo()
        estado = .inactivo
    }

    public var estaHabilitado: Bool { permisosListos }

    public func iniciar() async throws {
        guard permisosListos else {
            throw emitirError(.noConfigurado("Primero pide permisos en la app y luego llama habilitar()."))
        }
        if case .escuchando = estado { return }

        cierreIntencional = false
        detenerTodo()

        ultimoTexto = ""
        cajaVAD.marcarVoz(CFAbsoluteTimeGetCurrent())

        try prepararSpeech()
        try iniciarMicrofono()

        estado = .escuchando(textoParcial: "")
        iniciarEndpointingVAD()
        iniciarTimeoutMaximo()
    }

    public func cancelar() async {
        cierreIntencional = true
        detenerTodo()
        ultimoTexto = ""
        estado = .inactivo
    }
}

// MARK: - Speech

private extension VozATexto {

    func prepararSpeech() throws {
        let locale = Locale(identifier: config.localeIdentifier)
        guard let rec = SFSpeechRecognizer(locale: locale), rec.isAvailable else {
            throw emitirError(.noDisponible("Speech no disponible para \(config.localeIdentifier)."))
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = config.reportarParciales
        req.requiresOnDeviceRecognition = config.requiereOnDevice
        cajaRequest.valor = req

        tareaSpeech = rec.recognitionTask(with: req) { [weak self] result, err in
            guard let self else { return }

            if let err {
                Task { await self.manejarErrorSpeech(err.localizedDescription) }
                return
            }
            guard let result else { return }

            let texto = result.bestTranscription.formattedString
            let esFinal = result.isFinal

            Task { [texto, esFinal] in
                await self.recibioTexto(texto, isFinal: esFinal)
            }
        }
    }

    func manejarErrorSpeech(_ mensaje: String) {
        if cierreIntencional { return }
        _ = emitirError(.desconocido("Speech error: \(mensaje)"))
        cierreIntencional = true
        detenerTodo()
    }

    func recibioTexto(_ texto: String, isFinal: Bool) {
        ultimoTexto = texto
        estado = .escuchando(textoParcial: texto)
        emitirParcial(texto)

        if isFinal {
            Task { await finalizar(texto) }
        }
    }

    func finalizar(_ texto: String) async {
        cierreIntencional = true
        detenerTodo()
        estado = .finalizado(texto: texto)
        emitirFinal(texto)
    }

    func cerrarAudioSpeech() {
        cajaRequest.valor?.endAudio()
    }

    func limpiarSpeech() {
        tareaSpeech?.finish()
        tareaSpeech = nil
        cajaRequest.valor = nil
    }
}

// MARK: - VAD (silencio real)

private extension VozATexto {

    var umbralRMS: Float { config.umbralRMSVAD }

    var segundosSilencio: TimeInterval {
        max(config.tiempoSilencioParaAutoDetener, 1.8) // mínimo “pausas humanas”
    }

    func iniciarEndpointingVAD() {
        tareaEndpointing?.cancel()
        let silencio = segundosSilencio
        let caja = cajaVAD

        tareaEndpointing = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 150_000_000)

                guard case .escuchando = await self.estado else { continue }

                let ahora = CFAbsoluteTimeGetCurrent()
                let ultimo = caja.leerUltimoTiempoConVoz()

                if (ahora - ultimo) >= silencio {
                    await self.finalizarPorSilencio()
                    return
                }
            }
        }
    }

    func iniciarTimeoutMaximo() {
        tareaTimeout?.cancel()
        let maximo: TimeInterval = 45

        tareaTimeout = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(maximo * 1_000_000_000))
            await self.finalizarPorSilencio()
        }
    }

    func finalizarPorSilencio() async {
        cierreIntencional = true
        detenerTodo()
        estado = .finalizado(texto: ultimoTexto)
        emitirFinal(ultimoTexto)
    }

    func detenerTareas() {
        tareaEndpointing?.cancel()
        tareaEndpointing = nil
        tareaTimeout?.cancel()
        tareaTimeout = nil
    }
}

// MARK: - Micrófono

private extension VozATexto {

    func iniciarMicrofono() throws {

        #if os(iOS) || os(tvOS) || os(watchOS)
        let sesion = AVAudioSession.sharedInstance()
        try sesion.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try sesion.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = audioEngine.inputNode

        if tapInstalado {
            input.removeTap(onBus: 0)
            tapInstalado = false
        }

        audioEngine.stop()
        audioEngine.reset()

        let cajaReq = cajaRequest
        let caja = cajaVAD
        let umbral = umbralRMS

        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            cajaReq.valor?.append(buffer)

            if calcularRMS(buffer) >= umbral {
                caja.marcarVoz(CFAbsoluteTimeGetCurrent())
            }
        }

        tapInstalado = true
        audioEngine.prepare()
        try audioEngine.start()
    }

    func detenerMicrofono() {
        if audioEngine.isRunning { audioEngine.stop() }

        let input = audioEngine.inputNode
        if tapInstalado {
            input.removeTap(onBus: 0)
            tapInstalado = false
        }

        #if os(iOS) || os(tvOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func detenerTodo() {
        detenerTareas()
        detenerMicrofono()
        cerrarAudioSpeech()
        limpiarSpeech()
    }
}

// MARK: - Callbacks

private extension VozATexto {

    func emitirEstado(_ e: EstadoVozATexto) {
        guard let cb = callbacks.alEstado else { return }
        Task { @MainActor in cb(e) }
    }

    func emitirParcial(_ t: String) {
        guard let cb = callbacks.alParcial else { return }
        Task { @MainActor in cb(t) }
    }

    func emitirFinal(_ t: String) {
        guard let cb = callbacks.alFinal else { return }
        Task { @MainActor in cb(t) }
    }

    @discardableResult
    func emitirError(_ e: ErrorVozATexto) -> ErrorVozATexto {
        estado = .error(e.localizedDescription)
        if let cb = callbacks.alError {
            Task { @MainActor in cb(e) }
        }
        return e
    }
}

// MARK: - RMS helper

private func calcularRMS(_ buffer: AVAudioPCMBuffer) -> Float {
    let n = Int(buffer.frameLength)
    guard n > 0 else { return 0 }

    if let ch = buffer.floatChannelData?[0] {
        var s: Float = 0
        for i in 0..<n { let x = ch[i]; s += x * x }
        return sqrt(s / Float(n))
    }

    if let ch16 = buffer.int16ChannelData?[0] {
        var s: Float = 0
        let denom = Float(Int16.max)
        for i in 0..<n { let x = Float(ch16[i]) / denom; s += x * x }
        return sqrt(s / Float(n))
    }

    return 0
}
