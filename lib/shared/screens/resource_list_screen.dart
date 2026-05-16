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
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';


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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ResourceProvider>().fetchResources(widget.resourceType);
    }
  }

  Future<void> _refreshData() async {
    await context.read<ResourceProvider>().fetchResources(widget.resourceType, refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.resourceType == 'operasional') {
      return const OperasionalScreen();
    }
    if (widget.resourceType == 'transaksi_do') {
      return const TransaksiDoScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
              items = items.where((i) => i.operasional.toLowerCase() == widget.initialFilter!.toLowerCase()).toList();
            } else if (widget.resourceType == 'jurnal_keuangan') {
              items = items.where((i) => i.jenisTransaksi.toLowerCase() == widget.initialFilter!.toLowerCase()).toList();
            }
          }

          if (provider.isLoading && items.isEmpty) {
            return _buildSkeletons();
          }


          return RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF01579B),
            child: items.isEmpty
                ? Stack(
                    children: [
                      ListView(), // Dynamic list to enable RefreshIndicator
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('Data ${widget.title} belum tersedia', style: TextStyle(color: Colors.grey[400])),
                            const SizedBox(height: 8),
                            Text('Tarik ke bawah untuk memuat ulang', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length + (provider.isFetchingMoreFor(widget.resourceType) ? 1 : 0),
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index < items.length) {
                        final item = items[index];
                        return _buildItemTile(item);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                              child: AppLoadingIndicator(size: 24),
                          ),
                        );
                      }
                    },
                  ),
          );
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
        },
        backgroundColor: const Color(0xFF01579B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
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
      subtitle = '${CurrencyFormatter.formatRupiah(item.nominal)} - ${item.keterangan ?? ""}';
      icon = Icons.account_balance_wallet_rounded;
      iconColor = item.operasional.toLowerCase() == 'pengeluaran' ? const Color(0xFF0D47A1) : const Color(0xFF27AE60);
    } else if (item is JurnalKeuangan) {
      name = item.keterangan?.isNotEmpty == true ? item.keterangan! : item.jenisTransaksi;
      subtitle = '${CurrencyFormatter.formatRupiah(item.nominal)} - ${item.jenisTransaksi}';
      icon = Icons.receipt_long_rounded;
      iconColor = item.jenisTransaksi == 'Pemasukan' ? const Color(0xFF27AE60) : const Color(0xFF0D47A1);
    } else if (item is User) {
      name = item.name.toUpperCase();
      subtitle = item.email;
      icon = Icons.manage_accounts_rounded;
      iconColor = const Color(0xFF673AB7);
    }

    final bool isDeletable = (item is Penjual || item is Supir || item is Pekerja);

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  if (hutang != null && hutang > 0)
                    Text(
                      'HUTANG: ${CurrencyFormatter.formatRupiah(hutang)}',
                      style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
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
          child: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ),
        onTap: () {
          if (item is Operasional) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OperasionalDetailScreen(operasional: item),
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
                context.read<ResourceProvider>().fetchResources('penjual', refresh: true);
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
                context.read<ResourceProvider>().fetchResources('supir', refresh: true);
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
                context.read<ResourceProvider>().fetchResources('pekerja', refresh: true);
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

    if (!isDeletable) return tile;

    return Dismissible(
      key: Key('delete_${widget.resourceType}_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('Apakah Anda yakin ingin menghapus $name dari daftar ${widget.title}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('BATAL', style: TextStyle(color: Colors.grey[600])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('HAPUS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final provider = context.read<ResourceProvider>();
        final success = await provider.deleteResource(widget.resourceType, item.id);
        
        if (!mounted) return;
        
        if (!success) {
          // Refresh list to restore the item since delete failed
          await provider.fetchResources(widget.resourceType, refresh: true);
          if (context.mounted) {
            ErrorDialog.show(
              context,
              title: 'Gagal Menghapus',
              message: provider.errorMessage ?? 'Data tidak dapat dihapus karena mungkin masih terkait dengan transaksi lain.',
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$name berhasil dihapus')),
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 30),
      ),
      child: tile,
    );
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
                  SkeletonLoader(width: MediaQuery.of(context).size.width * 0.4, height: 16),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: MediaQuery.of(context).size.width * 0.6, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

