import 'dart:io';

import 'package:luma_sync_server/ai_usage_store.dart';
import 'package:luma_sync_server/chat_store.dart';
import 'package:luma_sync_server/family_store.dart';
import 'package:luma_sync_server/recipe_store.dart';
import 'package:luma_sync_server/subway_store.dart';
import 'package:test/test.dart';

/// Each store's `deleteUser` is what account deletion relies on to leave
/// nothing of the account behind. These pin what goes and what stays for the
/// people the deleted user shared things with.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_account_deletion_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  FamilySharedEvent event(String id, String familyId, String author,
          {List<String> audience = const []}) =>
      FamilySharedEvent(
        id: id,
        familyId: familyId,
        authorUserId: author,
        title: id,
        startMs: 0,
        endMs: 1,
        allDay: false,
        color: 0,
        recurrence: 'none',
        visibility: audience.isEmpty ? 'all' : 'subset',
        visibleMemberUserIds: audience,
        createdAtMs: 0,
        updatedAtMs: 0,
      );

  FamilyMember member(String familyId, String userId, String role) =>
      FamilyMember(
          familyId: familyId, userId: userId, role: role, joinedAtMs: 0);

  group('family', () {
    test('an owned family goes entirely', () async {
      final store = await FamilyStore.open(dir.path);
      store.familiesById['f1'] = Family(
          id: 'f1', name: 'Home', ownerUserId: 'gone', createdAtMs: 0);
      store.membersByFamilyId['f1'] = {
        'gone': member('f1', 'gone', 'owner'),
        'stay': member('f1', 'stay', 'member'),
      };
      store.familyIdByUserId
        ..['gone'] = 'f1'
        ..['stay'] = 'f1';
      store.sharedEventsByFamilyId['f1'] = {'e': event('e', 'f1', 'stay')};

      await store.deleteUser('gone', 'Gone@Example.com');

      final reopened = await FamilyStore.open(dir.path);
      expect(reopened.familiesById, isEmpty);
      expect(reopened.familyIdByUserId, isEmpty);
      expect(reopened.sharedEventsByFamilyId, isEmpty);
    });

    test('in someone else\'s family only the member\'s traces go', () async {
      final store = await FamilyStore.open(dir.path);
      store.familiesById['f1'] = Family(
          id: 'f1', name: 'Home', ownerUserId: 'owner', createdAtMs: 0);
      store.membersByFamilyId['f1'] = {
        'owner': member('f1', 'owner', 'owner'),
        'gone': member('f1', 'gone', 'member'),
      };
      store.familyIdByUserId
        ..['owner'] = 'f1'
        ..['gone'] = 'f1';
      store.sharedEventsByFamilyId['f1'] = {
        'mine': event('mine', 'f1', 'gone'),
        'theirs': event('theirs', 'f1', 'owner', audience: ['owner', 'gone']),
      };
      store.invitesById['i1'] = FamilyInvite(
          id: 'i1',
          familyId: 'f1',
          inviteeEmail: 'gone@example.com',
          invitedByUserId: 'owner',
          createdAtMs: 0,
          expiresAtMs: 1 << 50);

      await store.deleteUser('gone', 'gone@example.com');

      final reopened = await FamilyStore.open(dir.path);
      expect(reopened.familiesById.keys, ['f1']);
      expect(reopened.membersOf('f1').map((m) => m.userId), ['owner']);
      expect(reopened.familyIdByUserId.containsKey('gone'), isFalse);
      final events = reopened.sharedEventsByFamilyId['f1']!;
      expect(events.keys, ['theirs']);
      expect(events['theirs']!.visibleMemberUserIds, ['owner']);
      expect(reopened.invitesById, isEmpty);
    });
  });

  test('chat drops the key, invites and every conversation', () async {
    final store = await ChatStore.open(dir.path);
    store.publicKeyByUserId
      ..['gone'] = 'k1'
      ..['stay'] = 'k2';
    store.conversationsById['c1'] = ChatConversation(
        id: 'c1', userAId: 'gone', userBId: 'stay', createdAtMs: 0);
    store.conversationsById['c2'] = ChatConversation(
        id: 'c2', userAId: 'stay', userBId: 'other', createdAtMs: 0);
    store.messagesByConversationId['c1'] = [
      ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          senderUserId: 'stay',
          createdAtMs: 0,
          blobForRecipient: 'x',
          blobForSender: 'y'),
    ];
    store.invitesById['i1'] = ChatInvite(
        id: 'i1',
        fromUserId: 'stay',
        toEmail: 'gone@example.com',
        createdAtMs: 0,
        expiresAtMs: 1 << 50);

    await store.deleteUser('gone', 'gone@example.com');

    final reopened = await ChatStore.open(dir.path);
    expect(reopened.publicKeyByUserId.keys, ['stay']);
    expect(reopened.conversationsById.keys, ['c2']);
    expect(reopened.messagesByConversationId, isEmpty);
    expect(reopened.invitesById, isEmpty);
  });

  test('recipes drop the user\'s recipes, reviews and photos', () async {
    final store = await RecipeStore.open(dir.path);
    PublicRecipe recipe(String id, String author, String? photo) =>
        PublicRecipe(
          id: id,
          authorId: author,
          authorEmail: '$author@example.com',
          title: id,
          description: null,
          category: 'Other',
          servings: 2,
          prepMinutes: 0,
          cookMinutes: 0,
          ingredients: '[]',
          steps: '[]',
          createdAtMs: 0,
          photoId: photo,
        );
    RecipeReview review(String id, String recipeId, String user,
            String? photo) =>
        RecipeReview(
          id: id,
          recipeId: recipeId,
          userId: user,
          userEmail: '$user@example.com',
          rating: 5,
          text: 'ok',
          createdAtMs: 0,
          photoId: photo,
        );

    store.recipesById['r1'] = recipe('r1', 'gone', 'p1');
    store.recipesById['r2'] = recipe('r2', 'stay', null);
    store.reviewsByRecipeId['r1'] = [review('v1', 'r1', 'stay', 'p2')];
    store.reviewsByRecipeId['r2'] = [
      review('v2', 'r2', 'gone', 'p3'),
      review('v3', 'r2', 'other', null),
    ];
    for (final p in ['p1', 'p2', 'p3']) {
      await store.writeMedia(p, [1, 2, 3]);
    }

    await store.deleteUser('gone');

    final reopened = await RecipeStore.open(dir.path);
    expect(reopened.recipesById.keys, ['r2']);
    expect(reopened.reviewsFor('r1'), isEmpty);
    expect(reopened.reviewsFor('r2').map((r) => r.id), ['v3']);
    for (final p in ['p1', 'p2', 'p3']) {
      expect(await reopened.readMedia(p), isNull);
    }
  });

  test('subway drops owned rooms and leaves the others', () async {
    final store = await SubwayStore.open(dir.path);
    store.roomsByCode['OWNED1'] = SubwayRoom(
        code: 'OWNED1',
        ownerId: 'gone',
        createdAtMs: 0,
        memberIds: {'gone', 'stay'});
    store.roomsByCode['JOINED'] = SubwayRoom(
        code: 'JOINED',
        ownerId: 'stay',
        createdAtMs: 0,
        memberIds: {'stay', 'gone'},
        clockHolderId: 'gone',
        clockLeaseExpiresAtMs: 1 << 50);
    await store.writeState('OWNED1', '{}');

    await store.deleteUser('gone');

    final reopened = await SubwayStore.open(dir.path);
    expect(reopened.roomsByCode.keys, ['JOINED']);
    final joined = reopened.roomsByCode['JOINED']!;
    expect(joined.memberIds, {'stay'});
    expect(joined.clockHolderId, isNull);
    expect(await reopened.readState('OWNED1'), isNull);
  });

  test('AI usage forgets the user', () async {
    final store = await AiUsageStore.open(dir.path);
    await store.recordSupportMessage('gone');
    await store.recordSupportMessage('stay');

    await store.deleteUser('gone');

    final reopened = await AiUsageStore.open(dir.path);
    expect(reopened.supportMessagesUsed('gone'), 0);
    expect(reopened.supportMessagesUsed('stay'), 1);
  });
}
