//
//  ServicioVosATexto+Microfono.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 23/03/26.
//

import AVFoundation

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

    func iniciarVAD() {
        tareaEndpointing?.cancel()
        tareaTimeout?.cancel()

        let silencio = max(config.tiempoSilencioParaAutoDetener, 1.8)

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
