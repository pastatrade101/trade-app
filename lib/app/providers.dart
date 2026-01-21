import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/repositories/auth_repository.dart';
import '../core/repositories/user_repository.dart';
import '../core/repositories/signal_repository.dart';
import '../core/repositories/tip_repository.dart';
import '../core/repositories/report_repository.dart';
import '../core/repositories/affiliate_repository.dart';
import '../core/repositories/broker_repository.dart';
import '../core/repositories/highlight_repository.dart';
import '../core/repositories/payment_repository.dart';
import '../core/repositories/product_repository.dart';
import '../core/repositories/revenue_repository.dart';
import '../core/repositories/trading_session_repository.dart';
import '../core/repositories/testimonial_repository.dart';
import '../core/services/storage_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/affiliate_click_service.dart';
import '../core/services/membership_service.dart';
import '../features/admin/services/admin_notification_service.dart';
import '../features/news/data/news_repository.dart';
import '../features/premium/data/global_offer_repository.dart';
import '../features/premium/models/global_offer.dart';
import '../core/models/app_user.dart';
import '../core/models/trading_session_config.dart';
import '../core/models/user_membership.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  return SignalRepository();
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return RevenueRepository();
});

final testimonialRepositoryProvider = Provider<TestimonialRepository>((ref) {
  return TestimonialRepository();
});

final tipRepositoryProvider = Provider<TipRepository>((ref) {
  return TipRepository();
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepository();
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

final affiliateRepositoryProvider = Provider<AffiliateRepository>((ref) {
  return AffiliateRepository(storage: ref.read(storageServiceProvider));
});

final brokerRepositoryProvider = Provider<BrokerRepository>((ref) {
  return BrokerRepository(storage: ref.read(storageServiceProvider));
});

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository();
});

final tradingSessionRepositoryProvider =
    Provider<TradingSessionRepository>((ref) {
  return TradingSessionRepository();
});

final tradingSessionConfigProvider =
    StreamProvider<TradingSessionConfig>((ref) {
  return ref.watch(tradingSessionRepositoryProvider).watchConfig();
});

final affiliateClickServiceProvider = Provider<AffiliateClickService>((ref) {
  return AffiliateClickService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final adminNotificationServiceProvider =
    Provider<AdminNotificationService>((ref) => AdminNotificationService());

final membershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService();
});

final globalOfferRepositoryProvider =
    Provider<GlobalOfferRepository>((ref) => GlobalOfferRepository());

final globalOfferProvider =
    StreamProvider<GlobalOffer?>((ref) => ref.watch(globalOfferRepositoryProvider).watchActiveOffer());

final globalOfferConfigProvider =
    StreamProvider<GlobalOffer?>((ref) => ref.watch(globalOfferRepositoryProvider).watchOfferConfig());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});

final userMembershipProvider = StreamProvider<UserMembership?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(null);
  }
  return ref.watch(membershipServiceProvider).watchMembership(user.uid);
});

final supportTradersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchSupportTraders(limit: 200);
});

final isPremiumActiveProvider = Provider<bool>((ref) {
  final membership = ref.watch(userMembershipProvider).value;
  return ref.watch(membershipServiceProvider).isPremiumActive(membership);
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}
