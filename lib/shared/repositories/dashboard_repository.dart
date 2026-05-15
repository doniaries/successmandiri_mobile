import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';

class DashboardRepository {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardSummary> getSummary() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.dashboardSummary);
      return DashboardSummary.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

