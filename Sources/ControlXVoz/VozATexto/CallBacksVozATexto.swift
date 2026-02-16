//
//  CallBacksVozATexto.swift
//  ControlXVoz
//
//  Created by ChumBucketComputer on 16/02/26.
//

import Foundation

/// Callbacks hacia la app.
///
/// ¿Por qué @MainActor aquí?
/// - Porque la app seguramente va a actualizar UI (SwiftUI/UIKit),
///   y la UI debe actualizarse en el hilo principal.
/// - El package NO “mueve UI”, solo “notifica”; pero garantizamos
///   que la notificación llega en MainActor.
///
/// ¿Por qué @Sendable?
/// - Indica que la closure es segura para usarse en concurrencia.
/// - Swift la usa para analizar riesgos de data races.
public struct CallbacksVozATexto: Sendable {

    /// Cambios de estado del mecanismo.
    public var alEstado: (@MainActor @Sendable (EstadoVozATexto) -> Void)?

    /// Texto parcial mientras hablas (cuando conectemos Speech).
    public var alParcial: (@MainActor @Sendable (String) -> Void)?

    /// Texto final al detener.
    public var alFinal: (@MainActor @Sendable (String) -> Void)?

    /// Error tipado (para mostrar en UI o logs).
    public var alError: (@MainActor @Sendable (ErrorVozATexto) -> Void)?

    public init(
        alEstado: (@MainActor @Sendable (EstadoVozATexto) -> Void)? = nil,
        alParcial: (@MainActor @Sendable (String) -> Void)? = nil,
        alFinal: (@MainActor @Sendable (String) -> Void)? = nil,
        alError: (@MainActor @Sendable (ErrorVozATexto) -> Void)? = nil
    ) {
        self.alEstado = alEstado
        self.alParcial = alParcial
        self.alFinal = alFinal
        self.alError = alError
    }
}
