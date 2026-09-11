export async function resolve(specifier, context, nextResolve) {
  if (specifier === "firebase-admin" || specifier.startsWith("firebase-admin/")) {
    throw new Error("FIREBASE_ADMIN_IMPORTED_BEFORE_SOURCE_SCAN");
  }
  return nextResolve(specifier, context);
}
