import 'office.dart';

abstract interface class OfficeRepository {
  Stream<Office?> watchOffice({required String officeId});
}

class OfficeFailure implements Exception {
  const OfficeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
