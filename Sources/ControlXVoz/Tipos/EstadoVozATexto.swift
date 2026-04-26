//
//  Estado.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation

public enum EstadoVozATexto: Sendable, Equatable {
    case inactivo
    
    case listo
    
    case escuchando(textoParcial: String)
    
    case finalizado(texto: String)
    
    case error(String)
}

