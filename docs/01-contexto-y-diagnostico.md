# Contexto, alcance y diagnóstico de datos

## Información del proyecto

| Elemento | Descripción |

|---|---|

| Proyecto | Control de Asistencia |

| Institución | Universidad Nacional de Huancavelica |

| Sede del caso de estudio | UNH sede Pampas |

| Autor | Wilder Huaman Quispe |

| Código | 2023141028 |

| Plataforma | Aplicación móvil Android desarrollada con Flutter |

| Repositorio | https://github.com/2023141028-maker/control\_asistencia |

| Backend | Firebase Authentication, Cloud Firestore y Cloud Storage |

## 1. Contextualización del problema

El control de asistencia de trabajadores requiere comprobar no solamente la identidad del usuario, sino también el momento, lugar y evidencia asociados a cada registro.

Un procedimiento manual o basado solamente en una hora ingresada por el trabajador puede producir:

- Suplantación de identidad.

- Registros realizados fuera de la sede.

- Duplicidad de entradas o salidas.

- Alteración de fechas y horas.

- Ausencia de evidencia comprobable.

- Dificultad para auditar una jornada.

- Acceso no autorizado a información de otros trabajadores.

El sistema propuesto registra la entrada y salida mediante una aplicación móvil que integra autenticación, perfil autorizado, sede asignada, geolocalización, evidencia fotográfica y marcas de tiempo del servidor.

## 2. Usuarios involucrados

### 2.1. Trabajador

Es el usuario principal del MVP. Necesita:

- Iniciar sesión de manera segura.

- Consultar su perfil.

- Conocer la sede que tiene asignada.

- Validar si se encuentra dentro del radio permitido.

- Registrar una entrada.

- Registrar una salida.

- Consultar su propia jornada.

- Recibir mensajes claros cuando una validación falla.

El trabajador no puede asignarse un rol, activar su cuenta, modificar su sede ni consultar asistencias ajenas.

### 2.2. Administrador

Es responsable de:

- Registrar o autorizar perfiles.

- Asignar roles y sedes.

- Activar o desactivar trabajadores.

- Consultar asistencias.

- Consultar evidencias cuando corresponda.

- Mantener la configuración geográfica de las sedes.

La interfaz administrativa completa queda fuera del alcance del MVP móvil, pero sus permisos y restricciones están contemplados en el modelo y en las reglas de seguridad.

## 3. Objetivo del MVP

Implementar un sistema móvil capaz de registrar una jornada diaria por trabajador, validando:

1\. Identidad autenticada.

2\. Perfil autorizado y activo.

3\. Sede asignada y activa.

4\. Ubicación GPS precisa.

5\. Permanencia dentro del radio permitido.

6\. Ausencia de ubicación simulada.

7\. Evidencia fotográfica válida.

8\. Entrada o salida coherente con el estado de la jornada.

9\. Fecha y hora controladas por Firebase.

## 4. Alcance funcional

### 4.1. Funciones incluidas

- Inicio y cierre de sesión.

- Control de acceso por perfil, rol y estado.

- Consulta de sede asignada.

- Validación de ubicación geográfica.

- Cálculo de distancia con la fórmula de Haversine.

- Control de precisión máxima del GPS.

- Detección de ubicación simulada.

- Captura de fotografía con cámara frontal.

- Validación de formato y tamaño de evidencia.

- Registro transaccional de entrada.

- Registro transaccional de salida.

- Prevención de duplicidad.

- Consulta de la jornada diaria.

- Consulta limitada del historial propio.

- Reglas de seguridad de Firestore.

- Reglas de seguridad de Storage.

- Pruebas automatizadas con Firebase Emulator Suite.

### 4.2. Elementos fuera del alcance

- Reconocimiento facial.

- Verificación biométrica.

- Gestión de remuneraciones.

- Control de permisos y vacaciones.

- Múltiples turnos durante un mismo día.

- Marcación sin conexión.

- Panel web administrativo completo.

- Reportes estadísticos avanzados.

- Integración con dispositivos biométricos externos.

Estos elementos pueden implementarse en versiones futuras sin modificar la finalidad principal del MVP.

## 5. Módulos implementados

| Módulo | Responsabilidad |

|---|---|

| Autenticación | Iniciar sesión, observar la sesión y cerrarla |

| Usuarios | Consultar perfil, rol, estado y sede asignada |

| Sedes | Obtener configuración geográfica y estado |

| Ubicación | Obtener GPS, precisión y señal de ubicación simulada |

| Geocerca | Calcular distancia y decidir si la ubicación es válida |

| Evidencia | Capturar, validar, subir y eliminar fotografías temporales |

| Asistencia | Registrar entrada, salida y consultar jornada |

| Seguridad | Restringir datos mediante reglas de Firestore y Storage |

| Emuladores | Reproducir Authentication, Firestore y Storage localmente |

| Pruebas | Validar dominio, widgets, repositorios y reglas |

## 6. Insumos utilizados

| Insumo | Aplicación dentro del proyecto |

|---|---|

| Rúbrica y auditoría inicial | Identificación de brechas de datos, seguridad, modelo y pruebas |

| Repositorio original | Evidencia del punto de partida y del historial de mejora |

| Requisitos del MVP | Definición de actores, módulos y reglas |

| Datos de UNH sede Pampas | Configuración de la geocerca |

| Coordenadas de la sede | Centro para calcular la distancia |

| Radio de 100 metros | Límite de aceptación geográfica |

| Precisión máxima de 30 metros | Control de calidad del GPS |

| Código Flutter | Implementación móvil y separación por capas |

| Configuración Firebase | Conexión con Authentication, Firestore y Storage |

| Reglas de seguridad | Validación de autorización e integridad |

| Índices Firestore | Soporte para consultas ordenadas y filtradas |

| Pruebas automatizadas | Evidencia reproducible de casos permitidos y rechazados |

| Historial Git | Evidencia cronológica y verificable del avance |

| Capturas del emulador | Evidencia visual de entrada, salida, Firestore y Storage |

## 7. Evidencia del avance real

El desarrollo se encuentra dividido en commits con responsabilidades específicas. Entre los principales están:

| Commit | Evidencia |

|---|---|

| `e0a03b1` | Configuración inicial de Firebase |

| `86cf54a` | Inicio de sesión seguro |

| `f9953d7` | Perfiles y control de acceso |

| `a01cfd1` | Integración de sede asignada |

| `0d6027d` | Servicio y validación geográfica |

| `cbed8ea` | Integración de geolocalización en la interfaz |

| `2accab9` | Registro transaccional de asistencia |

| `d6a637a` | Pruebas de reglas Firestore |

| `9a711b1` | Pruebas de reglas Storage |

| `e0aca42` | Captura y coordinación de evidencia |

| `21717ca` | Flujo completo de entrada y salida |

| `2eb534f` | Entorno local reproducible con emuladores |

El historial puede verificarse con:

```powershell

git log --oneline --graph --decorate --all
