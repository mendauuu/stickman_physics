// lib/game/world_walls.dart
// Four static Box2D bodies forming the screen boundary.
// ONLY imports flame_forge2d — no vector_math conflict possible.

import 'dart:ui' show Canvas;
import 'package:flame_forge2d/flame_forge2d.dart';
import '../constants/game_constants.dart';

class WallBody extends BodyComponent {
  final Vector2 _pos;
  final Vector2 _halfSize;

  WallBody(this._pos, this._halfSize);

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef()
        ..type = BodyType.static
        ..position = _pos,
    );
    final shape = PolygonShape()..setAsBoxXY(_halfSize.x, _halfSize.y);
    body.createFixture(
      FixtureDef(shape)
        ..restitution = kWallRestitution
        ..friction = kWallFriction
        ..density = 0,
    );
    return body;
  }

  @override
  void render(Canvas canvas) {} // invisible walls
}

List<WallBody> buildWalls(Vector2 ws) {
  final w = ws.x, h = ws.y, t = kWallThickness;
  return [
    WallBody(Vector2(w / 2, h + t), Vector2(w / 2 + t, t)), // floor
    WallBody(Vector2(w / 2, -t),    Vector2(w / 2 + t, t)), // ceiling
    WallBody(Vector2(-t, h / 2),    Vector2(t, h / 2 + t)), // left
    WallBody(Vector2(w + t, h / 2), Vector2(t, h / 2 + t)), // right
  ];
}
