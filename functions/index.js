const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require("googleapis");

admin.initializeApp();

// You need to set this up using a Service Account from Google Cloud Console
// with access to the Google Play Developer API.
// For now, we stub the actual API call and assume valid if a token is provided.
// In a production environment, you would use google.androidpublisher('v3') 
// to verify the purchaseToken against the productId and packageName.

exports.verifyPurchase = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { purchaseToken, productId, source } = data;
  if (!purchaseToken) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a purchaseToken."
    );
  }

  const uid = context.auth.uid;
  let isValid = false;
  let expiryDate = null;

  try {
    if (source === "play_store") {
      // TODO: Replace this stub with actual Google Play Developer API validation
      // using google.auth.GoogleAuth and google.androidpublisher('v3').purchases.subscriptions.get
      
      // STUB: Assume valid if a token is passed (for demonstration)
      // Normally you would check the subscription state here.
      isValid = true;
      expiryDate = new Date();
      expiryDate.setFullYear(expiryDate.getFullYear() + 1); // Stub: 1 year expiry
    } else if (source === "app_store") {
      // TODO: Apple verification logic
      isValid = true;
    }

    if (isValid) {
      // Update the user's subscription document securely
      const subRef = admin.firestore().collection("users").doc(uid).collection("subscription").doc("status");
      await subRef.set({
        isSubscribed: true,
        productId: productId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiryDate: expiryDate, // Optional: if you track expiry
      }, { merge: true });

      return { success: true, isSubscribed: true };
    } else {
      return { success: false, isSubscribed: false, error: "Invalid receipt" };
    }
  } catch (error) {
    console.error("Verification error:", error);
    throw new functions.https.HttpsError("internal", "Verification failed");
  }
});

exports.incrementQuoteCount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const uid = context.auth.uid;
  const subRef = admin.firestore().collection("users").doc(uid).collection("subscription").doc("status");

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const subDoc = await transaction.get(subRef);
      
      if (!subDoc.exists) {
        transaction.set(subRef, { freeQuotesUsed: 1 });
      } else {
        const currentCount = subDoc.data().freeQuotesUsed || 0;
        transaction.update(subRef, { freeQuotesUsed: currentCount + 1 });
      }
    });

    return { success: true };
  } catch (error) {
    console.error("Increment error:", error);
    throw new functions.https.HttpsError("internal", "Failed to increment quote count");
  }
});
