#!/usr/bin/env node

const fs = require('fs');
const admin = require('firebase-admin');

function printUsage() {
  console.error(
    'Usage: node scripts/update-vehicle-location.js --id VEHICLE_ID --location "New Hub Name"',
  );
  console.error(
    'Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON file path first.',
  );
}

function readArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1) {
    return null;
  }
  return process.argv[index + 1] ?? null;
}

function requireCredentialsPath() {
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialsPath) {
    throw new Error(
      'GOOGLE_APPLICATION_CREDENTIALS is not set. Point it to a Firebase service account JSON file.',
    );
  }
  if (!fs.existsSync(credentialsPath)) {
    throw new Error(`Service account file not found: ${credentialsPath}`);
  }
}

async function main() {
  const vehicleId = readArg('--id');
  const nextLocation = readArg('--location');

  if (!vehicleId || !nextLocation) {
    printUsage();
    process.exitCode = 1;
    return;
  }

  requireCredentialsPath();

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  const firestore = admin.firestore();
  const vehicleRef = firestore.collection('vehicles').doc(vehicleId);
  const snapshot = await vehicleRef.get();

  if (!snapshot.exists) {
    throw new Error(`Vehicle not found: ${vehicleId}`);
  }

  await vehicleRef.set(
    {
      location: nextLocation,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`Updated ${vehicleId} location to "${nextLocation}"`);
}

main().catch((error) => {
  console.error(error.message ?? error);
  process.exitCode = 1;
});
