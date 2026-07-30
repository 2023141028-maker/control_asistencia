const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  GeoPoint,
  setDoc,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'control-asistencia-d468b';
const AUTH_HOST = '127.0.0.1';
const AUTH_PORT = 9099;
const FIRESTORE_HOST = '127.0.0.1';
const FIRESTORE_PORT = 8080;
const OFFICE_ID = 'unh-pampas';

const email = (
  process.env.DEMO_EMAIL ?? 'empleado.demo@unh.edu.pe'
).trim().toLowerCase();

const password = process.env.DEMO_PASSWORD ?? '';

async function readResponse(response) {
  const text = await response.text();

  if (text.length === 0) return {};

  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
}

async function resetAuthEmulator() {
  const url =
    `http://${AUTH_HOST}:${AUTH_PORT}/emulator/v1/projects/` +
    `${encodeURIComponent(PROJECT_ID)}/accounts`;

  const response = await fetch(url, { method: 'DELETE' });
  const body = await readResponse(response);

  if (!response.ok) {
    throw new Error(
      `No se pudo limpiar Authentication Emulator: ${JSON.stringify(body)}`,
    );
  }
}

async function createDemoAuthUser() {
  const url =
    `http://${AUTH_HOST}:${AUTH_PORT}/identitytoolkit.googleapis.com/` +
    'v1/accounts:signUp?key=demo-key';

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });

  const body = await readResponse(response);

  if (!response.ok) {
    throw new Error(
      `No se pudo crear el usuario local: ${JSON.stringify(body)}`,
    );
  }

  if (typeof body.localId !== 'string' || body.localId.length === 0) {
    throw new Error('Authentication Emulator no devolvió un UID válido.');
  }

  return body.localId;
}

async function main() {
  if (password.length < 8) {
    throw new Error(
      'DEMO_PASSWORD debe tener al menos 8 caracteres.',
    );
  }

  let testEnvironment;

  try {
    await resetAuthEmulator();
    const uid = await createDemoAuthUser();

    testEnvironment = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: FIRESTORE_HOST,
        port: FIRESTORE_PORT,
      },
    });

    await testEnvironment.clearFirestore();

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const database = context.firestore();
      const now = Timestamp.now();

      await Promise.all([
        setDoc(doc(database, 'offices', OFFICE_ID), {
          active: true,
          address: 'Av. Perú, Daniel Hernández 09161',
          createdAt: now,
          location: new GeoPoint(-12.389037, -74.858949),
          maxAccuracyMeters: 30,
          name: 'UNH sede Pampas',
          radiusMeters: 100,
          schemaVersion: 1,
          timezone: 'America/Lima',
          updatedAt: now,
        }),

        setDoc(doc(database, 'users', uid), {
          uid,
          email,
          fullName: 'Empleado Demo',
          employeeCode: 'EMP-DEMO-001',
          role: 'employee',
          status: 'active',
          officeId: OFFICE_ID,
          schemaVersion: 1,
          createdAt: now,
          updatedAt: now,
        }),
      ]);
    });

    console.log('');
    console.log('EMULADORES PREPARADOS CORRECTAMENTE');
    console.log(`Correo local: ${email}`);
    console.log(`UID local: ${uid}`);
    console.log(`Sede: ${OFFICE_ID}`);
  } finally {
    if (testEnvironment !== undefined) {
      await testEnvironment.cleanup();
    }
  }
}

main().catch((error) => {
  console.error('');
  console.error('NO SE PUDO PREPARAR EL ENTORNO LOCAL');
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});