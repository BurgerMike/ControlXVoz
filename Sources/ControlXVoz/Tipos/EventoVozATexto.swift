//
//  EventosVozATexto.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation

public enum EventoVozATexto: Sendable {
    
    case estado(EstadoVozATexto)
    
    case parcial(String)
    
    case final(String)
    
    case error(ErrorVozATexto)
}
