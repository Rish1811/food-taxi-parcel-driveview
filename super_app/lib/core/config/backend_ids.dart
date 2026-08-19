/// Identifiers for the backends the app talks to.
///
/// Today every module resolves to [k9] — one merged Express app at
/// `k9.appzeto.com` serving `/api/v1/food/*` and `/api/v1/taxi/*` from a shared
/// `src/core` (one users collection, one access+refresh JWT pair).
///
/// The indirection exists so that a second host — a transitional split, a
/// regional deployment, a service extracted later — becomes a config change
/// rather than a refactor: `AppModule.endpointId` selects the client, and
/// `apiClientProvider` is keyed by it.
class BackendIds {
  const BackendIds._();

  /// The merged k9 backend. Every module points here.
  static const String k9 = 'k9';
}
