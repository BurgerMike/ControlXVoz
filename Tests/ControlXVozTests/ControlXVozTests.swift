import Testing
@testable import ControlXVoz

@Test
func iniciarSinPermisosLanzaErrorControlado() async {
    let servicio = VozATexto()

    do {
        try await servicio.iniciar()
        #expect(Bool(false), "Debió lanzar error")
    } catch let e as ErrorVozATexto {
        #expect(e == .noConfigurado("Debes solicitar permisos (Paso 3). Por ahora usa marcarPermisosComoListosParaPruebas() para tests."))
    } catch {
        #expect(Bool(false), "Error inesperado: \(error)")
    }
}

@Test
func flujoBasicoNoCrashea() async throws {
    let servicio = VozATexto()
    await servicio.marcarPermisosComoListosParaPruebas()
    try await servicio.iniciar()
    await servicio.detener()
}
