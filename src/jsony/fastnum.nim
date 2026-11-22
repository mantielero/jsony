## Fast number parsing helpers (Phase 3). Opt-out via -d:jsonyNoFastInt / -d:jsonyNoFastFloat.
## Fast paths must fall back to original behavior on any ambiguity.

const pow10f64* = [
  1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10,
  1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22
]
