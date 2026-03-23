//
//  ErroresVozATexto.swift
//  ControlXVoz
//
//  Created by ChumBucketComputer on 16/02/26.
//

import Foundation

/// Errores tipados para que el package NUNCA crashee.
/// En vez de fatalError / force unwrap, siempre devolvemos un error claro.
public enum ErrorVozATexto: Error, Sendable, Equatable, LocalizedError {

    /// Se usa cuando la app no habilitó el servicio (ej. no pidió permisos aún).
    case noConfigurado(String)

    /// La app o el sistema negó permisos (micrófono / speech).
    case permisosDenegados(String)

    /// El sistema no puede dar el servicio (ej. Speech no disponible).
    case noDisponible(String)

    /// Fallos de audio (engine, categoría, hardware, etc.)
    case falloAudio(String)

    /// Cancelación explícita (usuario o app).
    case cancelado

    /// Cualquier otro mensaje de error.
    case desconocido(String)

    /// Texto listo para mostrar al usuario.
    public var errorDescription: String? {
        switch self {
        case .noConfigurado(let m): return m
        case .permisosDenegados(let m): return m
        case .noDisponible(let m): return m
        case .falloAudio(let m): return m
        case .cancelado: return "Operación cancelada."
        case .desconocido(let m): return m
        }
    }
}
