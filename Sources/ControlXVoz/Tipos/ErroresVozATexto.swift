//
//  ErroresVozATexto.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation

public enum ErrorVozATexto: Error, Sendable, Equatable, LocalizedError {
    
    case noConfigurado(String)
    
    case permisosDenegados(String)
    
    case noDisponible(String)
    
    case falloAudio(String)
    
    case cancelado
    
    case desconocido(String)
    
    public var errorDescription: String? {
        switch self {
        case .noConfigurado(let m): return m
        case .permisosDenegados(let m): return m
        case .noDisponible(let m): return m
        case .falloAudio(let m): return m
        case .cancelado: return "Operación cancelada"
        case .desconocido(let m): return m
        }
    }
}
