import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';

class DashboardRepository {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardSummary> getSummary({String? date}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.dashboardSummary,
        queryParameters: date != null ? {'date': date} : null,
      );
      return DashboardSummary.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

