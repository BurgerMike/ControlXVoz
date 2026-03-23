//
//  Untitled.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 23/03/26.
//

//
//  ServicioVozATexto.swift
//

import Foundation
import AVFoundation
import Speech

public actor VozATexto {

    // MARK: - Propiedades

    internal let config: ConfigVozATexto
    internal let continuacion: AsyncStream<EventoVozATexto>.Continuation
    public  let eventos: AsyncStream<EventoVozATexto>

    internal var permisosListos = false
    internal(set) var estado: EstadoVozATexto = .inactivo

    internal let audioEngine = AVAudioEngine()
    internal var tapInstalado = false

    internal var tareaSpeech: SFSpeechRecognitionTask?
    internal var speechRequest: SFSpeechAudioBufferRecognitionRequest?

    internal var ultimoTiempoConVoz: TimeInterval = 0
    internal var tareaEndpointing: Task<Void, Never>?
    internal var tareaTimeout: Task<Void, Never>?

    internal var ultimoTexto = ""
    internal var cierreIntencional = false

    // MARK: - Init

    public init(config: ConfigVozATexto = .init()) {
        self.config = config
        var cap: AsyncStream<EventoVozATexto>.Continuation!
        self.eventos = AsyncStream { cap = $0 }
        self.continuacion = cap
    }
}
