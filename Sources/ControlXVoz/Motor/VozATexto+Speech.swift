//
//  VozATexto+Speech.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Speech

extension VozATexto {
    func prepararSpeech() throws {
        guard let reconocedor = SFSpeechRecognizer(
            locale: Locale(identifier: config.idioma.rawValue)), reconocedor.isAvailable else {
            throw emitirError(.noDisponible (
                "Speech no disponible para \(config.idioma.rawValue)."
            ))
        }
        
        let solicitud = SFSpeechAudioBufferRecognitionRequest()
        solicitud.shouldReportPartialResults = config.reportarParciales
        solicitud.requiresOnDeviceRecognition = config.requiereOnDevice
        speechRequest = solicitud
        
        tareaSpeech = reconocedor.recognitionTask(with: solicitud) { [weak self] resultado, error in
            
            let texto = resultado?.bestTranscription.formattedString
            let esFinal = resultado?.isFinal ?? false
            let mensajeError = error?.localizedDescription
            
            Task { [weak self] in
                await self?.recibirResultado(
                    texto: texto,
                    esFinal: esFinal,
                    error: mensajeError
                )
            }
        }
    }
    
    func recibirResultado(texto: String?, esFinal: Bool, error: String?) {
        if let error {
            if !cierreIntencional {
                emitirError(.desconocido(error))
                detenerTodo()
            }
            return
        }
        
        guard let texto else { return }
        
        ultimoTexto = texto
        estado = .escuchando(textoParcial: texto)
        continuacion.yield(.parcial(texto))
        
        if esFinal {
            finalizarConTexto(texto)
        }
    }
    
    func finalizarConTexto(_ texto: String) {
        cierreIntencional = true
        detenerTodo()
        estado = .finalizado(texto: texto)
        continuacion.yield(.final(texto))
    }
    
    func limpiarSpeech() {
        tareaSpeech?.finish()
        tareaSpeech = nil
        speechRequest?.endAudio()
        speechRequest = nil 
    }
}
