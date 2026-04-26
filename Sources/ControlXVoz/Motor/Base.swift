//
//  Base.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation
import AVFoundation
import Speech

public actor VozATexto {
    internal let config: ConfigVozATexto
    
    public let eventos: AsyncStream<EventoVozATexto>
    
    internal let continuacion: AsyncStream<EventoVozATexto>.Continuation
    
    internal(set) public var estado: EstadoVozATexto = .inactivo
    
    internal var permisosListos = false
    
    internal var cierreIntencional = false
    
    internal let audioEngine = AVAudioEngine()
    
    internal var tapInstalado = false
    
    internal var tareaSpeech: SFSpeechRecognitionTask?
    
    internal var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    
    internal var ultimoTiempoConVoz: TimeInterval = 0
    
    internal var tareaEndpointing: Task<Void, Never>?
    
    internal var tareaTimeout: Task<Void, Never>?
    
    internal var ultimoTexto = ""
    
    public init(config: ConfigVozATexto = .init()) {
        self.config = config
        
        var capturada: AsyncStream<EventoVozATexto>.Continuation!
        self.eventos = AsyncStream { capturada = $0 }
        self.continuacion = capturada
    }
    
    
}
