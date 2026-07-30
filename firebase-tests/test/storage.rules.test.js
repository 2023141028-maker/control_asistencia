const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  Timestamp,
} = require("firebase/firestore");
const {
  deleteObject,
  getMetadata,
  ref,
  updateMetadata,
  uploadBytes,
} = require("firebase/storage");

const PROJECT_ID = "control-asistencia-d468b";
const BUCKET_URL =
  "gs://control-asistencia-d468b";
const OFFICE_ID = "unh-pampas";
const USER_ID = "employee-001";
const OTHER_USER_ID = "employee-002";
const INACTIVE_USER_ID = "employee-inactive";
const ADMIN_ID = "admin-001";
const WORK_DATE = "2026-07-30";
const ATTENDANCE_ID = `${USER_ID}_${WORK_DATE}`;

const CHECK_IN_PATH =
  `attendanceEvidence/${USER_ID}/${ATTENDANCE_ID}/check-in.jpg`;

const CHECK_OUT_PATH =
  `attendanceEvidence/${USER_ID}/${ATTENDANCE_ID}/check-out.jpg`;

const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8",
);

const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8",
);

let testEnv;

const fixedTimestamp = () =>
  Timestamp.fromDate(
    new Date("2026-07-30T13:00:00.000Z"),
  );

function profile(
  uid,
  {
    role = "employee",
    status = "active",
    officeId = OFFICE_ID,
  } = {},
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

function checkedInAttendance({ completed = false } = {}) {
  return {
    userId: USER_ID,
    officeId: OFFICE_ID,
    workDate: WORK_DATE,
    mode: "onsite",
    status: completed ? "completed" : "checked-in",
    checkIn: {
      evidencePath: CHECK_IN_PATH,
    },
    checkOut: completed
      ? {
          evidencePath: CHECK_OUT_PATH,
        }
      : null,
    schemaVersion: 1,
    createdAt: fixedTimestamp(),
    updatedAt: fixedTimestamp(),
  };
}

function metadata({
  ownerUid = USER_ID,
  attendanceId = ATTENDANCE_ID,
  eventName = "check-in",
  officeId = OFFICE_ID,
  schemaVersion = "1",
} = {}) {
  return {
    contentType: "image/jpeg",
    customMetadata: {
      ownerUid,
      attendanceId,
      eventName,
      officeId,
      schemaVersion,
    },
  };
}

function jpegBytes(size = 32) {
  const bytes = new Uint8Array(size);

  if (size >= 4) {
    bytes[0] = 0xff;
    bytes[1] = 0xd8;
    bytes[size - 2] = 0xff;
    bytes[size - 1] = 0xd9;
  }

  return bytes;
}

function storageFor(uid) {
  return testEnv
    .authenticatedContext(uid, {
      email: `${uid}@example.com`,
    })
    .storage(BUCKET_URL);
}

function storageRefFor(
  storage,
  objectPath = CHECK_IN_PATH,
) {
  return ref(storage, objectPath);
}

async function seedProfiles() {
  await testEnv.withSecurityRulesDisabled(
    async (context) => {
      const database = context.firestore();

      await Promise.all([
        setDoc(
          doc(database, "users", USER_ID),
          profile(USER_ID),
        ),
        setDoc(
          doc(database, "users", OTHER_USER_ID),
          profile(OTHER_USER_ID, {
            officeId: "otra-sede",
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
      ]);
    },
  );
}

async function seedAttendance({
  completed = false,
} = {}) {
  await testEnv.withSecurityRulesDisabled(
    async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "attendances",
          ATTENDANCE_ID,
        ),
        checkedInAttendance({ completed }),
      );
    },
  );
}

async function uploadValidCheckIn() {
  const storage = storageFor(USER_ID);

  await assertSucceeds(
    uploadBytes(
      storageRefFor(storage),
      jpegBytes(),
      metadata(),
    ),
  );
}

async function clearStorageRecursively() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const rootReference = context.storage().ref();

    async function removeContents(reference) {
      const result = await reference.listAll();

      await Promise.all(
        result.prefixes.map((prefix) => removeContents(prefix)),
      );

      await Promise.all(
        result.items.map((item) => item.delete()),
      );
    }

    await removeContents(rootReference);
  });
}

