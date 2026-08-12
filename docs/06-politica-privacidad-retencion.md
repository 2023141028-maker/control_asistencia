# Política de privacidad y conservación de evidencias

## 1. Alcance

Esta política corresponde a **Control de Asistencia 1.6.0**. Su finalidad es
documentar el tratamiento mínimo de datos necesario para validar una entrada o
salida presencial. No convierte la constancia de asistencia en comprobante de
pago y no incorpora cálculos tributarios.

## 2. Datos tratados

| Dato | Finalidad | Ubicación | Acceso |
|---|---|---|---|
| UID y código laboral | Relacionar la marcación con la cuenta autenticada | Firestore | Trabajador propietario y administrador |
| Fecha, hora y sede | Trazabilidad laboral | Firestore | Trabajador propietario y administrador |
| Coordenada, precisión y distancia | Verificar presencia en la sede | Firestore | Trabajador propietario y administrador |
| Fotografía frontal | Evidencia y verificación de identidad | Cloudinary; Firestore conserva solo la URL | Acceso administrativo autorizado |
| Plantilla facial de 192 valores | Comparación facial local | `faceProfiles` en Firestore | Trabajador propietario y administrador; escritura solo administrativa |
| Resultado facial y prueba de vida | Justificar la decisión de registro | Firestore | Trabajador propietario y administrador |

No se solicitan DNI, números bancarios, tarjetas, remuneraciones ni datos
tributarios. Las demostraciones y capturas de la entrega deben utilizar cuentas
ficticias.

## 3. Consentimiento verificable

La matrícula facial requiere que el administrador confirme mediante una casilla
que el trabajador está presente, fue informado y aceptó expresamente. El perfil
facial registra:

- versión del consentimiento;
- versión del aviso de privacidad;
- método presencial explícito;
- fecha del servidor;
- UID del administrador que registró la aceptación.

Antes de cada entrada o salida, el trabajador debe marcar una casilla de
aceptación. Si no lo hace, el botón para abrir la cámara permanece deshabilitado.
La aplicación y las reglas de Firestore registran y validan:

- `privacyConsentAccepted: true`;
- `privacyConsentVersion: 1.1`;
- `evidencePurpose: attendance-verification`;
- `evidenceRetentionUntil`.

## 4. Conservación

Las nuevas evidencias fotográficas tienen un plazo configurado de **90 días**.
Firestore comprueba que la fecha declarada se encuentre entre 89 y 91 días
respecto de la hora controlada por el servidor. La pequeña tolerancia permite
el tiempo transcurrido entre la captura, el GPS, la subida y la transacción.

Al vencer el plazo, la fotografía debe eliminarse mediante un backend o proceso
administrativo autorizado que mantenga el secreto de Cloudinary fuera del APK.
La versión móvil no contiene ese secreto y, por ello, no promete una eliminación
automática que técnicamente no pueda ejecutar.

Los metadatos de asistencia pueden conservarse durante el periodo institucional
necesario para auditoría laboral. La organización responsable debe aprobar el
plazo definitivo antes de un despliegue productivo.

## 5. Retiro y atención de solicitudes

El trabajador puede solicitar al responsable del sistema:

- consultar el tratamiento aplicado;
- desactivar o reemplazar su plantilla facial;
- retirar el consentimiento para nuevas marcaciones biométricas;
- revisar o eliminar una evidencia cuando no exista una obligación de
  conservación aplicable.

El retiro debe desactivar la plantilla en `faceProfiles`. Las reglas impiden
nuevas asistencias cuando no existe un consentimiento facial activo.

## 6. Controles técnicos

- Autenticación mediante Firebase Authentication.
- Acceso por propietario o administrador activo.
- Plantillas faciales no listables por trabajadores.
- Secreto de Cloudinary excluido del código y del APK.
- HTTPS obligatorio para referencias de evidencia.
- Reglas que exigen finalidad, consentimiento y fecha de conservación.
- Nombre enmascarado en la constancia.
- Rechazo de ubicación simulada, baja precisión y distancia no permitida.
- Prueba de vida activa y comparación facial antes de subir la evidencia.

## 7. Limitación declarada

La prueba de vida reduce intentos con fotografías estáticas, pero no constituye
una certificación especializada de detección de ataques de presentación. La
política de 90 días es una configuración técnica del proyecto y debe ser
ratificada por la institución responsable conforme a sus obligaciones reales.
