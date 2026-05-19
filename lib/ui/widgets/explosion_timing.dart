/// Shared timing constants for chain-explosion playback. The board view
/// uses these to schedule cell-reveal delays; the explosion overlay uses
/// them to schedule each ring's appearance, so the two stay in lockstep.
class ExplosionTiming {
  /// Delay between successive mines detonating in the same chain.
  static const int msPerCenter = 150;

  /// Additional delay per cell of Chebyshev distance from the nearest
  /// detonation center, for cells revealed by the chain.
  static const int msPerDistance = 30;

  /// Maximum distance considered for the per-cell stagger. Cells revealed
  /// far from any center (via flood-fill of a 0-cell) won't lag longer than
  /// this, otherwise they'd appear seconds after the explosion ended.
  static const int maxDistance = 3;

  /// Duration of a single ring's expand-and-fade animation.
  static const int ringDurationMs = 380;
}
