const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const firestore = admin.firestore();
const activeBookingStatuses = ['pending', 'confirmed'];

function normalizeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function sanitizeFirestoreValue(value) {
  if (Array.isArray(value)) {
    return value
      .filter((item) => item !== undefined)
      .map((item) => sanitizeFirestoreValue(item));
  }
  if (value && typeof value === 'object' && !(value instanceof Date) && !(value instanceof admin.firestore.Timestamp)) {
    return Object.fromEntries(
      Object.entries(value)
        .filter(([, nestedValue]) => nestedValue !== undefined)
        .map(([key, nestedValue]) => [key, sanitizeFirestoreValue(nestedValue)]),
    );
  }
  return value;
}

function parseStartDate(rawValue) {
  const normalized = normalizeString(rawValue);
  const parsed = new Date(normalized);
  if (!normalized || Number.isNaN(parsed.getTime())) {
    throw new HttpsError('invalid-argument', 'A valid booking start date is required.');
  }
  return parsed;
}

function parseQuantity(rawValue) {
  if (!Number.isInteger(rawValue) || rawValue <= 0) {
    throw new HttpsError('invalid-argument', 'Booking quantity must be a positive whole number.');
  }
  return rawValue;
}

function splitPickupHubs(location) {
  return normalizeString(location)
    .split(/[\n,]+/)
    .map((hub) => hub.trim())
    .filter(Boolean);
}

function computeEndDate(startDate, unit, quantity) {
  switch (unit) {
    case 'hour':
      return new Date(startDate.getTime() + quantity * 60 * 60 * 1000);
    case 'day':
      return new Date(startDate.getTime() + quantity * 24 * 60 * 60 * 1000);
    case 'week':
      return new Date(startDate.getTime() + quantity * 7 * 24 * 60 * 60 * 1000);
    case 'month':
      return new Date(
        Date.UTC(
          startDate.getUTCFullYear(),
          startDate.getUTCMonth() + quantity,
          startDate.getUTCDate(),
          startDate.getUTCHours(),
          startDate.getUTCMinutes(),
          startDate.getUTCSeconds(),
          startDate.getUTCMilliseconds(),
        ),
      );
    default:
      throw new HttpsError('invalid-argument', 'Unsupported rental unit.');
  }
}

function rateForUnit(vehicleData, unit) {
  const rates = Array.isArray(vehicleData.rates) ? vehicleData.rates : [];
  const rate = rates.find((entry) => entry && entry.unit === unit);
  if (!rate || typeof rate.price !== 'number') {
    throw new HttpsError('failed-precondition', 'This rental rate is no longer available.');
  }
  return rate.price;
}

function deliveryFeeForVehicleType(vehicleType, fulfillmentMethod) {
  if (fulfillmentMethod === 'pickup') {
    return 0;
  }
  switch (vehicleType) {
    case 'car':
      return 3;
    case 'motorbike':
      return 1.5;
    case 'bicycle':
      return 1;
    default:
      throw new HttpsError('failed-precondition', 'This vehicle type cannot be delivered right now.');
  }
}

function bookingRangesOverlap(existingStart, existingEnd, requestedStart, requestedEnd) {
  return requestedStart < existingEnd && requestedEnd > existingStart;
}

function inventoryCountFromVehicle(vehicleData) {
  const rawValue = vehicleData.inventoryCount;
  if (!Number.isInteger(rawValue) || rawValue < 1) {
    return 1;
  }
  return rawValue;
}

function toDate(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new HttpsError('failed-precondition', 'An existing booking has an invalid date.');
  }
  return parsed;
}

