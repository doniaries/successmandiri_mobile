$path = "c:\laragon\www\successmandiri_mobile\lib\screens\dashboard\dashboard_screen.dart"
$content = Get-Content $path
$part1 = $content[0..418]
$part2 = @(
    "                            Consumer<DashboardProvider>(",
    "                              builder: (context, dashboard, child) {",
    "                                if (dashboard.isLoading) {",
    "                                  return _buildSkeletonCard();",
    "                                }",
    "                                final summary = dashboard.summary;",
    "                                if (summary != null) {",
    "                                  return _buildStatCards(",
    "                                    summary.saldo,",
    "                                    summary.stats,",
    "                                  );",
    "                                }",
    "                                return const SizedBox.shrink();",
    "                              },",
    "                            ),",
    "                          ],",
    "                        ),",
    "                      ),",
    "                    ],",
    "                  ),",
    "                ),",
    "              ),"
)
$part3 = $content[441..($content.Length - 1)]
$newContent = $part1 + $part2 + $part3
$newContent | Set-Content $path
