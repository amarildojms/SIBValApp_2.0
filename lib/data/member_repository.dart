import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member.dart';

/// Espelha app/src/main/java/com/sibval/app/data/repository/MemberRepository.kt.
class MemberRepository {
  MemberRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<Member>> getAll() async {
    final snapshot = await _firestore.collection('members').orderBy('name').get();
    return snapshot.docs.map(Member.fromFirestore).toList();
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(FirebaseFirestore.instance);
});

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) {
  return ref.watch(memberRepositoryProvider).getAll();
});
