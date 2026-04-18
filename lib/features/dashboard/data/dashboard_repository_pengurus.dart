part of 'dashboard_repository.dart';

extension DashboardRepositoryPengurusExtension on DashboardRepository {
  Future<List<Map<String, dynamic>>> fetchPengurusApprovalQueue() async {
    try {
      final rows = _toMapList(
        await _runInvoiceSelectWithFallback(
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,nama_pelanggan,lokasi_muat,lokasi_bongkar,'
          'armada_start_date,status,total_biaya,pph,total_bayar,created_by,created_at,updated_at,'
          'submission_role,approval_status,approval_requested_at,approval_requested_by,'
          'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
          'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by,rincian',
          (columns) => _supabase
              .from('invoices')
              .select(columns)
              .eq('submission_role', 'pengurus')
              .or(
                'approval_status.eq.pending,approval_status.is.null,edit_request_status.eq.pending',
              )
              .order('created_at', ascending: false),
        ),
      );
      final creatorIds = rows
          .map((row) => '${row['created_by'] ?? ''}'.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final profileById = <String, Map<String, dynamic>>{};
      if (creatorIds.isNotEmpty) {
        try {
          final profiles = _toMapList(
            await _supabase
                .from('profiles')
                .select('id,name,username,role')
                .inFilter('id', creatorIds),
          );
          for (final row in profiles) {
            final id = '${row['id'] ?? ''}'.trim();
            if (id.isEmpty) continue;
            profileById[id] = row;
          }
        } catch (_) {
          // Approval queue tetap harus tampil walau nama pembuat tidak bisa
          // di-resolve dari tabel profiles.
        }
      }
      return rows.map((row) {
        final creatorId = '${row['created_by'] ?? ''}'.trim();
        final creator = profileById[creatorId];
        final requestType =
            '${row['edit_request_status'] ?? ''}'.trim().toLowerCase() ==
                    'pending'
                ? 'edit_request'
                : 'new_income';
        return <String, dynamic>{
          ...row,
          '__request_type': requestType,
          '__creator_name':
              '${creator?['name'] ?? creator?['username'] ?? creatorId ?? '-'}'
                  .trim(),
        };
      }).toList();
    } on PostgrestException catch (e) {
      final workflowMissing = DashboardRepository._optionalInvoiceColumns.any(
        (column) => _isMissingColumnError(e, column),
      );
      if (workflowMissing) return const <Map<String, dynamic>>[];
      throw Exception('Gagal memuat approval income pengurus: ${e.message}');
    }
  }

  Future<int> countPendingPengurusApprovals() async {
    final rows = await fetchPengurusApprovalQueue();
    return rows.length;
  }

  Future<void> requestPengurusInvoiceEdit(String invoiceId) async {
    final cleanedId = invoiceId.trim();
    if (cleanedId.isEmpty) {
      throw Exception('ID invoice tidak ditemukan.');
    }
    try {
      await _supabase.rpc(
        'request_pengurus_invoice_edit',
        params: {'p_invoice_id': cleanedId},
      );
      final invoice = await fetchInvoiceById(cleanedId);
      if (invoice != null) {
        await _notifyStaffAboutPengurusEditRequest(invoice);
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal mengirim request edit invoice: ${e.message}');
    }
  }

  Future<void> approvePengurusIncome(String invoiceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    final invoice = await fetchInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Income pengurus tidak ditemukan.');
    }
    final nowIso = DateTime.now().toIso8601String();
    await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
      'approval_status': 'approved',
      'approved_at': nowIso,
      'approved_by': user.id,
      'rejected_at': null,
      'rejected_by': null,
      'updated_at': nowIso,
    });
    final details = _buildEffectiveIncomeDetails(
      details: _toMapList(invoice['rincian']),
      pickup: '${invoice['lokasi_muat'] ?? ''}',
      destination: '${invoice['lokasi_bongkar'] ?? ''}',
      armadaId: '${invoice['armada_id'] ?? ''}',
      armadaStartDate: Formatters.parseDate(invoice['armada_start_date']),
      armadaEndDate: Formatters.parseDate(invoice['armada_end_date']),
      tonase: _num(invoice['tonase']),
      harga: _num(invoice['harga']),
      muatan: '${invoice['muatan'] ?? ''}',
      namaSupir: '${invoice['nama_supir'] ?? ''}',
    );
    final expenseReferenceDate = _resolveExpenseReferenceDateFromDetails(
      details,
      fallbackDate: invoice['armada_start_date'] ?? invoice['tanggal'],
    );
    await _createSanguExpenseFromIncomeBestEffort(
      invoiceId: invoiceId,
      invoiceNumber: '${invoice['no_invoice'] ?? ''}',
      expenseDate: expenseReferenceDate,
      details: details,
      fallbackPickup: '${invoice['lokasi_muat'] ?? ''}',
      fallbackDestination: '${invoice['lokasi_bongkar'] ?? ''}',
      fallbackArmadaId: '${invoice['armada_id'] ?? ''}',
      fallbackCargo: '${invoice['muatan'] ?? ''}',
    );
    final creatorId = '${invoice['created_by'] ?? ''}'.trim();
    if (creatorId.isNotEmpty) {
      await _insertCustomerNotificationBestEffort(
        userId: creatorId,
        title: 'Income Pengurus Disetujui',
        message:
            'Income untuk ${invoice['nama_pelanggan'] ?? '-'} sudah disetujui admin/owner.',
        kind: 'success',
        sourceType: 'invoice',
        sourceId: invoiceId,
        payload: <String, dynamic>{
          'invoice_id': invoiceId,
          'request_type': 'new_income',
          'target': 'invoice_list',
        },
      );
    }
  }

  Future<void> rejectPengurusIncome(String invoiceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    final invoice = await fetchInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Income pengurus tidak ditemukan.');
    }
    final nowIso = DateTime.now().toIso8601String();
    await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
      'approval_status': 'rejected',
      'rejected_at': nowIso,
      'rejected_by': user.id,
      'updated_at': nowIso,
    });
    final creatorId = '${invoice['created_by'] ?? ''}'.trim();
    if (creatorId.isNotEmpty) {
      await _insertCustomerNotificationBestEffort(
        userId: creatorId,
        title: 'Income Pengurus Ditolak',
        message:
            'Income untuk ${invoice['nama_pelanggan'] ?? '-'} ditolak admin/owner. Cek data lalu ajukan lagi.',
        kind: 'error',
        sourceType: 'invoice',
        sourceId: invoiceId,
        payload: <String, dynamic>{
          'invoice_id': invoiceId,
          'request_type': 'new_income',
          'target': 'invoice_list',
        },
      );
    }
  }

  Future<void> approvePengurusInvoiceEdit(String invoiceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    final invoice = await fetchInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Invoice pengurus tidak ditemukan.');
    }
    final nowIso = DateTime.now().toIso8601String();
    await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
      'edit_request_status': 'approved',
      'edit_resolved_at': nowIso,
      'edit_resolved_by': user.id,
      'updated_at': nowIso,
    });
    final creatorId = '${invoice['created_by'] ?? ''}'.trim();
    if (creatorId.isNotEmpty) {
      await _insertCustomerNotificationBestEffort(
        userId: creatorId,
        title: 'Request Edit Disetujui',
        message:
            'Request edit untuk income ${invoice['nama_pelanggan'] ?? '-'} sudah disetujui. Sekarang data bisa direvisi.',
        kind: 'success',
        sourceType: 'invoice',
        sourceId: invoiceId,
        payload: <String, dynamic>{
          'invoice_id': invoiceId,
          'request_type': 'edit_request',
          'target': 'invoice_list',
        },
      );
    }
  }

  Future<void> rejectPengurusInvoiceEdit(String invoiceId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    final invoice = await fetchInvoiceById(invoiceId);
    if (invoice == null) {
      throw Exception('Invoice pengurus tidak ditemukan.');
    }
    final nowIso = DateTime.now().toIso8601String();
    await _updateInvoiceWithFallback(invoiceId, <String, dynamic>{
      'edit_request_status': 'rejected',
      'edit_resolved_at': nowIso,
      'edit_resolved_by': user.id,
      'updated_at': nowIso,
    });
    final creatorId = '${invoice['created_by'] ?? ''}'.trim();
    if (creatorId.isNotEmpty) {
      await _insertCustomerNotificationBestEffort(
        userId: creatorId,
        title: 'Request Edit Ditolak',
        message:
            'Request edit untuk income ${invoice['nama_pelanggan'] ?? '-'} ditolak admin/owner.',
        kind: 'warning',
        sourceType: 'invoice',
        sourceId: invoiceId,
        payload: <String, dynamic>{
          'invoice_id': invoiceId,
          'request_type': 'edit_request',
          'target': 'invoice_list',
        },
      );
    }
  }
}
