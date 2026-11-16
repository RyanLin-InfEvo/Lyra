// SPDX-FileCopyrightText: 2026 Tzu-Ting Lin
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:ui/features/models/playlist.dart';
import 'package:ui/features/models/tag.dart';
import 'package:ui/features/models/track.dart';
import 'package:ui/features/tracks/track_filter_model.dart';

void main() {
  const tracks = [
    Track(
      id: 't1',
      title: 'Blue in Green',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      genre: 'Jazz',
      format: 'FLAC',
    ),
    Track(
      id: 't2',
      title: 'Hotel California',
      artistName: 'Eagles',
      albumTitle: 'Hell Freezes Over',
      genre: 'Rock',
      format: 'ALAC',
    ),
    Track(
      id: 't3',
      title: 'So What',
      artistName: 'Miles Davis',
      albumTitle: 'Kind of Blue',
      genre: 'Jazz',
      format: 'DSD',
    ),
    Track(
      id: 't4',
      title: 'Moonlight',
      artistName: 'London Symphony',
      albumTitle: 'Classical Highlights',
      genre: 'Classical',
      format: 'FLAC',
    ),
  ];

  final tags = [
    const Tag(id: 'tag-a', name: 'tagA', category: 'mood'),
    const Tag(id: 'tag-b', name: 'TagB', category: 'mood'),
    const Tag(id: 'tag-c', name: 'Audiophile', category: 'audio'),
  ];

  const playlists = [
    Playlist(id: 'pl-c', title: 'PlaylistC', trackIds: ['t1', 't2', 't4']),
    Playlist(id: 'pl-other', title: 'Late Night', trackIds: ['t3']),
  ];

  final context = TrackFilterContext.fromLibrary(
    tracks: tracks,
    tags: tags,
    playlists: playlists,
    taggedTrackIdsByTag: {
      'tag-a': {'t1', 't3'},
      'tag-b': {'t2'},
      'tag-c': {'t1', 't2', 't3'},
    },
  );

  group('TrackFilterQuery evaluation', () {
    test('inactive query returns all tracks unfiltered', () {
      const query = TrackFilterQuery();
      expect(query.isActive, isFalse);
      expect(query.apply(tracks, context), hasLength(4));
      expect(query.formatSummaryLabel(context), isNull);
    });

    test(
      'evaluates (Tag isAnyOf [tagA, TagB]) AND (Playlist isAnyOf [PlaylistC])',
      () {
        const query = TrackFilterQuery(
          groups: [
            TrackFilterGroup(
              id: 'g1',
              combinator: TrackFilterCombinator.and,
              rules: [
                TrackFilterRule(
                  id: 'r1',
                  field: TrackFilterField.tag,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['tag-a', 'tag-b'],
                ),
                TrackFilterRule(
                  id: 'r2',
                  field: TrackFilterField.playlist,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['pl-c'],
                ),
              ],
            ),
          ],
        );

        final result = query.apply(tracks, context);
        expect(result.map((t) => t.id), ['t1', 't2']);
        expect(query.activeRuleCount, 2);
        expect(
          query.formatSummaryLabel(context),
          'Tag: (tagA OR TagB) AND Playlist: PlaylistC',
        );
      },
    );

    test('evaluates isAllOf operator on multi-valued tag field', () {
      const query = TrackFilterQuery(
        groups: [
          TrackFilterGroup(
            id: 'g1',
            combinator: TrackFilterCombinator.and,
            rules: [
              TrackFilterRule(
                id: 'r1',
                field: TrackFilterField.tag,
                operator: TrackFilterOperator.isAllOf,
                values: ['tag-a', 'tag-c'],
              ),
            ],
          ),
        ],
      );

      final result = query.apply(tracks, context);
      expect(result.map((t) => t.id), ['t1', 't3']);
    });

    test('evaluates isNoneOf exclusion operator across scalar fields', () {
      const query = TrackFilterQuery(
        groups: [
          TrackFilterGroup(
            id: 'g1',
            combinator: TrackFilterCombinator.and,
            rules: [
              TrackFilterRule(
                id: 'r1',
                field: TrackFilterField.genre,
                operator: TrackFilterOperator.isNoneOf,
                values: ['jazz', 'classical'],
              ),
            ],
          ),
        ],
      );

      final result = query.apply(tracks, context);
      expect(result.map((t) => t.id), ['t2']);
    });

    test(
      'evaluates Match ANY (OR) inside a group and OR across multiple groups',
      () {
        const query = TrackFilterQuery(
          groups: [
            TrackFilterGroup(
              id: 'g1',
              combinator: TrackFilterCombinator.and,
              rules: [
                TrackFilterRule(
                  id: 'r1',
                  field: TrackFilterField.artist,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['Miles Davis'],
                ),
                TrackFilterRule(
                  id: 'r2',
                  field: TrackFilterField.format,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['DSD'],
                ),
              ],
            ),
            TrackFilterGroup(
              id: 'g2',
              combinator: TrackFilterCombinator.or,
              rules: [
                TrackFilterRule(
                  id: 'r3',
                  field: TrackFilterField.genre,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['Classical'],
                ),
                TrackFilterRule(
                  id: 'r4',
                  field: TrackFilterField.format,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['ALAC'],
                ),
              ],
            ),
          ],
        );

        final result = query.apply(tracks, context);
        // Group 1 matches t3 (Miles Davis AND DSD). Group 2 matches t2 (ALAC) and t4 (Classical).
        expect(result.map((t) => t.id), ['t2', 't3', 't4']);
      },
    );

    test(
      'empty incomplete rules inside a group do not mask active matches',
      () {
        const query = TrackFilterQuery(
          groups: [
            TrackFilterGroup(
              id: 'g1',
              combinator: TrackFilterCombinator.and,
              rules: [
                TrackFilterRule(
                  id: 'r1',
                  field: TrackFilterField.format,
                  operator: TrackFilterOperator.isAnyOf,
                  values: ['FLAC'],
                ),
                TrackFilterRule(
                  id: 'r2',
                  field: TrackFilterField.tag,
                  operator: TrackFilterOperator.isAnyOf,
                  values: [],
                ),
              ],
            ),
          ],
        );

        final result = query.apply(tracks, context);
        expect(result.map((t) => t.id), ['t1', 't4']);
      },
    );

    test(
      'TrackFilterQuery.forTags formats single tag summary cleanly and syncs referencedTagIds',
      () {
        final single = TrackFilterQuery.forTags({'tag-c'});
        expect(single.formatSummaryLabel(context), 'Tag: Audiophile');
        expect(single.referencedTagIds, {'tag-c'});

        final multi = TrackFilterQuery.forTags({'tag-a', 'tag-b'});
        expect(multi.formatSummaryLabel(context), 'Tag: (tagA OR TagB)');
        expect(multi.referencedTagIds, {'tag-a', 'tag-b'});
      },
    );

    test(
      'switching rule to single-valued field normalizes isAllOf back to isAnyOf',
      () {
        const rule = TrackFilterRule(
          id: 'r1',
          field: TrackFilterField.tag,
          operator: TrackFilterOperator.isAllOf,
          values: ['tag-a'],
        );
        final switched = rule.copyWith(field: TrackFilterField.artist);
        expect(switched.operator, TrackFilterOperator.isAnyOf);
      },
    );

    test('whitespace-only values are ignored by isActive and matches', () {
      const rule = TrackFilterRule(
        id: 'r-ws',
        field: TrackFilterField.artist,
        operator: TrackFilterOperator.isAnyOf,
        values: ['   ', ''],
      );
      expect(rule.isActive, isFalse);
      expect(rule.matches(tracks.first, context), isTrue);

      const query = TrackFilterQuery(
        groups: [
          TrackFilterGroup(id: 'g-ws', rules: [rule]),
        ],
      );
      expect(query.isActive, isFalse);
      expect(query.apply(tracks, context).length, tracks.length);
    });
  });
}