function createNotificationPayload({
  recipientUserId = null,
  recipientRole = null,
  title,
  body,
  imageUrl = null,
  bookingId = null,
}) {
  return {
    recipientUserId,
    recipientRole,
    title,
    body,
    imageUrl,
    bookingId,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function createBookingForAuthenticatedUser({ auth, data }) {
  const vehicleId = normalizeString(data.vehicleId);
  const unit = normalizeString(data.unit);
  const fulfillmentMethod = normalizeString(data.fulfillmentMethod);
  const pickupHub = normalizeString(data.pickupHub);
  const deliveryAddress = normalizeString(data.deliveryAddress);
  const deliveryNotes = normalizeString(data.deliveryNotes);
  const quantity = parseQuantity(data.quantity);
  const startDate = parseStartDate(data.startDate);

  if (!vehicleId) {
    throw new HttpsError('invalid-argument', 'A vehicle is required.');
  }
  if (!['hour', 'day', 'week', 'month'].includes(unit)) {
    throw new HttpsError('invalid-argument', 'A valid rental unit is required.');
  }
  if (!['pickup', 'delivery'].includes(fulfillmentMethod)) {
    throw new HttpsError('invalid-argument', 'A valid fulfillment method is required.');
  }
  if (fulfillmentMethod === 'delivery' && !deliveryAddress) {
    throw new HttpsError('invalid-argument', 'A delivery address is required for delivery bookings.');
  }

  const userRef = firestore.collection('users').doc(auth.uid);
  const vehicleRef = firestore.collection('vehicles').doc(vehicleId);
  const bookingRef = firestore.collection('bookings').doc();
  const notificationRef = firestore.collection('notifications').doc();

  try {
    const result = await firestore.runTransaction(async (transaction) => {
      const [userSnapshot, vehicleSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(vehicleRef),
      ]);

      if (!userSnapshot.exists) {
        throw new HttpsError('failed-precondition', 'Complete your profile before booking.');
      }
      if (!vehicleSnapshot.exists) {
        throw new HttpsError('failed-precondition', 'This vehicle is no longer available.');
      }

      const profile = userSnapshot.data() || {};
      const vehicleData = vehicleSnapshot.data() || {};

      if (profile.isAdmin === true) {
        throw new HttpsError('permission-denied', 'Admin accounts cannot create bookings.');
      }

      const availableNow = vehicleData.availableNow !== false;
      if (!availableNow) {
        throw new HttpsError('failed-precondition', 'This vehicle is currently unavailable.');
      }

      const pickupHubs = splitPickupHubs(vehicleData.location);
      const defaultPickupHub = pickupHubs[0] || normalizeString(vehicleData.location);
      const resolvedPickupHub = pickupHub || defaultPickupHub;
      if (!resolvedPickupHub) {
        throw new HttpsError('failed-precondition', 'This vehicle does not have a valid pickup hub.');
      }
      if (pickupHubs.length > 0 && !pickupHubs.includes(resolvedPickupHub)) {
        throw new HttpsError('invalid-argument', 'Select a valid pickup hub.');
      }

      const endDate = computeEndDate(startDate, unit, quantity);
      const rentalPrice = rateForUnit(vehicleData, unit) * quantity;
      const deliveryFee = deliveryFeeForVehicleType(vehicleData.type, fulfillmentMethod);
      const totalPrice = rentalPrice + deliveryFee;
      const inventoryCount = inventoryCountFromVehicle(vehicleData);

      const conflictingQuery = firestore
        .collection('bookings')
        .where('vehicle.id', '==', vehicleId)
        .where('status', 'in', activeBookingStatuses);
      const conflictingSnapshots = await transaction.get(conflictingQuery);

      const overlappingReservationCount = conflictingSnapshots.docs.filter((doc) => {
        const existing = doc.data();
        return bookingRangesOverlap(
          toDate(existing.startDate),
          toDate(existing.endDate),
          startDate,
          endDate,
        );
      }).length;

      if (overlappingReservationCount >= inventoryCount) {
        throw new HttpsError(
          'already-exists',
          `All ${inventoryCount} units of this vehicle are already booked for the selected time.`,
        );
      }

      const firstName = normalizeString(profile.firstName);
      const lastName = normalizeString(profile.lastName);
      const displayName = `${firstName} ${lastName}`.trim() || normalizeString(auth.token.name);
      const bookingPayload = sanitizeFirestoreValue({
        userId: auth.uid,
        vehicle: {
          ...vehicleData,
          id: vehicleId,
        },
        unit,
        quantity,
        startDate: admin.firestore.Timestamp.fromDate(startDate),
        endDate: admin.firestore.Timestamp.fromDate(endDate),
        status: 'pending',
        fulfillmentMethod,
        pickupHub: resolvedPickupHub,
        deliveryAddress: fulfillmentMethod === 'delivery' ? deliveryAddress : null,
        deliveryNotes: fulfillmentMethod === 'delivery' ? deliveryNotes : null,
        deliveryFee,
        totalPrice,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        cancellationSource: null,
        account: {
          userId: auth.uid,
          displayName,
          firstName,
          lastName,
          email: normalizeString(profile.email) || normalizeString(auth.token.email),
          phoneNumber: normalizeString(profile.phoneNumber),
          photoUrl: profile.photoUrl || null,
          providerIds: Array.isArray(profile.providerIds) ? profile.providerIds : [],
        },
      });

      transaction.create(bookingRef, bookingPayload);
      transaction.create(
        notificationRef,
        sanitizeFirestoreValue(
          createNotificationPayload({
            recipientRole: 'admin',
            title: 'New booking request',
            body: `${displayName || 'A customer'} requested ${normalizeString(vehicleData.name)}.`,
            imageUrl: normalizeString(vehicleData.imageUrl) || null,
            bookingId: bookingRef.id,
          }),
        ),
      );

      return {
        bookingId: bookingRef.id,
        totalPrice,
        deliveryFee,
        endDate: endDate.toISOString(),
      };
    });

    return result;
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error('createBooking failed', error);
    throw new HttpsError('internal', 'Could not create the booking right now.');
  }
}

function errorStatusCode(error) {
  switch (error?.code) {
    case 'invalid-argument':
      return 400;
    case 'unauthenticated':
      return 401;
    case 'permission-denied':
      return 403;
    case 'not-found':
      return 404;
    case 'already-exists':
      return 409;
    case 'failed-precondition':
      return 412;
    default:
      return 500;
  }
}

function extractBearerToken(headerValue) {
  const normalized = normalizeString(headerValue);
  if (!normalized.toLowerCase().startsWith('bearer ')) {
    return '';
  }
  return normalized.substring(7).trim();
}

exports.createBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in to book a vehicle.');
  }

  return createBookingForAuthenticatedUser({
    auth: request.auth,
    data: request.data || {},
  });
});

