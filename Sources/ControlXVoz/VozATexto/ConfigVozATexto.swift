//
//  ConfigVozATexto.swift
//  ControlXVoz
//
//  Created by ChumBucketComputer on 16/02/26.
//

import Foundation

/// Configuración del mecanismo Voz → Texto (Speech-to-Text).
/// OJO: “voz, velocidad, pitch” es Text-to-Speech (otra cosa).
public struct ConfigVozATexto: Sendable, Equatable {

    /// Idioma/region para el reconocimiento, ej: "es-MX", "en-US".
    public var localeIdentifier: String

    /// Si quieres recibir parciales mientras hablas (tipo Siri).
    public var reportarParciales: Bool

    /// Tiempo (segundos) para auto-detener por silencio (fase futura).
    public var tiempoSilencioParaAutoDetener: TimeInterval

    /// Pedir reconocimiento en dispositivo si es posible (puede fallar si no está disponible).
    public var requiereOnDevice: Bool
    
    public var umbralRMSVAD: Float

    public init(
        localeIdentifier: String = "es-MX",
        reportarParciales: Bool = true,
        tiempoSilencioParaAutoDetener: TimeInterval = 1.2,
        requiereOnDevice: Bool = false,
        umbralRMSVAD: Float = 0.06
    ) {
        self.localeIdentifier = localeIdentifier
        self.reportarParciales = reportarParciales
        self.tiempoSilencioParaAutoDetener = tiempoSilencioParaAutoDetener
        self.requiereOnDevice = requiereOnDevice
        self.umbralRMSVAD = umbralRMSVAD
    }
}
