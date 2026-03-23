//
//  ServicioVozATexto+Speech.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 23/03/26.
//

import Speech

extension VozATexto {

    func prepararSpeech() throws {
        let locale = Locale(identifier: config.localeIdentifier)

        guard let reconocedor = SFSpeechRecognizer(locale: locale),
              reconocedor.isAvailable else {
            throw emitirError(.noDisponible("Speech no disponible para \(config.localeIdentifier)."))
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = config.reportarParciales
        req.requiresOnDeviceRecognition = config.requiereOnDevice
        speechRequest = req

        tareaSpeech = reconocedor.recognitionTask(with: req) { [weak self] resultado, error in
            let texto = resultado?.bestTranscription.formattedString
            let esFinal = resultado?.isFinal ?? false
            let mensajeError = error?.localizedDescription

            Task { [weak self] in
                await self?.recibirResultadoSpeech(
                    texto: texto,
                    esFinal: esFinal,
                    error: mensajeError
                )
            }
        }
    }

    func recibirResultadoSpeech(texto: String?, esFinal: Bool, error: String?) {
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
