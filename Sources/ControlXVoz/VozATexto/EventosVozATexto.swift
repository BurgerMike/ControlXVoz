//
//  CallBacksVozATexto.swift
//  ControlXVoz
//
//  Created by ChumBucketComputer on 16/02/26.
//
import Foundation

/// Todos los eventos que el package puede emitir.
/// En vez de 4 callbacks separados, un solo tipo
/// que agrupa todo — más limpio para AsyncStream.
public enum EventoVozATexto: Sendable {

    /// El servicio cambió de estado (inactivo, listo, escuchando...)
    /// La UI lo usa para mostrar animaciones o labels.
    case estado(EstadoVozATexto)

    /// Texto en vivo mientras hablas — llega muchas veces.
    /// Como subtítulos en tiempo real.
    case parcial(String)

    /// Texto completo y confirmado — llega UNA sola vez.
    /// ← Aquí M.O.E. despierta y decide qué hacer.
    case final(String)

    /// Algo salió mal — tipado para que la app sepa exactamente qué.
    case error(ErrorVozATexto)
}
