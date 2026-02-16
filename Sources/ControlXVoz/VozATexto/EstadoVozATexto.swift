//
//  EstadoVozATexto.swift
//  ControlXVoz
//
//  Created by ChumBucketComputer on 16/02/26.
//

import Foundation

/// Estados del “mecanismo” (NO UI).
/// La app (vista) lee este estado y decide qué animación/label mostrar.
public enum EstadoVozATexto: Sendable, Equatable {

    /// Aún no está listo o está apagado.
    case inactivo

    /// Listo para iniciar (ya habilitado).
    case listo

    /// Está escuchando. Puede traer texto parcial (cuando conectemos Speech).
    case escuchando(textoParcial: String)

    /// Terminó y entrega texto final.
    case finalizado(texto: String)

    /// Estado de error para UI/logs (sin crashear).
    case error(String)
}
