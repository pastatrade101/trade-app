import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_investment_flutter/core/models/app_user.dart';
import 'package:stock_investment_flutter/core/models/signal.dart';
import 'package:stock_investment_flutter/core/models/stats_summary.dart';
import 'package:stock_investment_flutter/core/models/validator_stats.dart';
import 'package:stock_investment_flutter/core/models/vote_aggregate.dart';

void main() {
  test('AppUser serialization round-trip', () {
    final user = AppUser(
      uid: 'uid1',
      displayName: 'Trader Joe',
      username: 'traderjoe',
      usernameLower: 'traderjoe',
      avatarUrl: '',
      email: 'trader@example.com',
      bio: 'Bio',
      country: 'UK',
      sessions: const ['London'],
      instruments: const ['XAUUSD'],
      strategyStyle: 'Scalper',
      experienceLevel: 'Beginner',
      role: 'member',
      traderStatus: 'none',
      rejectReason: null,
      socials: const {},
      socialLinks: const {},
      yearsExperience: 2,
      isVerified: false,
      verifiedAt: null,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      statsSummary: StatsSummary.empty(),
      validatorStats: ValidatorStats.empty(),
      followerCount: 1,
      followingCount: 2,
      isBanned: false,
    );

    final json = user.toJson();
    final restored = AppUser.fromJson('uid1', json);

    expect(restored.username, user.username);
    expect(restored.sessions, user.sessions);
    expect(restored.statsSummary.winRate30, user.statsSummary.winRate30);
  });

  test('Signal serialization round-trip', () {
    final signal = Signal(
      id: 'signal1',
      uid: 'uid1',
      posterNameSnapshot: 'Trader',
      posterVerifiedSnapshot: true,
      pair: 'XAUUSD',
      direction: 'Buy',
      entryType: 'Market',
      entryPrice: 1920.5,
      entryRange: null,
      stopLoss: 1900,
      tp1: 1950,
      tp2: 1970,
      premiumOnly: false,
      riskLevel: 'Medium',
      session: 'London',
      validUntil: DateTime(2024, 1, 2),
      reasoning: 'Test',
      tags: const ['trend'],
      imageUrl: 'http://image',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      status: 'open',
      voteAgg: VoteAggregate.empty(),
      resolvedBy: null,
      resolvedAt: null,
      finalOutcome: null,
      likesCount: 0,
      dislikesCount: 0,
    );

    final json = signal.toJson();
    json['createdAt'] = Timestamp.fromDate(DateTime(2024, 1, 1));
    json['updatedAt'] = Timestamp.fromDate(DateTime(2024, 1, 1));
    json['validUntil'] = Timestamp.fromDate(DateTime(2024, 1, 2));

    final restored = Signal.fromJson('signal1', json);

    expect(restored.pair, signal.pair);
    expect(restored.entryPrice, signal.entryPrice);
    expect(restored.voteAgg.totalVotes, 0);
  });
}
