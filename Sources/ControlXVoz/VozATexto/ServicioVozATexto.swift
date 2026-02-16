//
//  ServicioVozATexto.swift
//  ControlXVoz
//
//  VozATexto (mecanismo) — multiplataforma
//

import Foundation
import AVFoundation
import Speech

// MARK: - Cajas seguras para cruzar el tap (hilo de audio) con el actor

/// Caja para el request de Speech (se usa dentro del tap).
private final class CajaSpeechRequest: @unchecked Sendable {
    var valor: SFSpeechAudioBufferRecognitionRequest?
}

/// Caja para VAD (último instante donde se detectó voz).
private final class CajaVAD: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var _ultimoTiempoConVoz: TimeInterval = 0

    func marcarVoz(ahora: TimeInterval) {
        os_unfair_lock_lock(&lock)
        _ultimoTiempoConVoz = ahora
        os_unfair_lock_unlock(&lock)
    }

    func ultimoTiempoConVoz() -> TimeInterval {
        os_unfair_lock_lock(&lock)
        let v = _ultimoTiempoConVoz
        os_unfair_lock_unlock(&lock)
        return v
    }
}

// MARK: - Servicio

public actor VozATexto {

    // MARK: Config / Estado

    private let config: ConfigVozATexto
    private var permisosListos = false
    private var callbacks = CallbacksVozATexto()

    private(set) var estado: EstadoVozATexto = .inactivo {
        didSet { emitirEstado(estado) }
    }

    // MARK: Audio

    private let audioEngine = AVAudioEngine()
    private var tapInstalado = false

    // MARK: Speech

    private var recognizer: SFSpeechRecognizer?
    private var tareaSpeech: SFSpeechRecognitionTask?
    private let cajaRequest = CajaSpeechRequest()

    // MARK: VAD (silencio real)

    private let cajaVAD = CajaVAD()
    private var tareaEndpointing: Task<Void, Never>?
    private var tareaTimeoutMaximo: Task<Void, Never>?

    // Ajustes VAD (prácticos)
    private var umbralRMS: Float { config.umbralRMSVAD }   // sensibilidad (0.015–0.03 típico)
    private let maximoSegundos: TimeInterval = 45.0  // seguridad para no quedar colgado

    // Resultados
    private var ultimoTexto: String = ""
    private var cierreIntencional = false

    // MARK: Init

    public init(config: ConfigVozATexto = .init()) {
        self.config = config
    }

    // MARK: Callbacks

    public func establecerCallbacks(_ callbacks: CallbacksVozATexto) {
        self.callbacks = callbacks
    }

    // MARK: Habilitación

    /// La app externa pide permisos y luego llama esto.
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

    // MARK: Control principal

    /// Tap para empezar: escucha y transcribe. Se auto-detiene por silencio real (VAD).
    public func iniciar() async throws {
        guard permisosListos else {
            throw emitirError(.noConfigurado("Servicio no habilitado. La app debe pedir permisos y luego llamar habilitar()."))
        }
        if case .escuchando = estado { return }

        cierreIntencional = false
        detenerTodo()

        ultimoTexto = ""

        // Inicializa “último sonido” a ahora para no cortar instantáneo
        let ahora = CFAbsoluteTimeGetCurrent()
        cajaVAD.marcarVoz(ahora: ahora)

        try prepararSpeech()
        do {
            try iniciarMicrofono()
        } catch {
            cierreIntencional = true
            detenerTodo()
            throw emitirError(.falloAudio("No se pudo iniciar micrófono: \(error.localizedDescription)"))
        }

        estado = .escuchando(textoParcial: "")
        iniciarEndpointingPorSilencioReal()
        iniciarTimeoutMaximo()
    }

    /// Cancelar manual: corta sin resultado.
    public func cancelar() async {
        cierreIntencional = true
        detenerTodo()
        ultimoTexto = ""
        estado = .inactivo
    }

    // MARK: - Speech

    private func prepararSpeech() throws {
        let locale = Locale(identifier: config.localeIdentifier)

        guard let rec = SFSpeechRecognizer(locale: locale) else {
            throw emitirError(.noDisponible("No se pudo crear SFSpeechRecognizer para \(config.localeIdentifier)."))
        }
        guard rec.isAvailable else {
            throw emitirError(.noDisponible("Speech no disponible en este momento para \(config.localeIdentifier)."))
        }
        recognizer = rec

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = config.reportarParciales
        req.requiresOnDeviceRecognition = config.requiereOnDevice
        cajaRequest.valor = req

        tareaSpeech = rec.recognitionTask(with: req) { [weak self] resultado, error in
            guard let self else { return }

            if let error {
                let msg = "Speech error: \(error.localizedDescription)"
                Task { await self.manejarErrorSpeech(msg) }
                return
            }

            guard let resultado else { return }

            // No capturar `resultado` dentro del Task.
            let texto = resultado.bestTranscription.formattedString
            let esFinal = resultado.isFinal

            Task { [texto, esFinal] in
                await self.recibioTexto(texto, isFinal: esFinal)
            }
        }
    }

    private func manejarErrorSpeech(_ mensaje: String) {
        // Si cerramos por silencio/cancelación, no lo tratamos como error visible.
        if cierreIntencional { return }
        _ = emitirError(.desconocido(mensaje))
        cierreIntencional = true
        detenerTodo()
    }

    private func recibioTexto(_ texto: String, isFinal: Bool) {
        ultimoTexto = texto
        estado = .escuchando(textoParcial: texto)
        emitirParcial(texto)

        if isFinal {
            // Si Speech decide finalizar solo, tratamos como final normal.
            Task { await self.finalizarComoExito() }
        }
    }

    private func finalizarComoExito() async {
        cierreIntencional = true
        detenerMicrofono()
        finalizarAudioParaSpeech()
        detenerTareas()

        let texto = ultimoTexto
        estado = .finalizado(texto: texto)
        emitirFinal(texto)

        limpiarSpeech()
    }

    private func finalizarPorSilencio() async {
        // Cierre intencional: no mostrar error.
        cierreIntencional = true

        detenerMicrofono()
        finalizarAudioParaSpeech()
        detenerTareas()

        let texto = ultimoTexto
        estado = .finalizado(texto: texto)
        emitirFinal(texto)

        limpiarSpeech()
    }

    private func finalizarAudioParaSpeech() {
        cajaRequest.valor?.endAudio()
    }

    private func limpiarSpeech() {
        tareaSpeech?.finish()
        tareaSpeech = nil
        recognizer = nil
        cajaRequest.valor = nil
    }

    // MARK: - Endpointing por silencio real (VAD)

    /// El silencio real que usaremos para finalizar.
    /// Regla: mínimo 1.8s para tolerar pausas humanas.
    private func umbralSilencioReal() -> TimeInterval {
        max(config.tiempoSilencioParaAutoDetener, 1.8)
    }

    private func iniciarEndpointingPorSilencioReal() {
        tareaEndpointing?.cancel()

        let silencio = umbralSilencioReal()
        let caja = cajaVAD

        tareaEndpointing = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s

                guard case .escuchando = await self.estado else { continue }

                let ahora = CFAbsoluteTimeGetCurrent()
                let ultimo = caja.ultimoTiempoConVoz()

                if (ahora - ultimo) >= silencio {
                    await self.finalizarPorSilencio()
                    return
                }
            }
        }
    }

    private func iniciarTimeoutMaximo() {
        tareaTimeoutMaximo?.cancel()
        let maximo = maximoSegundos

        tareaTimeoutMaximo = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(maximo * 1_000_000_000))
            await self.finalizarPorSilencio()
        }
    }

    private func detenerTareas() {
        tareaEndpointing?.cancel()
        tareaEndpointing = nil
        tareaTimeoutMaximo?.cancel()
        tareaTimeoutMaximo = nil
    }

    // MARK: - Micro (multiplataforma)

    private func iniciarMicrofono() throws {

        #if os(iOS) || os(tvOS) || os(watchOS)
        let sesion = AVAudioSession.sharedInstance()
        try sesion.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try sesion.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let nodoEntrada = audioEngine.inputNode

        if tapInstalado {
            nodoEntrada.removeTap(onBus: 0)
            tapInstalado = false
        }

        // Reset defensivo (ayuda cuando cambia el input device / AirPods)
        audioEngine.stop()
        audioEngine.reset()

        let cajaReq = cajaRequest
        let cajaVAD = self.cajaVAD
        let umbral = self.umbralRMS

        nodoEntrada.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            // 1) Alimentar Speech
            cajaReq.valor?.append(buffer)

            // 2) VAD (RMS) — si hay voz real, marcamos actividad
            let rms = calcularRMS(buffer)
            if rms >= umbral {
                cajaVAD.marcarVoz(ahora: CFAbsoluteTimeGetCurrent())
            }
        }

        tapInstalado = true

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func detenerMicrofono() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        let nodoEntrada = audioEngine.inputNode
        if tapInstalado {
            nodoEntrada.removeTap(onBus: 0)
            tapInstalado = false
        }

        #if os(iOS) || os(tvOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func detenerTodo() {
        detenerTareas()
        detenerMicrofono()
        limpiarSpeech()
    }

    // MARK: - Emisión segura hacia UI (MainActor)

    private func emitirEstado(_ estado: EstadoVozATexto) {
        guard let cb = callbacks.alEstado else { return }
        Task { @MainActor in cb(estado) }
    }

    private func emitirParcial(_ texto: String) {
        guard let cb = callbacks.alParcial else { return }
        Task { @MainActor in cb(texto) }
    }

    private func emitirFinal(_ texto: String) {
        guard let cb = callbacks.alFinal else { return }
        Task { @MainActor in cb(texto) }
    }

    @discardableResult
    private func emitirError(_ error: ErrorVozATexto) -> ErrorVozATexto {
        estado = .error(error.localizedDescription)
        if let cb = callbacks.alError {
            Task { @MainActor in cb(error) }
        }
        return error
    }
}

// MARK: - RMS helpers (fuera del actor)

private func calcularRMS(_ buffer: AVAudioPCMBuffer) -> Float {
    let n = Int(buffer.frameLength)
    guard n > 0 else { return 0 }

    // Float32 path
    if let ch = buffer.floatChannelData?[0] {
        var suma: Float = 0
        for i in 0..<n {
            let x = ch[i]
            suma += x * x
        }
        return sqrt(suma / Float(n))
    }

    // Int16 path
    if let ch16 = buffer.int16ChannelData?[0] {
        var suma: Float = 0
        let denom = Float(Int16.max)
        for i in 0..<n {
            let x = Float(ch16[i]) / denom
            suma += x * x
        }
        return sqrt(suma / Float(n))
    }

    // Desconocido
    return 0
}
