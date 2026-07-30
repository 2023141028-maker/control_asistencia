# Control de Asistencia

Aplicación móvil desarrollada con Flutter y Firebase para registrar la entrada y salida de trabajadores mediante autenticación, validación geográfica y evidencia fotográfica.

## Problema

El registro manual de asistencia puede presentar suplantaciones, duplicidad, información incompleta y dificultad para comprobar si el trabajador se encontraba realmente en la sede autorizada.

Este proyecto propone un MVP que registra cada jornada con:

- Usuario autenticado.

- Perfil activo y sede asignada.

- Ubicación GPS precisa.

- Validación del radio geográfico.

- Detección de ubicaciones simuladas.

- Evidencia fotográfica.

- Fecha y hora del servidor.

- Control transaccional de entrada y salida.

## Usuarios

### Trabajador

Puede:

- Iniciar y cerrar sesión.

- Consultar su perfil y sede.

- Validar su ubicación.

- Registrar una entrada diaria.

- Registrar una salida.

- Consultar sus propias asistencias.

### Administrador

Puede:

- Consultar los perfiles registrados.

- Consultar asistencias y evidencias.

- Activar o desactivar trabajadores.

- Asignar una sede y un rol.

La interfaz administrativa completa no forma parte del alcance actual del MVP. Estas operaciones están protegidas mediante reglas de seguridad.

## Alcance del MVP

El MVP implementa:

- Inicio de sesión con Firebase Authentication.

- Autorización mediante perfiles almacenados en Firestore.

- Roles `admin` y `employee`.

- Estados `active`, `inactive` y `pending`.

- Asignación de una sede por trabajador.

- Consulta de la configuración geográfica de la sede.

- Obtención de ubicación GPS precisa.

- Cálculo de distancia mediante la fórmula de Haversine.

- Rechazo de ubicaciones simuladas.

- Captura de fotografía con la cámara frontal.

- Validación de archivo JPEG de hasta 2 MB.

- Registro transaccional de entrada y salida.

- Prevención de registros duplicados.

- Consulta limitada del historial propio.

- Reglas de seguridad para Firestore y Cloud Storage.

- Pruebas unitarias, de widgets y de reglas con emuladores.

No incluye planillas, permisos laborales, reconocimiento facial, cálculo de remuneraciones ni múltiples turnos.

## Sede configurada

| Campo | Valor |

|---|---|

| Identificador | `unh-pampas` |

| Nombre | UNH sede Pampas |

| Dirección | Av. Perú, Daniel Hernández 09161 |

| Latitud | `-12.389037` |

| Longitud | `-74.858949` |

| Radio permitido | 100 metros |

| Precisión máxima | 30 metros |

| Zona horaria | `America/Lima` |

## Arquitectura

El proyecto separa responsabilidades en cuatro capas:

- `presentation`: pantallas, tarjetas y puertas de acceso.

- `application`: coordinación del registro de asistencia.

- `domain`: entidades, contratos y reglas de negocio.

- `data`: implementaciones con Firebase, Geolocator e Image Picker.

```mermaid

flowchart TD

&#x20;   A\[Interfaz Flutter] --> B\[Casos de uso]

&#x20;   B --> C\[Reglas de dominio]

&#x20;   C --> D\[Firebase]

&#x20;   C --> E\[GPS y cámara]