exports.createBookingHttp = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: { code: 'method-not-allowed', message: 'Use POST for this endpoint.' } });
    return;
  }

  try {
    const bearerToken = extractBearerToken(req.headers.authorization);
    if (!bearerToken) {
      throw new HttpsError('unauthenticated', 'You must be signed in to book a vehicle.');
    }

    const decodedToken = await admin.auth().verifyIdToken(bearerToken);
    const result = await createBookingForAuthenticatedUser({
      auth: {
        uid: decodedToken.uid,
        token: decodedToken,
      },
      data: req.body || {},
    });

    res.status(200).json(result);
  } catch (error) {
    if (error instanceof HttpsError) {
      res.status(errorStatusCode(error)).json({
        error: {
          code: error.code,
          message: error.message,
        },
      });
      return;
    }

    logger.error('createBookingHttp failed', error);
    res.status(500).json({
      error: {
        code: 'internal',
        message: 'Could not create the booking right now.',
      },
    });
  }
});

exports.notifyAdminOnCustomerCancellation = onDocumentUpdated('bookings/{bookingId}', async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();

  if (!beforeData || !afterData) {
    return;
  }

  const statusChanged = beforeData.status !== afterData.status;
  const sourceChanged = beforeData.cancellationSource !== afterData.cancellationSource;
  const cancelledByCustomer =
    afterData.status === 'cancelled' && afterData.cancellationSource === 'customer';

  if (!cancelledByCustomer || (!statusChanged && !sourceChanged)) {
    return;
  }

  const bookingId = event.params.bookingId;
  const customerName =
    normalizeString(afterData.account?.displayName) ||
    normalizeString(afterData.account?.firstName) ||
    'A customer';
  const vehicleName = normalizeString(afterData.vehicle?.name) || 'a vehicle';
  const imageUrl = normalizeString(afterData.vehicle?.imageUrl) || null;

  await firestore.collection('notifications').add(
    createNotificationPayload({
      recipientRole: 'admin',
      title: 'Customer cancellation',
      body: `${customerName} cancelled ${vehicleName}.`,
      imageUrl,
      bookingId,
    }),
  );
});
