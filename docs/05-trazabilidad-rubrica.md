# Trazabilidad de la rúbrica

## 1. Objetivo

Este documento relaciona cada criterio de la rúbrica con evidencias verificables del proyecto: documentación, código fuente, reglas de seguridad, pruebas automatizadas, capturas y evolución registrada en Git.

La auditoría inicial otorgó 12.5 de 20 puntos. La imagen original se conserva en [`evidencias/00-rubrica-inicial.png`](evidencias/00-rubrica-inicial.png).

La siguiente matriz muestra cómo se atendieron las observaciones detectadas. El puntaje indicado es el máximo objetivo y su asignación final corresponde al docente.

## 2. Matriz de trazabilidad

| N.° | Criterio | Mejora implementada | Evidencia verificable | Puntaje objetivo |
|---:|---|---|---|---:|
| 1 | Uso de insumos y contextualización | Se documentaron problema, usuarios, alcance, MVP, módulos, arquitectura, tecnologías, repositorio y evolución real | [`README.md`](../README.md), [`01-contexto-y-diagnostico.md`](01-contexto-y-diagnostico.md), [`09-historial-git.txt`](evidencias/09-historial-git.txt) y capturas | 2.0 |
| 2 | Diagnóstico de datos del MVP | Se clasificaron datos principales, sensibles, derivados, geográficos, de configuración, auditoría y evidencia; también se definieron integridad, nulabilidad y responsables | [`01-contexto-y-diagnostico.md`](01-contexto-y-diagnostico.md) y [`02-modelo-y-diccionario.md`](02-modelo-y-diccionario.md) | 3.0 |
| 3 | Selección o validación del gestor | Se justificó Firebase considerando consistencia, seguridad, costos, funcionamiento sin conexión, atomicidad y limitaciones | Sección 3 de este documento, [`firestore.rules`](../firestore.rules), [`storage.rules`](../storage.rules) y [`firebase.json`](../firebase.json) | 3.0 |
| 4 | Modelo de base de datos propuesto | Se modelaron `users`, `offices`, `faceProfiles`, `attendances` y las evidencias en Cloudinary, incluyendo relaciones, geocerca, biometría, consentimiento, retención e identificadores determinísticos | [`02-modelo-y-diccionario.md`](02-modelo-y-diccionario.md), [`06-politica-privacidad-retencion.md`](06-politica-privacidad-retencion.md), índices y reglas Firestore | 4.0 |
| 5 | Diccionario de datos | Se documentaron campos, tipos, obligatoriedad, nulabilidad, dominio, origen, ejemplo, validaciones y nivel de sensibilidad | [`02-modelo-y-diccionario.md`](02-modelo-y-diccionario.md) | 2.0 |
| 6 | Matriz pantalla–dato–consulta | Cada pantalla se relacionó con componentes Flutter, datos, repositorios, consultas reales, reglas y estados de error | [`03-matriz-pantalla-dato-consulta.md`](03-matriz-pantalla-dato-consulta.md) | 2.0 |
| 7 | Consultas del MVP y CRUD | Se implementaron lecturas en tiempo real, historial filtrado y limitado, creación y actualización transaccional, control de duplicidad, consentimiento por marcación y manejo de errores | Repositorios de `lib/features`, reglas Firestore y pruebas automatizadas | 2.0 |
| 8 | Datos de prueba, implementación y defensa | Se incluyen pruebas Flutter y de reglas para GPS, biometría, prueba de vida, constancia, consentimiento y conservación | [`04-pruebas-y-defensa.md`](04-pruebas-y-defensa.md), [`06-politica-privacidad-retencion.md`](06-politica-privacidad-retencion.md) y carpeta [`evidencias`](evidencias) | 2.0 |
|  | **Total objetivo** |  |  | **20.0** |

## 3. Justificación del gestor Firebase

### 3.1. Consistencia

Cada asistencia utiliza el identificador determinístico `{uid}_{YYYY-MM-DD}`. Esto impide crear varios documentos diarios para el mismo trabajador.

La entrada y la salida se registran mediante transacciones de Firestore que primero leen el estado actual y después crean o actualizan el documento.

### 3.2. Seguridad

Firebase Authentication identifica al usuario. Las reglas de Firestore verifican adicionalmente:

- Perfil existente.
- Estado activo.
- Rol autorizado.
- Sede asignada.
- Propiedad de la asistencia.
- Estructura y tipos de los documentos.
- Ruta, tamaño, formato y metadatos de la evidencia.
- Inmutabilidad de los campos críticos.
- Prohibición de eliminar asistencias confirmadas.
- Consentimiento facial activo.
- Finalidad y versión del aviso de privacidad.
- Fecha de conservación de la evidencia.

La interfaz nunca se considera una barrera de seguridad; la autorización se aplica nuevamente en Firebase.

### 3.3. Costos

Authentication y Firestore pueden utilizarse dentro de las cuotas gratuitas del plan Spark durante el desarrollo. Los emuladores permiten probar reglas, consultas y datos sin consumir recursos de producción.

Firestore y Authentication pueden operar dentro de sus cuotas gratuitas durante
el desarrollo. Las fotografías se almacenan en Cloudinary mediante un preset
restringido; el secreto administrativo no se incorpora al APK.

### 3.4. Funcionamiento sin conexión

Firestore dispone de caché local para consultas previamente obtenidas. Sin embargo, el MVP no permite confirmar una asistencia sin conexión porque necesita:

- Hora controlada por el servidor.
- Transacción contra el estado más reciente.
- Validación de duplicidad.
- Carga de evidencia.
- Evaluación de reglas de seguridad.

Esta decisión evita mostrar como confirmada una asistencia que todavía no existe en el servidor.

### 3.5. Atomicidad

