import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// A list loaded page by page (ST-10): what is loaded so far, and how loading the next page went.
class PagedList<T> {
  const PagedList({required this.items, this.next, this.loadingMore = false, this.moreError = false});

  final List<T> items;
  final String? next;
  final bool loadingMore;

  /// Loading the next page failed; the list stays and a retry is offered at the end.
  final bool moreError;

  bool get hasMore => next != null;

  PagedList<T> copyWith({List<T>? items, String? next, bool clearNext = false, bool? loadingMore, bool? moreError}) =>
      PagedList(items: items ?? this.items, next: clearNext ? null : (next ?? this.next), loadingMore: loadingMore ?? this.loadingMore, moreError: moreError ?? this.moreError);
}

abstract class PagedNotifier<T> extends AsyncNotifier<PagedList<T>> {
  Future<Paged<T>> fetch(ApiClient api, String? cursor);

  @override
  Future<PagedList<T>> build() async {
    final page = await fetch(ref.read(apiProvider), null);
    return PagedList(items: page.items, next: page.next);
  }

  /// Next page; safe to call repeatedly (ignored while loading or at the end).
  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, moreError: false));
    try {
      final page = await fetch(ref.read(apiProvider), cur.next);
      state = AsyncData(PagedList(items: [...cur.items, ...page.items], next: page.next));
    } catch (_) {
      state = AsyncData(cur.copyWith(loadingMore: false, moreError: true));
    }
  }
}

class RideHistoryNotifier extends PagedNotifier<RideHistoryItem> {
  @override
  Future<Paged<RideHistoryItem>> fetch(ApiClient api, String? cursor) => api.rideHistory(cursor: cursor);

  /// ST-11: rate a finished ride; the row updates without reloading the list.
  Future<void> rate(String id, int stars, String? comment) async {
    await ref.read(apiProvider).rateRide(id, stars, comment: comment);
    final cur = state.value;
    if (cur != null) state = AsyncData(cur.copyWith(items: [for (final r in cur.items) r.id == id ? r.rated(stars) : r]));
  }
}

class PaymentHistoryNotifier extends PagedNotifier<PaymentItem> {
  @override
  Future<Paged<PaymentItem>> fetch(ApiClient api, String? cursor) => api.paymentHistory(cursor: cursor);
}

final rideHistoryProvider = AsyncNotifierProvider.autoDispose<RideHistoryNotifier, PagedList<RideHistoryItem>>(RideHistoryNotifier.new);
final paymentHistoryProvider = AsyncNotifierProvider.autoDispose<PaymentHistoryNotifier, PagedList<PaymentItem>>(PaymentHistoryNotifier.new);

/// TO-11: office announcements shown as banners on Home.
final announcementsProvider = FutureProvider.autoDispose<List<Announcement>>((ref) => ref.watch(apiProvider).activeAnnouncements());
