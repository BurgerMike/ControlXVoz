//
//  VozATexto+API.swift
//  ControlXVoz
//
//  Created by Miguel Carlos Elizondo Martinez on 26/04/26.
//

import Foundation

extension VozATexto {
    public func habilitar() {
        permisosListos = true
        if case .inactivo = estado {
            estado = .listo
            continuacion.yield(.estado(.listo))
        }
    }
    
    public func deshabilitar() {
        permisosListos = false
        cierreIntencional = true
        detenerTodo()
        estado = .inactivo
        continuacion.yield(.estado(.inactivo))
    }
    
    public var estaHabilitado: Bool {
        permisosListos
    }
    
    public func iniciar() async throws {
        guard permisosListos else {
            throw emitirError(.noConfigurado("Llama habilitar() antes de iniciar."))
        }
        
        if case .escuchando = estado { return }
        
        cierreIntencional = false
        detenerTodo()
        ultimoTexto = ""
        ultimoTiempoConVoz = CFAbsoluteTimeGetCurrent()
        
        try prepararSpeech()
        try iniciarMicrofono()
        
        estado = .escuchando(textoParcial: "")
        continuacion.yield(.estado(.escuchando(textoParcial: "")))
        
        iniciarVAD()
    }
    
    public func cancelar() async {
        cierreIntencional = true
        detenerTodo()
        ultimoTexto = ""
        estado = .inactivo
        continuacion.yield(.estado(.inactivo))
    }
}
    
    extension VozATexto {
        func detenerTodo() {
            detenerVAD()
            detenerMicrofono()
            limpiarSpeech()
        }
        
        @discardableResult
         func emitirError(_ error: ErrorVozATexto) -> ErrorVozATexto {
             estado = .error(error.localizedDescription)
             continuacion.yield(.error(error))
             return error
         }
    }

    
