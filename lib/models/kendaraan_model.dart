class Kendaraan {
  final int id;
  final String nopol;
  final String? jenis;
  final String? status;

  Kendaraan({
    required this.id,
    required this.nopol,
    this.jenis,
    this.status,
  });

  factory Kendaraan.fromJson(Map<String, dynamic> json) {
    return Kendaraan(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nopol: json['no_polisi'],
      jenis: json['jenis_kendaraan'],
      status: json['status_kendaraan'],
    );
  }
}

