# Adaptación hospitalaria — versión 1.7.0

La aplicación registra la asistencia de trabajadores de un hospital y conserva
las validaciones de identidad, prueba de vida, ubicación y evidencia existentes.

## Datos agregados al perfil

| Campo Firestore | Descripción | Ejemplo |
|---|---|---|
| `hospitalArea` | Área en la que presta servicio | `emergency` |
| `position` | Cargo o función laboral | `Enfermero asistencial` |
| `shift` | Turno fijo asignado | `night` |

Los valores permitidos para `shift` son `morning`, `afternoon`, `night` y
`guard-24h`. El administrador asigna estos datos desde **Personal**. Un
trabajador activo no puede registrar asistencia si su perfil hospitalario está
incompleto.

## Jornada nocturna

Los turnos `night` y `guard-24h` atraviesan la medianoche. Una marcación hecha
antes de las 07:00 se asocia a la fecha en que inició el turno. Por ejemplo:

- Entrada: 13/08/2026 a las 19:00.
- Salida: 14/08/2026 a las 06:30.
- Fecha laboral de ambas marcas: `2026-08-13`.

Esta regla evita crear dos asistencias distintas para una misma jornada
hospitalaria.

## Actualización de perfiles existentes

Los perfiles anteriores continúan siendo legibles. El administrador debe abrir
cada trabajador, completar área, cargo y turno, y guardar. Después debe publicar
las reglas actualizadas:

```powershell
firebase use control-asistencia-d468b
firebase deploy --only firestore:rules
```

## Verificación local

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release `
  --dart-define=CLOUDINARY_CLOUD_NAME=SU_CLOUD `
  --dart-define=CLOUDINARY_UNSIGNED_UPLOAD_PRESET=SU_PRESET
```

El APK se genera en `build\app\outputs\flutter-apk\app-release.apk`.
