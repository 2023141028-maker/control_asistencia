const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  GeoPoint,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} = require("firebase/firestore");

const PROJECT_ID = "control-asistencia-d468b";
const OFFICE_ID = "unh-pampas";
const OTHER_OFFICE_ID = "otra-sede";
const USER_ID = "employee-001";
const OTHER_USER_ID = "employee-002";
const INACTIVE_USER_ID = "employee-inactive";
const ADMIN_ID = "admin-001";
const WORK_DATE = "2026-07-30";
const LATITUDE = -12.389037;
const LONGITUDE = -74.858949;

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

let testEnv;

const fixedTimestamp = () =>
  Timestamp.fromDate(new Date("2026-07-30T13:00:00.000Z"));

function profile(
  uid,
  { role = "employee", status = "active", officeId = OFFICE_ID } = {},
) {
  return {
    uid,
    email: `${uid}@example.com`,
    fullName: `Usuario ${uid}`,
    employeeCode: uid,
    role,
    status,
    officeId,
    schemaVersion: 1,
    createdAt: fixedTimestamp(),
    updatedAt: fixedTimestamp(),
  };
}

function office(latitude = LATITUDE, longitude = LONGITUDE) {
  return {
    name: "UNH sede Pampas",
    address: "Av. Perú, Daniel Hernández 09161",
    location: new GeoPoint(latitude, longitude),
    radiusMeters: 100,
    maxAccuracyMeters: 30,
    timezone: "America/Lima",
    active: true,
    schemaVersion: 1,
    createdAt: fixedTimestamp(),
    updatedAt: fixedTimestamp(),
  };
}

const attendanceId = (uid = USER_ID) => `${uid}_${WORK_DATE}`;

const attendanceRef = (database, uid = USER_ID) =>
  doc(database, "attendances", attendanceId(uid));

const evidencePath = (uid, event) =>
  `attendanceEvidence/${uid}/${attendanceId(uid)}/${event}.jpg`;

function mark({
  uid = USER_ID,
  event = "check-in",
  latitude = LATITUDE,
  longitude = LONGITUDE,
  accuracyMeters = 10,
  distanceMeters = 0,
  isMocked = false,
  customEvidencePath,
} = {}) {
  return {
    capturedAt: Timestamp.now(),
    recordedAt: serverTimestamp(),
    location: new GeoPoint(latitude, longitude),
    accuracyMeters,
    distanceMeters,
    isMocked,
    evidencePath: customEvidencePath ?? evidencePath(uid, event),
  };
}

function entry({
  uid = USER_ID,
  officeId = OFFICE_ID,
  markOverrides = {},
  status = "checked-in",
  checkOut = null,
} = {}) {
  return {
    userId: uid,
    officeId,
    workDate: WORK_DATE,
    mode: "onsite",
    status,
    checkIn: mark({
      uid,
      event: "check-in",
      ...markOverrides,
    }),
    checkOut,
    schemaVersion: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

const checkOutMark = (overrides = {}) =>
  mark({
    uid: USER_ID,
    event: "check-out",
    ...overrides,
  });

const authenticatedDb = (uid) =>
  testEnv
    .authenticatedContext(uid, {
      email: `${uid}@example.com`,
    })
    .firestore();

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();

    await Promise.all([
      setDoc(
        doc(database, "users", USER_ID),
        profile(USER_ID),
      ),
      setDoc(
        doc(database, "users", OTHER_USER_ID),
        profile(OTHER_USER_ID, {
          officeId: OTHER_OFFICE_ID,
        }),
      ),
      setDoc(
        doc(database, "users", INACTIVE_USER_ID),
        profile(INACTIVE_USER_ID, {
          status: "inactive",
        }),
      ),
      setDoc(
        doc(database, "users", ADMIN_ID),
        profile(ADMIN_ID, {
          role: "admin",
          officeId: null,
        }),
      ),
      setDoc(
        doc(database, "offices", OFFICE_ID),
        office(),
      ),
      setDoc(
        doc(database, "offices", OTHER_OFFICE_ID),
        office(-12.4, -74.87),
      ),
    ]);
  });
}

