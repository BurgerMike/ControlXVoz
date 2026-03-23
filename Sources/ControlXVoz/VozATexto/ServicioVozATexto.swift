//
//  ServicioVozATexto.swift
//

import Foundation
import AVFoundation
import Speech

public actor VozATexto {

    // MARK: - Propiedades

    private let config: ConfigVozATexto
    private let continuacion: AsyncStream<EventoVozATexto>.Continuation
    public  let eventos: AsyncStream<EventoVozATexto>

    private var permisosListos = false
    private(set) var estado: EstadoVozATexto = .inactivo

    private let audioEngine = AVAudioEngine()
    private var tapInstalado = false

    private var tareaSpeech: SFSpeechRecognitionTask?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?

    private var ultimoTiempoConVoz: TimeInterval = 0
    private var tareaEndpointing: Task<Void, Never>?
    private var tareaTimeout: Task<Void, Never>?

    private var ultimoTexto = ""
    private var cierreIntencional = false

    // MARK: - Init

    public init(config: ConfigVozATexto = .init()) {
        self.config = config
        var cap: AsyncStream<EventoVozATexto>.Continuation!
        self.eventos = AsyncStream { cap = $0 }
        self.continuacion = cap
    }
}

// MARK: - Micrófono

extension VozATexto {

    func iniciarMicrofono() throws {
        let input = audioEngine.inputNode

        if tapInstalado {
            input.removeTap(onBus: 0)
            tapInstalado = false
        }

        audioEngine.stop()
        audioEngine.reset()

        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.speechRequest?.append(buffer)
            let rms = calcularRMS(buffer)
            Task { [weak self] in
                await self?.actualizarVAD(rms: rms)
            }
        }

        tapInstalado = true
        audioEngine.prepare()
        try audioEngine.start()
    }

    func detenerMicrofono() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalado {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalado = false
        }
    }

    func actualizarVAD(rms: Float) {
        if rms >= config.umbralRMSVAD {
            ultimoTiempoConVoz = CFAbsoluteTimeGetCurrent()
        }
    }
}

// MARK: - RMS

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

