// lib/game/story.dart
// "Exam Escape: The Saga of the Last Night" — the story told between fights.
// Ozod fell asleep at 2:59 AM before his Final Exam. At 3:00 he wakes up
// inside the Nightmare University and has six hours (six floors) to reach
// the Grade Reaper before 9:00 AM.

import 'package:flutter/material.dart' show Color;

/// Who is talking in a story panel.
enum Speaker { narrator, ozod, mira, reaper, voice }

class StoryLine {
  final Speaker who;
  final String text;
  final String emoji; // big picture shown above narrator lines
  const StoryLine(this.who, this.text, {this.emoji = ''});

  String get name => switch (who) {
        Speaker.narrator => '',
        Speaker.ozod => 'OZOD',
        Speaker.mira => 'MIRA',
        Speaker.reaper => 'THE GRADE REAPER',
        Speaker.voice => 'A VOICE',
      };

  Color get color => switch (who) {
        Speaker.narrator => const Color(0xFFB0BEC5),
        Speaker.ozod => const Color(0xFF00E5FF),
        Speaker.mira => const Color(0xFFB2EBF2),
        Speaker.reaper => const Color(0xFFFF1744),
        Speaker.voice => const Color(0xFFFF5252),
      };
}

const _n = Speaker.narrator, _o = Speaker.ozod, _m = Speaker.mira, _r = Speaker.reaper, _v = Speaker.voice;

/// Shown once, when a run starts from the very first room.
const List<StoryLine> kPrologue = [
  StoryLine(_n, 'It is 2:59 AM.\nOzod, a first-year student, has one exam left: the Final Exam that decides everything.',
      emoji: '🌙'),
  StoryLine(_n, 'He promised himself he would study all night.\nHis head drops onto his notebook. The lamp flickers.',
      emoji: '📓'),
  StoryLine(_n, 'At exactly 3:00 AM he opens his eyes.\nHe is standing in the university hallway.', emoji: '👁️'),
  StoryLine(_n, 'The walls are cracked. The lights are red.\nEvery clock on every wall shows the same thing: 6 HOURS LEFT.',
      emoji: '⏰'),
  StoryLine(_v,
      '"Every student who sleeps comes to my school. Few wake up.\nReach me before nine… or stay here forever."'),
  StoryLine(_n, 'That voice belongs to the Grade Reaper.', emoji: '💀'),
];

/// Ozod meets Mira in the first hallway.
const List<StoryLine> kMeetMira = [
  StoryLine(_n, 'A pale, glowing girl in an old uniform is waiting by the lockers.', emoji: '👻'),
  StoryLine(_m, 'I fell asleep before my exam… ten years ago. I never woke up.'),
  StoryLine(_m, 'I can\'t fight. But I know this school\'s secrets.'),
  StoryLine(_m, 'Your notes are scattered across every floor. Each page you find brings back what you studied — and makes you stronger.'),
  StoryLine(_m, 'You still have a chance. I didn\'t. Don\'t waste it.'),
];

/// Floor 3: after the Librarian fades away.
const List<StoryLine> kLibraryBook = [
  StoryLine(_n, 'On the Librarian\'s desk lies a heavy book:\nSTUDENTS WHO NEVER WOKE UP.', emoji: '📕'),
  StoryLine(_n, 'Mira turns the pages slowly… and stops.\nHer own name is written there, in faded ink.'),
  StoryLine(_m, '…So that\'s where I went.'),
  StoryLine(_n, 'On the next empty line, someone has already started writing in pencil:\n"OZOD"', emoji: '✏️'),
  StoryLine(_o, 'It\'s only pencil.\nPencil can be erased.'),
];

/// Floor 5 → 6: Mira stops at the final staircase.
const List<StoryLine> kFinalStairs = [
  StoryLine(_n, 'The last staircase. Above it: the Exam Hall.\nMira stops on the first step. She can\'t go any further.', emoji: '🪜'),
  StoryLine(_m, 'He owns me. I can\'t go up there.'),
  StoryLine(_n, 'She presses something into Ozod\'s hand: the last page of his notes.', emoji: '📄'),
  StoryLine(_m, 'If you beat him… maybe we all wake up.'),
];

/// The Reaper's hood falls (phase 3).
const List<StoryLine> kUnmasked = [
  StoryLine(_n, 'The Grade Reaper takes off his hood.', emoji: '💀'),
  StoryLine(_n, 'Under it is a face Ozod knows better than any other.\nHis own.'),
  StoryLine(_r, 'I am not your enemy. I am your fear.\nYou can\'t kill me… you can only stop running.'),
  StoryLine(_m, '(far away, from the staircase)\nOzod… stop running. Stand still.'),
];

/// After the walk into the light.
const List<StoryLine> kEnding = [
  StoryLine(_n, 'The Reaper shrinks smaller, and smaller…\nuntil he is just a tiny red pen on the floor.', emoji: '🖊️'),
  StoryLine(_n, 'The alarm SCREAMS.', emoji: '⏰'),
  StoryLine(_n, 'Ozod wakes up at his desk, notebook stuck to his face.\n8:59 AM.\nHe runs.', emoji: '🏃'),
  StoryLine(_n, 'He reaches the Exam Hall just as the doors close.\nHe sits down… and he remembers everything.', emoji: '🚪'),
  StoryLine(_n, 'On the last page of his exam, in the corner, there is a tiny drawing of a reaper.\nIt is smiling.', emoji: '💀'),
  StoryLine(_n, 'Across the hall, a girl he has never seen before lifts her head from a desk, as if waking from a very long sleep.'),
  StoryLine(_n, 'She looks at him and nods.\nIt\'s Mira.', emoji: '👋'),
];

/// Shown small on the victory screen: the sequel hook.
const String kPostCredit = 'A new student falls asleep in the library. Somewhere, a clock starts ticking… 3:00 AM.';

/// Notes Ozod says out loud as he picks up each Lost Note (by floor).
const List<String> kNoteMemories = [
  'I remember… leave ten minutes early. Never be late again.',
  'I remember… show every step, and the answer follows.',
  'I remember… in silence, I can finally focus.',
  'I remember… rest is not weakness. Sleep is how you learn.',
  'I remember… do it now. Not tomorrow.',
  'I remember… I studied. I am ready. I am not afraid.',
];