async function createValidEntry() {
  const database = authenticatedDb(USER_ID);

  await assertSucceeds(
    setDoc(attendanceRef(database), entry()),
  );
}

describe("Reglas de seguridad de asistencias", function () {
  this.timeout(30000);

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        host: "127.0.0.1",
        port: 8080,
        rules,
      },
    });
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seedBaseData();
  });

  after(async () => {
    await testEnv.cleanup();
  });

  it("01 rechaza usuario no autenticado", async () => {
    const database =
      testEnv.unauthenticatedContext().firestore();

    await assertFails(
      setDoc(attendanceRef(database), entry()),
    );
  });

  it("02 rechaza trabajador inactivo", async () => {
    const database = authenticatedDb(INACTIVE_USER_ID);

    await assertFails(
      setDoc(
        attendanceRef(database, INACTIVE_USER_ID),
        entry({ uid: INACTIVE_USER_ID }),
      ),
    );
  });

  it("03 permite entrada válida", async () => {
    const database = authenticatedDb(USER_ID);

    await assertSucceeds(
      setDoc(attendanceRef(database), entry()),
    );
  });

  it("04 rechaza sede no asignada", async () => {
    const database = authenticatedDb(USER_ID);

    await assertFails(
      setDoc(
        attendanceRef(database),
        entry({ officeId: OTHER_OFFICE_ID }),
      ),
    );
  });

  const invalidLocationCases = [
    [
      "05 rechaza GPS simulado",
      { isMocked: true },
    ],
    [
      "06 rechaza precisión insuficiente",
      { accuracyMeters: 31 },
    ],
    [
      "07 rechaza coordenadas lejanas con distancia declarada cero",
      {
        latitude: -12.0,
        longitude: -75.0,
        distanceMeters: 0,
      },
    ],
    [
      "08 rechaza distancia que no coincide con las coordenadas",
      { distanceMeters: 50 },
    ],
    [
      "09 rechaza ruta de evidencia incorrecta",
      { customEvidencePath: "evidencias/foto.jpg" },
    ],
  ];

  for (const [name, markOverrides] of invalidLocationCases) {
    it(name, async () => {
      const database = authenticatedDb(USER_ID);

      await assertFails(
        setDoc(
          attendanceRef(database),
          entry({ markOverrides }),
        ),
      );
    });
  }

  it("10 rechaza entrada duplicada", async () => {
    const database = authenticatedDb(USER_ID);

    await assertSucceeds(
      setDoc(attendanceRef(database), entry()),
    );

    await assertFails(
      setDoc(attendanceRef(database), entry()),
    );
  });

  it("11 rechaza salida sin entrada previa", async () => {
    const database = authenticatedDb(USER_ID);

    await assertFails(
      setDoc(
        attendanceRef(database),
        entry({
          status: "completed",
          checkOut: checkOutMark(),
        }),
      ),
    );
  });

  it("12 permite una salida válida", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    await assertSucceeds(
      updateDoc(attendanceRef(database), {
        status: "completed",
        checkOut: checkOutMark(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("13 impide modificar la entrada al registrar salida", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    await assertFails(
      updateDoc(attendanceRef(database), {
        status: "completed",
        checkIn: mark({ distanceMeters: 1 }),
        checkOut: checkOutMark(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("14 rechaza una segunda salida", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    await assertSucceeds(
      updateDoc(attendanceRef(database), {
        status: "completed",
        checkOut: checkOutMark(),
        updatedAt: serverTimestamp(),
      }),
    );

    await assertFails(
      updateDoc(attendanceRef(database), {
        status: "completed",
        checkOut: checkOutMark(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("15 impide eliminar una asistencia", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    await assertFails(
      deleteDoc(attendanceRef(database)),
    );
  });

  it("16 permite al propietario leer su asistencia", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    await assertSucceeds(
      getDoc(attendanceRef(database)),
    );
  });

  it("17 impide que otro trabajador lea la asistencia", async () => {
    await createValidEntry();

    const database = authenticatedDb(OTHER_USER_ID);

    await assertFails(
      getDoc(attendanceRef(database)),
    );
  });

  it("18 permite lectura al administrador activo", async () => {
    await createValidEntry();

    const database = authenticatedDb(ADMIN_ID);

    await assertSucceeds(
      getDoc(attendanceRef(database)),
    );
  });

  it("19 permite historial propio con filtro y límite", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    const historyQuery = query(
      collection(database, "attendances"),
      where("userId", "==", USER_ID),
      orderBy("workDate", "desc"),
      limit(30),
    );

    await assertSucceeds(
      getDocs(historyQuery),
    );
  });

    it("20 rechaza historial sin límite", async () => {
    const database = authenticatedDb(USER_ID);

    await createValidEntry();

    const unlimitedQuery = query(
      collection(database, "attendances"),
      where("userId", "==", USER_ID),
    );

    await assertFails(
      getDocs(unlimitedQuery),
    );
  });

  it("21 permite consultar el documento diario propio aunque no exista", async () => {
    const database = authenticatedDb(USER_ID);

    await assertSucceeds(
      getDoc(attendanceRef(database)),
    );
  });

  it("22 impide consultar un documento diario inexistente ajeno", async () => {
    const database = authenticatedDb(OTHER_USER_ID);

    await assertFails(
      getDoc(attendanceRef(database)),
    );
  });

  it("23 permite al administrador listar perfiles", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertSucceeds(
      getDocs(
        query(
          collection(database, "users"),
          orderBy("fullName"),
          limit(100),
        ),
      ),
    );
  });

  it("24 impide al trabajador listar perfiles", async () => {
    const database = authenticatedDb(USER_ID);

    await assertFails(
      getDocs(
        query(
          collection(database, "users"),
          orderBy("fullName"),
          limit(100),
        ),
      ),
    );
  });

  it("25 permite al administrador crear un perfil válido", async () => {
    const database = authenticatedDb(ADMIN_ID);
    const newUserId = "employee-new";

    await assertSucceeds(
      setDoc(
        doc(database, "users", newUserId),
        {
          ...profile(newUserId),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("26 impide al trabajador crear perfiles", async () => {
    const database = authenticatedDb(USER_ID);
    const newUserId = "employee-forbidden";

    await assertFails(
      setDoc(
        doc(database, "users", newUserId),
        {
          ...profile(newUserId),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("27 permite al administrador actualizar un trabajador", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertSucceeds(
      updateDoc(
        doc(database, "users", USER_ID),
        {
          fullName: "Trabajador Actualizado",
          status: "inactive",
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("28 impide que el administrador cambie su propio rol", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertFails(
      updateDoc(
        doc(database, "users", ADMIN_ID),
        {
          role: "employee",
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("29 permite al administrador crear una sede válida", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertSucceeds(
      setDoc(
        doc(database, "offices", "sede-nueva"),
        {
          ...office(-12.38, -74.85),
          name: "Sede nueva",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("30 permite al administrador actualizar una sede", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertSucceeds(
      updateDoc(
        doc(database, "offices", OFFICE_ID),
        {
          radiusMeters: 120,
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("31 impide al trabajador crear una sede", async () => {
    const database = authenticatedDb(USER_ID);

    await assertFails(
      setDoc(
        doc(database, "offices", "sede-prohibida"),
        {
          ...office(-12.38, -74.85),
          name: "Sede prohibida",
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });

  it("32 impide eliminar perfiles y sedes", async () => {
    const database = authenticatedDb(ADMIN_ID);

    await assertFails(
      deleteDoc(doc(database, "users", USER_ID)),
    );

    await assertFails(
      deleteDoc(doc(database, "offices", OFFICE_ID)),
    );
  });

  it("33 impide asignar una sede inexistente a un trabajador activo", async () => {
    const database = authenticatedDb(ADMIN_ID);
    const newUserId = "employee-invalid-office";

    await assertFails(
      setDoc(
        doc(database, "users", newUserId),
        {
          ...profile(newUserId, {
            officeId: "sede-inexistente",
          }),
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
      ),
    );
  });
});
