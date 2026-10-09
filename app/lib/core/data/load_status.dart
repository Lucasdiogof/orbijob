/// Where a screen's data is. `failure` carries a [DataFailureKind] alongside, so the UI can tell "no data"
/// (ready + empty) from "could not load" (failure) from "must sign in" (failure + needsSignIn).
enum LoadStatus { loading, ready, failure }
