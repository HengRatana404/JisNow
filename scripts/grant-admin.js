#!/usr/bin/env node

const fs = require('fs');
const admin = require('firebase-admin');

function printUsage() {
  console.error(
    'Usage: node scripts/grant-admin.js --email user@example.com | --uid FIREBASE_UID',
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

async function resolveUser(auth, email, uid) {
  if (uid) {
    return auth.getUser(uid);
  }
  return auth.getUserByEmail(email);
}

async function main() {
  const email = readArg('--email');
  const uid = readArg('--uid');

  if ((!email && !uid) || (email && uid)) {
    printUsage();
    process.exitCode = 1;
    return;
  }

  requireCredentialsPath();

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  const auth = admin.auth();
  const firestore = admin.firestore();
  const user = await resolveUser(auth, email, uid);

  await auth.setCustomUserClaims(user.uid, {
    ...(user.customClaims ?? {}),
    admin: true,
  });

  await firestore.collection('users').doc(user.uid).set(
    {
      email: user.email ?? email ?? '',
      isAdmin: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`Admin access granted for ${user.email ?? user.uid}`);
}

main().catch((error) => {
  console.error(error.message ?? error);
  process.exitCode = 1;
});
