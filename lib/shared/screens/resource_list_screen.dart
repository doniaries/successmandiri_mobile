import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/features/supir/models/supir_model.dart';
import 'package:sawitappmobile/features/kendaraan/models/kendaraan_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/features/pekerja/models/pekerja_model.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_detail_screen.dart';
import 'package:sawitappmobile/features/penjual/screens/add_penjual_screen.dart';
import 'package:sawitappmobile/features/supir/screens/add_supir_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/add_operasional_screen.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/screens/jurnal_keuangan_detail_screen.dart';
import 'package:sawitappmobile/features/penjual/screens/penjual_detail_screen.dart';
import 'package:sawitappmobile/features/supir/screens/supir_detail_screen.dart';
import 'package:sawitappmobile/features/pekerja/screens/add_pekerja_screen.dart';
import 'package:sawitappmobile/features/pekerja/screens/pekerja_detail_screen.dart';
import 'package:sawitappmobile/features/user/screens/user_detail_screen.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';

class ResourceListScreen extends StatefulWidget {
  final String title;
  final String resourceType;
  final String? initialFilter;

  const ResourceListScreen({
    super.key,
    required this.title,
    required this.resourceType,
    this.initialFilter,
  });

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _inactiveScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _activeScrollController.addListener(_onActiveScroll);
    _inactiveScrollController.addListener(_onInactiveScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _activeScrollController.dispose();
    _inactiveScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ResourceProvider>().fetchResources(widget.resourceType);
    }
  }

  void _onActiveScroll() {
    if (_activeScrollController.position.pixels >=
        _activeScrollController.position.maxScrollExtent - 200) {
      context.read<ResourceProvider>().fetchResources(widget.resourceType);
    }
  }

  void _onInactiveScroll() {
    if (_inactiveScrollController.position.pixels >=
        _inactiveScrollController.position.maxScrollExtent - 200) {
      context.read<ResourceProvider>().fetchResources(widget.resourceType);
    }
  }

  Future<void> _refreshData() async {
    await context.read<ResourceProvider>().fetchResources(
      widget.resourceType,
      refresh: true,
    );
  }

  Widget _buildSummaryCards(List<dynamic> items) {
    final int totalCount = items.length;
    final double totalHutang = items.fold(0.0, (sum, item) {
      if (item is Penjual) return sum + (item.sisaHutang ?? 0.0);
      if (item is Supir) return sum + (item.sisaHutang ?? 0.0);
      if (item is Pekerja) return sum + item.sisaHutang;
      return sum;
    });

    String titleLabel = 'Total';
    IconData countIcon = Icons.people_alt_rounded;
    Color themeColor = const Color(0xFF01579B);

    if (widget.resourceType == 'penjual') {
      titleLabel = 'Total Penjual';
      countIcon = Icons.store_rounded;
      themeColor = const Color(0xFF0288D1);
    } else if (widget.resourceType == 'supir') {
      titleLabel = 'Total Supir';
      countIcon = Icons.local_shipping_rounded;
      themeColor = const Color(0xFF00897B);
    } else if (widget.resourceType == 'pekerja') {
      titleLabel = 'Total Pekerja';
      countIcon = Icons.engineering_rounded;
      themeColor = const Color(0xFF7B1FA2);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Total Orang Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withAlpha(217)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withAlpha(64),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        titleLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        countIcon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$totalCount Orang',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aktif / Terdaftar',
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Total Hutang Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Hutang',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.red[400],
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      CurrencyFormatter.formatRupiah(totalHutang),
                      style: TextStyle(
                        color: totalHutang > 0 ? Colors.red[700] : Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sisa Kewajiban',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(ResourceProvider provider, List<dynamic> items, ScrollController controller) {
    if (provider.isLoading && items.isEmpty) {
      return _buildSkeletons();
    }

    final bool showCards = widget.resourceType == 'penjual' ||
        widget.resourceType == 'supir' ||
        widget.resourceType == 'pekerja';

    Widget listBody = items.isEmpty
        ? Stack(
            children: [
              ListView(), // Dynamic list to enable RefreshIndicator
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data ${widget.title} belum tersedia',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tarik ke bawah untuk memuat ulang',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        : ListView.separated(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount:
                items.length +
                (provider.isFetchingMoreFor(widget.resourceType)
                    ? 1
                    : 0),
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index < items.length) {
                final item = items[index];
                return _buildItemTile(item);
              } else {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: AppLoadingIndicator(size: 24)),
                );
              }
            },
          );

    final Widget scrollableList = RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF01579B),
      child: listBody,
    );

    if (showCards) {
      return Column(
        children: [
          _buildSummaryCards(items),
          Expanded(child: scrollableList),
        ],
      );
    }

    return scrollableList;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resourceType == 'operasional') {
      return const OperasionalScreen();
    }
    if (widget.resourceType == 'transaksi_do') {
      return const TransaksiDoScreen();
    }

    final bool hasTabs = widget.resourceType == 'penjual' ||
        widget.resourceType == 'supir' ||
        widget.resourceType == 'pekerja';

    Widget scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: hasTabs
            ? const TabBar(
                labelColor: Color(0xFF01579B),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF01579B),
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                tabs: [
                  Tab(text: 'AKTIF'),
                  Tab(text: 'NONAKTIF'),
                ],
              )
            : null,
      ),
      body: Consumer<ResourceProvider>(
        builder: (context, provider, child) {
          List<dynamic> items = [];
          switch (widget.resourceType) {
            case 'penjual':
              items = provider.penjuals;
              break;
            case 'supir':
              items = provider.supirs;
              break;
            case 'pekerja':
              items = provider.pekerjas;
              break;
            case 'kendaraan':
              items = provider.kendaraans;
              break;
            case 'operasional':
              items = provider.operasionals;
              break;
            case 'jurnal_keuangan':
              items = provider.jurnalKeuangans;
              break;
            case 'user':
              items = provider.users;
              break;
          }

          // Apply initial filter if provided
          if (widget.initialFilter != null) {
            if (widget.resourceType == 'operasional') {
              items = items
                  .where(
                    (i) =>
                        i.operasional.toLowerCase() ==
                        widget.initialFilter!.toLowerCase(),
                  )
                  .toList();
            } else if (widget.resourceType == 'jurnal_keuangan') {
              items = items
                  .where(
                    (i) =>
                        i.jenisTransaksi.toLowerCase() ==
                        widget.initialFilter!.toLowerCase(),
                  )
                  .toList();
            }
          }

          if (hasTabs) {
            final activeItems = items.where((i) {
              if (i is Penjual) return i.isActive;
              if (i is Supir) return i.isActive;
              if (i is Pekerja) return i.isActive;
              return true;
            }).toList();

            final inactiveItems = items.where((i) {
              if (i is Penjual) return !i.isActive;
              if (i is Supir) return !i.isActive;
              if (i is Pekerja) return !i.isActive;
              return false;
            }).toList();

            return TabBarView(
              children: [
                _buildListContent(provider, activeItems, _activeScrollController),
                _buildListContent(provider, inactiveItems, _inactiveScrollController),
              ],
            );
          }

          return _buildListContent(provider, items, _scrollController);
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'resource_list_fab_${widget.resourceType}',
        onPressed: () {
          Widget screen;
          switch (widget.resourceType) {
            case 'penjual':
              screen = const AddPenjualScreen();
              break;
            case 'supir':
              screen = const AddSupirScreen();
              break;
            case 'pekerja':
              screen = const AddPekerjaScreen();
              break;
            case 'operasional':
              screen = const AddOperasionalScreen();
              break;
            default:
              return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
        backgroundColor: const Color(0xFF01579B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );

    if (hasTabs) {
      return DefaultTabController(
        length: 2,
        child: scaffold,
      );
    }

    return scaffold;
  }

  Widget _buildItemTile(dynamic item) {
    String name = '';
    String? subtitle;
    double? hutang;
    IconData icon = Icons.info;
    Color iconColor = const Color(0xFF2980B9);

    if (item is Penjual) {
      name = item.nama.toUpperCase();
      subtitle = item.telepon;
      hutang = item.sisaHutang;
      icon = Icons.store_rounded;
      iconColor = const Color(0xFF01579B);
    } else if (item is Supir) {
      name = item.nama.toUpperCase();
      subtitle = item.status;
      hutang = item.sisaHutang;
      icon = Icons.person_rounded;
      iconColor = const Color(0xFF01579B);
    } else if (item is Pekerja) {
      name = item.nama.toUpperCase();
      subtitle = item.posisi;
      hutang = item.sisaHutang;
      icon = Icons.engineering_rounded;
      iconColor = const Color(0xFF00796B);
    } else if (item is Kendaraan) {
      name = item.nopol;
      subtitle = item.jenis;
      icon = Icons.directions_car_rounded;
      iconColor = const Color(0xFF2980B9);
    } else if (item is Operasional) {
      name = item.kategoriLabel ?? item.kategori;
      subtitle =
          '${CurrencyFormatter.formatRupiah(item.nominal)} - ${item.keterangan ?? ""}';
      icon = Icons.account_balance_wallet_rounded;
      iconColor = item.operasional.toLowerCase() == 'pengeluaran'
          ? const Color(0xFF0D47A1)
          : const Color(0xFF27AE60);
    } else if (item is JurnalKeuangan) {
      name = item.pihakTerkait != null && item.pihakTerkait!.isNotEmpty && item.pihakTerkait != '-'
          ? '${item.pihakTerkait} (${item.subKategori})'
          : (item.keterangan?.isNotEmpty == true 
              ? '${item.subKategori} (${item.keterangan})' 
              : item.subKategori);
      subtitle =
          '${CurrencyFormatter.formatRupiah(item.nominal)} • ${item.jenisTransaksi} • ${item.caraPembayaran.toUpperCase()}';
      icon = Icons.receipt_long_rounded;
      iconColor = item.jenisTransaksi == 'Pemasukan'
          ? const Color(0xFF27AE60)
          : const Color(0xFF0D47A1);
    } else if (item is User) {
      name = item.name.toUpperCase();
      subtitle = item.email;
      icon = Icons.manage_accounts_rounded;
      iconColor = const Color(0xFF673AB7);
    }

    Widget tile = Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: (item is User && item.fullPhotoUrl != null)
            ? CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(item.fullPhotoUrl!),
                backgroundColor: iconColor.withValues(alpha: 0.1),
              )
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF1A1A1A),
          ),
        ),
        subtitle: (subtitle != null || (hutang != null && hutang > 0))
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (hutang != null && hutang > 0)
                      Text(
                        'HUTANG: ${CurrencyFormatter.formatRupiah(hutang)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey[400],
            size: 20,
          ),
        ),
        onTap: () {
          if (item is Operasional) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    OperasionalDetailScreen(operasional: item),
              ),
            );
          } else if (item is JurnalKeuangan) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JurnalKeuanganDetailScreen(jurnal: item),
              ),
            );
          } else if (item is Penjual) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PenjualDetailScreen(penjual: item),
              ),
            ).then((deleted) {
              if (deleted == true && mounted && context.mounted) {
                context.read<ResourceProvider>().fetchResources(
                  'penjual',
                  refresh: true,
                );
              }
            });
          } else if (item is Supir) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SupirDetailScreen(supir: item),
              ),
            ).then((deleted) {
              if (deleted == true && mounted && context.mounted) {
                context.read<ResourceProvider>().fetchResources(
                  'supir',
                  refresh: true,
                );
              }
            });
          } else if (item is Pekerja) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PekerjaDetailScreen(pekerja: item),
              ),
            ).then((deleted) {
              if (deleted == true && mounted && context.mounted) {
                context.read<ResourceProvider>().fetchResources(
                  'pekerja',
                  refresh: true,
                );
              }
            });
          } else if (item is User) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailScreen(user: item),
              ),
            );
          }
        },
      ),
    );

    return tile;
  }

  Widget _buildSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SkeletonLoader(width: 48, height: 48, borderRadius: 15),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 16,
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 12,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