La creación o actualización del documento de asistencia es atómica dentro de Firestore.

Cloudinary y Firestore son servicios independientes y no comparten una única
transacción. Si Firestore rechaza la marcación después de subir la fotografía,
la aplicación identifica la evidencia provisional. Su eliminación efectiva debe
ejecutarse desde un backend autorizado porque el móvil no contiene el secreto de
Cloudinary.

### 3.6. Limitaciones conocidas

- El GPS de un teléfono no garantiza por sí solo la identidad física del trabajador.
- La detección de ubicación simulada reduce el fraude, pero no elimina todos los ataques posibles.
- El panel administrativo está orientado a móvil; no existe un portal web
  independiente.
- La asistencia requiere conexión al servidor.
- Las reglas deben mantenerse sincronizadas con el modelo de datos.
- Las evidencias fotográficas incrementan almacenamiento, transferencia y consideraciones de privacidad.

## 4. Implementación comprobable

| Módulo | Implementación principal |
|---|---|
| Autenticación | `FirebaseAuthRepository`, `AuthGate` y `LoginScreen` |
| Perfil y autorización | `FirestoreUserRepository` y `ProfileGate` |
| Sede | `FirestoreOfficeRepository` y `OfficeGate` |
| GPS | `GeolocatorLocationService` |
| Geocerca | `GeofenceValidator` con Haversine, precisión y ubicación simulada |
| Asistencia | `FirestoreAttendanceRepository` y transacciones |
| Coordinación | `AttendanceRegistrationService` |
| Cámara y prueba de vida | `EmbeddedEvidenceCamera` y `LivenessValidator` |
| Comparación facial | `MobileFaceVerificationService` y `FirestoreFaceProfileRepository` |
| Fotografías | `CloudinaryEvidenceRepository` |
| Privacidad | `PrivacyPolicy`, `PrivacyNoticeScreen` y consentimiento por marcación |
| Registro de jornada | `AttendanceRegistrationCard` |
| Historial | `AttendanceHistoryScreen` |
| Administración | `AdminDashboardScreen` y `FirebaseAdminRepository` |
| Personal | `AdminUsersScreen` |
| Sedes administrativas | `AdminOfficesScreen` |
| Auditoría de asistencias | `AdminAttendancesScreen` |
| Seguridad | `firestore.rules`, preset restringido y secretos fuera del APK |
| Entorno local | Firebase Emulator Suite y `seed-demo.js` |

## 5. Resultados de verificación

| Verificación | Resultado | Evidencia |
|---|---|---|
| `flutter analyze` | Sin problemas; código de salida 0 | [`07-flutter-analyze.txt`](evidencias/07-flutter-analyze.txt) |
| `flutter test` | La versión 1.7.0 contiene 47 pruebas, incluidas jornadas nocturnas y constancia hospitalaria | Resultado de terminal y archivos de `test/` |
| Reglas de Firestore | 36 casos incluidos, con consentimiento y conservación | `firebase-tests/test/firestore.rules.test.js` |
| Evolución del proyecto | Historial incremental desde el proyecto limpio | [`09-historial-git.txt`](evidencias/09-historial-git.txt) |

## 6. Evidencias visuales

| Evidencia | Archivo |
|---|---|
| Auditoría y calificación inicial | [`00-rubrica-inicial.png`](evidencias/00-rubrica-inicial.png) |
| Perfil administrador almacenado | [`01-perfil-administrador-firestore.png`](evidencias/01-perfil-administrador-firestore.png) |
| Sede UNH Pampas almacenada | [`02-sede-unh-pampas-firestore.png`](evidencias/02-sede-unh-pampas-firestore.png) |
| Rechazo por estar fuera de la geocerca | [`03-validacion-fuera-del-radio.png`](evidencias/03-validacion-fuera-del-radio.png) |
| Ubicación geográfica permitida | [`04-validacion-geografica-correcta.png`](evidencias/04-validacion-geografica-correcta.png) |
| Asistencia creada en Firestore | [`05-asistencia-firestore.png`](evidencias/05-asistencia-firestore.png) |
| Evidencia fotográfica almacenada | [`06-evidencia-storage.png`](evidencias/06-evidencia-storage.png) |
| Evidencia histórica de una versión anterior en simulador iPhone | [`12-ios-launch.png`](evidencias/12-ios-launch.png) |
| Preparación iOS 15.5 de la versión 1.7.0 | [`07-compatibilidad-ios.md`](07-compatibilidad-ios.md) y `.github/workflows/ios-build.yml` |

## 7. Flujo que puede demostrarse

1. Iniciar Firebase Emulator Suite.
2. Cargar los datos reproducibles de demostración.
3. Ejecutar la aplicación Android contra los emuladores.
4. Autenticarse con el trabajador de prueba.
5. Comprobar que el perfil esté activo y tenga una sede.
6. Simular la ubicación de UNH Pampas.
7. Validar distancia, precisión y ausencia de GPS simulado.
8. Leer y aceptar el aviso de privacidad de la marcación.
9. Superar el desafío de prueba de vida y la comparación facial.
10. Registrar la entrada mediante transacción.
11. Comprobar consentimiento, finalidad y fecha de conservación en Firestore.
12. Confirmar la fotografía en Cloudinary.
13. Repetir el flujo para la salida sin modificar la entrada.
14. Consultar la constancia y el historial personal.

## 8. Conclusión

El proyecto dispone de trazabilidad entre problema, datos, modelo, interfaz, consultas, reglas, implementación y pruebas. Las evidencias pueden verificarse directamente en el repositorio y reproducirse mediante Firebase Emulator Suite.

La documentación y las pruebas respaldan el puntaje máximo objetivo de la rúbrica; la calificación definitiva corresponde al docente.
