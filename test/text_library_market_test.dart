import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/text_library/minecraft/market_store.dart';

void main() {
  test('market state round-trips', () {
    const state = MarketState(
      clock: 2400,
      crate: {'bed': 2, 'telescope': 1},
      placed: [
        PlacedPiece(id: 'swing', x: 6, z: 7, rot: 1),
        PlacedPiece(id: 'aquarium', x: -3, z: -12, floor: 1, rot: 3),
      ],
      warned: true,
    );
    final back = MarketState.fromJson(state.toJson());
    expect(back.toJson(), state.toJson());
  });

  test('market state from the page is cleaned up', () {
    final state = MarketState.fromJson({
      'clock': 99999,
      'crate': {'bed': 3.6, 'gramophone': 0, 'Bad Id': 2, 'swing': 500, 7: 1},
      'placed': [
        {'id': 'bed', 'x': 2.4, 'z': -3, 'floor': -2, 'rot': -1},
        {'id': 'bed', 'x': 'far', 'z': 0},
        {'id': 'swing', 'x': 9000, 'z': 0},
        {'x': 1, 'z': 1},
        'nonsense',
      ],
      'warned': 'yes',
    });
    expect(state.clock, MarketState.cycle - 1);
    expect(state.crate, {'bed': 4, 'swing': MarketState.maxStack});
    expect(state.placed, hasLength(1));
    expect(state.placed.single.toJson(), {
      'id': 'bed',
      'x': 2,
      'z': -3,
      'floor': 0,
      'rot': 3,
    });
    expect(state.warned, isFalse);
  });

  test('no more than the most pieces the page keeps', () {
    final state = MarketState.fromJson({
      'placed': [
        for (var i = 0; i < 300; i++)
          {'id': 'candelabra', 'x': i % 100, 'z': i ~/ 100},
      ],
    });
    expect(state.placed, hasLength(MarketState.maxPieces));
  });

  test('nothing saved reads as an empty market', () {
    expect(MarketState.fromJson(null).toJson(), const MarketState().toJson());
  });
}
