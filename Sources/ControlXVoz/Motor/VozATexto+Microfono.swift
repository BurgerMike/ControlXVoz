//
//  VozATexto+Microfono.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation
import AVFAudio

extension VozATexto {
    func iniciarMicrofono() throws {
        let input = audioEngine.inputNode
        
        if tapInstalado {
            input.removeTap(onBus: 0)
            tapInstalado = false
        }
        
        audioEngine.stop()
        audioEngine.reset()
        
        let solicitud = speechRequest
        
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            solicitud?.append(buffer)
            
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
}

extension VozATexto {

    func actualizarVAD(rms: Float) {
        // Si el volumen supera el umbral configurado,
        // actualizamos el timestamp de "última vez que hubo voz".
        if rms >= config.umbralRMSVAD {
            ultimoTiempoConVoz = CFAbsoluteTimeGetCurrent()
        }
    }

    func iniciarVAD() {
        // Cancelamos cualquier tarea anterior antes de crear nuevas.
        tareaEndpointing?.cancel()
        tareaTimeout?.cancel()

        let silencio = max(config.tiempoSilencioParaAutoDetener, 1.8)

        // Loop que revisa cada 150ms si pasó suficiente silencio.
        // Cuando lo detecta, cierra el reconocimiento automáticamente.
        tareaEndpointing = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                guard case .escuchando = await self.estado else { continue }

                let ahora = CFAbsoluteTimeGetCurrent()
                let ultimo = await self.ultimoTiempoConVoz

                if (ahora - ultimo) >= silencio {
                    await self.finalizarConTexto(await self.ultimoTexto)
                    return
                }
            }
        }

        // Seguro de emergencia: si nadie dejó de hablar en 45s,
        // cierra de todas formas. SFSpeechRecognizer tiene límite
        // de ~1 minuto — esto evita que se corte sin avisar.
        tareaTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard let self else { return }
            await self.finalizarConTexto(await self.ultimoTexto)
        }
    }

    func detenerVAD() {
        tareaEndpointing?.cancel()
        tareaEndpointing = nil
        tareaTimeout?.cancel()
        tareaTimeout = nil
    }
}

// Fuera del actor — función pura sin estado, no necesita aislamiento.
// RMS (Root Mean Square) = el volumen promedio real del buffer de audio.
// Más alto = más fuerte el sonido = más probable que sea voz.
private func calcularRMS(_ buffer: AVAudioPCMBuffer) -> Float {
    let n = Int(buffer.frameLength)
    guard n > 0 else { return 0 }

    if let canal = buffer.floatChannelData?[0] {
        var suma: Float = 0
        for i in 0..<n {
            let muestra = canal[i]
            suma += muestra * muestra
        }
        return sqrt(suma / Float(n))
    }
    return 0
}