describe(
  "Reglas de seguridad de evidencias fotográficas",
  function () {
    this.timeout(30000);

    before(async () => {
      testEnv = await initializeTestEnvironment({
        projectId: PROJECT_ID,
        firestore: {
          host: "127.0.0.1",
          port: 8080,
          rules: firestoreRules,
        },
        storage: {
          host: "127.0.0.1",
          port: 9199,
          rules: storageRules,
        },
      });
    });

    beforeEach(async () => {
      await clearStorageRecursively();
      await testEnv.clearFirestore();
      await seedProfiles();
    });

    after(async () => {
      if (testEnv != null) {
        await testEnv.cleanup();
      }
    });

    it("01 rechaza carga sin autenticación", async () => {
      const storage = testEnv
        .unauthenticatedContext()
        .storage(BUCKET_URL);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(),
          metadata(),
        ),
      );
    });

    it("02 rechaza trabajador inactivo", async () => {
      const uid = INACTIVE_USER_ID;
      const attendanceId = `${uid}_${WORK_DATE}`;
      const objectPath =
        `attendanceEvidence/${uid}/${attendanceId}/check-in.jpg`;

      const storage = storageFor(uid);

      await assertFails(
        uploadBytes(
          storageRefFor(storage, objectPath),
          jpegBytes(),
          metadata({
            ownerUid: uid,
            attendanceId,
          }),
        ),
      );
    });

    it("03 permite JPEG válido del propietario", async () => {
      await uploadValidCheckIn();
    });

    it("04 rechaza carga en una ruta ajena", async () => {
      const storage = storageFor(OTHER_USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(),
          metadata(),
        ),
      );
    });

    it("05 rechaza contenido que no sea JPEG", async () => {
      const storage = storageFor(USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(),
          {
            ...metadata(),
            contentType: "image/png",
          },
        ),
      );
    });

    it("06 rechaza evidencia mayor de 2 MB", async () => {
      const storage = storageFor(USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(2 * 1024 * 1024 + 1),
          metadata(),
        ),
      );
    });

    it("07 rechaza evidencia vacía", async () => {
      const storage = storageFor(USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          new Uint8Array(0),
          metadata(),
        ),
      );
    });

    it("08 rechaza sede incorrecta", async () => {
      const storage = storageFor(USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(),
          metadata({
            officeId: "otra-sede",
          }),
        ),
      );
    });

    it("09 rechaza nombre no autorizado", async () => {
      const storage = storageFor(USER_ID);

      const objectPath =
        `attendanceEvidence/${USER_ID}/${ATTENDANCE_ID}/selfie.jpg`;

      await assertFails(
        uploadBytes(
          storageRefFor(storage, objectPath),
          jpegBytes(),
          metadata(),
        ),
      );
    });

    it("10 impide sobrescribir una fotografía", async () => {
      const storage = storageFor(USER_ID);

      await uploadValidCheckIn();

      await assertFails(
        uploadBytes(
          storageRefFor(storage),
          jpegBytes(),
          metadata(),
        ),
      );
    });

    it("11 permite lectura al propietario", async () => {
      const storage = storageFor(USER_ID);

      await uploadValidCheckIn();

      await assertSucceeds(
        getMetadata(storageRefFor(storage)),
      );
    });

    it("12 impide lectura a otro trabajador", async () => {
      await uploadValidCheckIn();

      const storage = storageFor(OTHER_USER_ID);

      await assertFails(
        getMetadata(storageRefFor(storage)),
      );
    });

    it("13 permite lectura al administrador", async () => {
      await uploadValidCheckIn();

      const storage = storageFor(ADMIN_ID);

      await assertSucceeds(
        getMetadata(storageRefFor(storage)),
      );
    });

    it("14 impide modificar metadatos", async () => {
      const storage = storageFor(USER_ID);

      await uploadValidCheckIn();

      await assertFails(
        updateMetadata(
          storageRefFor(storage),
          {
            cacheControl: "public,max-age=3600",
          },
        ),
      );
    });

    it("15 permite limpiar entrada no confirmada", async () => {
      const storage = storageFor(USER_ID);

      await uploadValidCheckIn();

      await assertSucceeds(
        deleteObject(storageRefFor(storage)),
      );
    });

    it("16 impide eliminar entrada confirmada", async () => {
      const storage = storageFor(USER_ID);

      await uploadValidCheckIn();
      await seedAttendance();

      await assertFails(
        deleteObject(storageRefFor(storage)),
      );
    });

    it("17 rechaza salida sin entrada abierta", async () => {
      const storage = storageFor(USER_ID);

      await assertFails(
        uploadBytes(
          storageRefFor(storage, CHECK_OUT_PATH),
          jpegBytes(),
          metadata({
            eventName: "check-out",
          }),
        ),
      );
    });

    it("18 permite salida con entrada abierta", async () => {
      const storage = storageFor(USER_ID);

      await seedAttendance();

      await assertSucceeds(
        uploadBytes(
          storageRefFor(storage, CHECK_OUT_PATH),
          jpegBytes(),
          metadata({
            eventName: "check-out",
          }),
        ),
      );
    });

    it("19 permite limpiar salida no confirmada", async () => {
      const storage = storageFor(USER_ID);

      await seedAttendance();

      await assertSucceeds(
        uploadBytes(
          storageRefFor(storage, CHECK_OUT_PATH),
          jpegBytes(),
          metadata({
            eventName: "check-out",
          }),
        ),
      );

      await assertSucceeds(
        deleteObject(
          storageRefFor(storage, CHECK_OUT_PATH),
        ),
      );
    });

    it("20 impide eliminar salida confirmada", async () => {
      const storage = storageFor(USER_ID);

      await seedAttendance();

      await assertSucceeds(
        uploadBytes(
          storageRefFor(storage, CHECK_OUT_PATH),
          jpegBytes(),
          metadata({
            eventName: "check-out",
          }),
        ),
      );

      await seedAttendance({
        completed: true,
      });

      await assertFails(
        deleteObject(
          storageRefFor(storage, CHECK_OUT_PATH),
        ),
      );
    });
  },
);
