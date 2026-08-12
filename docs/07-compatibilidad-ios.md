# Preparación y validación de iOS

## 1. Estado verificable

La versión 1.6.0 está preparada en código para compilarse en iOS 15.5 o
posterior. Esta preparación no equivale por sí sola a una certificación de
funcionamiento en iPhone. La validación final requiere macOS, Xcode, CocoaPods
y una prueba en dispositivo físico.

Android continúa siendo la plataforma funcionalmente verificada. El APK no se
puede instalar en un iPhone; Apple requiere una compilación iOS y, para
distribución, firma mediante una cuenta de Apple Developer.

## 2. Configuración incluida

| Elemento | Configuración |
|---|---|
| Versión mínima | iOS 15.5 |
| Bundle ID | `pe.edu.unh.controlAsistencia` |
| Lenguaje nativo | Swift 5 |
| Arquitecturas | 64 bits; `armv7` excluido |
| Firebase | Opciones iOS incluidas en `firebase_options.dart` |
| Cámara | Permiso y finalidad declarados en `Info.plist` |
| Ubicación | Permiso de uso mientras la app está activa |
| CocoaPods | `ios/Podfile` incluido |
| Automatización | `.github/workflows/ios-build.yml` |

La versión mínima y la exclusión de `armv7` responden a los requisitos del
plugin `google_mlkit_face_detection` usado por la cámara y la prueba de vida.
El motor `face_detection_tflite` declara soporte para iOS y realiza la
comparación facial local. El `Podfile` también desactiva la solicitud de
ubicación permanente porque la aplicación solo obtiene el GPS mientras está
abierta.

## 3. Requisitos para validar en una Mac

- macOS compatible con la versión de Xcode instalada.
- Xcode 15.3 o posterior.
- Flutter 3.44.4 estable.
- CocoaPods disponible.
- Simulador con iOS 15.5 o posterior.
- Para la prueba completa, un iPhone físico y conexión a Internet.

## 4. Compilación reproducible para simulador

Ejecutar desde la raíz del proyecto en macOS:

```bash
flutter doctor -v
flutter pub get
cd ios
pod install
cd ..
flutter analyze
flutter test
flutter build ios --simulator --debug \
  --dart-define=CLOUDINARY_CLOUD_NAME=SU_CLOUD \
  --dart-define=CLOUDINARY_UNSIGNED_UPLOAD_PRESET=SU_PRESET
```

El archivo correcto para abrir manualmente en Xcode es:

```text
ios/Runner.xcworkspace
```

No se debe abrir `Runner.xcodeproj` después de instalar los pods.

## 5. Compilación sin firma para dispositivo

```bash
flutter build ios --release --no-codesign \
  --dart-define=CLOUDINARY_CLOUD_NAME=SU_CLOUD \
  --dart-define=CLOUDINARY_UNSIGNED_UPLOAD_PRESET=SU_PRESET
```

Este comando comprueba la compilación, pero no produce una entrega instalable
en cualquier iPhone. Para instalar o publicar se debe configurar `Team`, firma
y aprovisionamiento en Xcode. Ningún certificado ni clave privada debe
incorporarse al repositorio.

## 6. Pruebas obligatorias en iPhone físico

1. Instalar y abrir la aplicación.
2. Iniciar sesión con una cuenta ficticia.
3. Conceder cámara y ubicación solo mientras se usa la aplicación.
4. Cargar perfil y sede desde Firebase.
5. Validar GPS, radio, precisión y rechazo fuera de sede.
6. Aceptar el aviso de privacidad.
7. Matricular o consultar una plantilla facial de demostración.
8. Verificar exactamente un rostro y el porcentaje de similitud.
9. Superar el giro o inclinación solicitado por la prueba de vida.
10. Subir una evidencia de prueba a Cloudinary.
11. Registrar entrada y salida en Firestore.
12. Confirmar ambas constancias de asistencia.

Las capturas deben ocultar rostro, UID, correo, URL de evidencia y coordenadas
exactas.

## 7. Evidencias para declarar iOS verificado

| Archivo | Contenido mínimo |
|---|---|
| `14_ios_build.png` | Compilación iOS finalizada sin errores |
| `15_ios_simulator.png` | Aplicación iniciada en simulador iPhone |
| `16_ios_permisos.png` | Solicitud de cámara y ubicación |
| `17_ios_flujo_real.png` | Flujo funcional en iPhone con datos ocultos |

Hasta obtener estas evidencias de la versión 1.6.0, el estado correcto es
“preparado para iOS; validación pendiente en macOS”, no “iOS aprobado”.
