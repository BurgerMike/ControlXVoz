//
//  ConfigVozATexto.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation

public struct ConfigVozATexto: Sendable, Equatable {
    
    public var idioma: IdiomaVoz
    
    public var reportarParciales: Bool
    
    public var tiempoSilencioParaAutoDetener: TimeInterval
    
    public var requiereOnDevice: Bool
    
    public var umbralRMSVAD: Float
    
    public init(
        idioma: IdiomaVoz = .espanolMexico,
    reportarParciales: Bool = true,
    tiempoSilencioParaAutoDetener: TimeInterval = 1.2,
    requiereOnDevice: Bool = true,
    umbralRMSVAD: Float = 0.06
    ) {
        self.idioma = idioma
        self.reportarParciales = reportarParciales
        self.tiempoSilencioParaAutoDetener = tiempoSilencioParaAutoDetener
        self.requiereOnDevice = requiereOnDevice
        self.umbralRMSVAD = umbralRMSVAD
    }
    
    
}

public enum IdiomaVoz: String, Sendable, Equatable, CaseIterable {
    case espanolMexico      = "es-MX"
    case espanolEspana      = "es-ES"
    case inglesUSA          = "en-US"
    case inglesReinoUnido   = "en-GB"
    case frances            = "fr-FR"
    case aleman             = "de-DE"
    case portuguesBrasil    = "pt-BR"
    case japonés            = "ja-JP"
    case chino              = "zh-CN"

    // Nombre legible para mostrar en UI —
    // el HUD o Settings de MOEAI lo usa directamente.
    public var nombre: String {
        switch self {
        case .espanolMexico:    return "Español (México)"
        case .espanolEspana:    return "Español (España)"
        case .inglesUSA:        return "English (US)"
        case .inglesReinoUnido: return "English (UK)"
        case .frances:          return "Français"
        case .aleman:           return "Deutsch"
        case .portuguesBrasil:  return "Português (Brasil)"
        case .japonés:          return "日本語"
        case .chino:            return "中文"
        }
    }
}
