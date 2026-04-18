part of 'dashboard_repository.dart';

extension DashboardRepositoryCrudExtension on DashboardRepository {
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    const variants = <String>[
      'id,email,name,username,avatar_url,role,phone,gender,birth_date,address,city,company,created_at,updated_at',
      'id,email,name,username,role,phone,gender,birth_date,address,city,company,created_at,updated_at',
    ];

    PostgrestException? lastError;
    for (final columns in variants) {
      try {
        final res = await _supabase
            .from('profiles')
            .select(columns)
            .eq('id', user.id)
            .maybeSingle();
        if (res == null) return null;
        return Map<String, dynamic>.from(res);
      } on PostgrestException catch (e) {
        lastError = e;
        final message = e.message.toLowerCase();
        if (!message.contains('column') &&
            !message.contains('does not exist')) {
          throw Exception('Gagal memuat profil: ${e.message}');
        }
      }
    }

    throw Exception('Gagal memuat profil: ${lastError?.message ?? 'unknown'}');
  }

  Future<void> createInvoice({
    required String customerName,
    required double total,
    String? noInvoice,
    String? invoiceEntity,
    bool includePph = true,
    String status = 'Unpaid',
    DateTime? issuedDate,
    String? email,
    String? noTelp,
    DateTime? kopDate,
    String? kopLocation,
    DateTime? dueDate,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? acceptedBy,
    String? customerId,
    String? orderId,
    List<Map<String, dynamic>>? details,
    String? submissionRole,
    String? approvalStatus,
    bool generateAutoSangu = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    DateTime? resolveIssueDateFromDetails(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final parsed = Formatters.parseDate(row['armada_start_date']);
        if (parsed != null) return parsed;
      }
      if (armadaStartDate != null) return armadaStartDate;
      return null;
    }

    final effectiveDetails = _buildEffectiveIncomeDetails(
      details: details,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: armadaStartDate,
      armadaEndDate: armadaEndDate,
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
    );
    final sanitizedDetails = _sanitizeIncomeDetails(effectiveDetails);
    final parsedIssueDate = resolveIssueDateFromDetails(sanitizedDetails) ??
        issuedDate ??
        DateTime.now();
    final requestedInvoiceNumber =
        (noInvoice?.trim().isEmpty ?? true) ? null : noInvoice!.trim();
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: sanitizedDetails);

    final effectiveSubmissionRole =
        (submissionRole ?? await _loadCurrentRole()).trim().toLowerCase();
    final effectiveApprovalStatus = (approvalStatus ??
            (effectiveSubmissionRole == 'pengurus' ? 'pending' : 'approved'))
        .trim()
        .toLowerCase();

    if (sanitizedDetails.length > 1) {
      final invalidDetailIndexes = <int>[];
      for (var i = 0; i < sanitizedDetails.length; i++) {
        if (_resolveIncomeDetailTotal(sanitizedDetails[i]) <= 0) {
          invalidDetailIndexes.add(i + 1);
        }
      }
      if (invalidDetailIndexes.isNotEmpty) {
        final detailLabels = invalidDetailIndexes.join(', ');
        throw Exception(
          'Setiap keberangkatan wajib memiliki tonase dan harga. Periksa rincian ke-$detailLabels.',
        );
      }

      for (var i = 0; i < sanitizedDetails.length; i++) {
        final detail = Map<String, dynamic>.from(sanitizedDetails[i]);
        final detailPickup = '${detail['lokasi_muat'] ?? pickup ?? ''}'.trim();
        final detailDestination =
            '${detail['lokasi_bongkar'] ?? destination ?? ''}'.trim();
        final detailArmadaId =
            '${detail['armada_id'] ?? armadaId ?? ''}'.trim().isEmpty
                ? null
                : '${detail['armada_id'] ?? armadaId}'.trim();
        final detailArmadaStartDate =
            Formatters.parseDate(detail['armada_start_date']) ??
                armadaStartDate;
        final detailArmadaEndDate =
            Formatters.parseDate(detail['armada_end_date']) ?? armadaEndDate;
        final detailMuatan =
            '${detail['muatan'] ?? muatan ?? ''}'.trim().isEmpty
                ? null
                : '${detail['muatan'] ?? muatan}'.trim();
        final detailDriver = _resolveDriverNames(
          explicitName: '${detail['nama_supir'] ?? namaSupir ?? ''}',
          details: [detail],
        );
        final detailTonase = _num(detail['tonase']);
        final detailHarga = _num(detail['harga']);
        final detailTotal = _resolveIncomeDetailTotal(detail);
        final detailIssueDate = detailArmadaStartDate ?? parsedIssueDate;

        final inserted = await _insertSingleIncomeInvoice(
          customerName: customerName,
          total: detailTotal,
          requestedNoInvoice: i == 0 ? requestedInvoiceNumber : null,
          invoiceEntity: invoiceEntity,
          includePph: includePph,
          status: status,
          issueDate: detailIssueDate,
          email: email,
          noTelp: noTelp,
          kopDate: kopDate,
          kopLocation: kopLocation,
          dueDate: dueDate,
          pickup: detailPickup,
          destination: detailDestination,
          armadaId: detailArmadaId,
          armadaStartDate: detailArmadaStartDate,
          armadaEndDate: detailArmadaEndDate,
          tonase: detailTonase,
          harga: detailHarga,
          muatan: detailMuatan,
          namaSupir: detailDriver,
          acceptedBy: acceptedBy,
          customerId: customerId,
          orderId: orderId,
          details: [detail],
          createdBy: user.id,
          submissionRole: effectiveSubmissionRole,
          approvalStatus: effectiveApprovalStatus,
        );

        if (generateAutoSangu && effectiveApprovalStatus == 'approved') {
          await _createSanguExpenseFromIncomeBestEffort(
            invoiceId: inserted['id'],
            invoiceNumber: inserted['no_invoice'] ?? '-',
            expenseDate: detailIssueDate,
            details: [detail],
            fallbackPickup: detailPickup,
            fallbackDestination: detailDestination,
            fallbackArmadaId: detailArmadaId,
            fallbackCargo: detailMuatan,
          );
        }
        if (effectiveSubmissionRole == 'pengurus' &&
            inserted['id'] != null &&
            '${inserted['id']}'.trim().isNotEmpty) {
          await _notifyStaffAboutPengurusIncomeBestEffort(
            invoiceId: '${inserted['id']}',
            customerName: customerName,
            pickup: detailPickup,
            destination: detailDestination,
            invoiceDate: detailIssueDate,
          );
        }
      }

      await _setArmadaStatusBestEffort(
        selectedArmadaIds,
        status: 'Full',
      );
      await _syncArmadaStatusNowBestEffort();
      return;
    }

    final singleDetailList =
        sanitizedDetails.isEmpty ? effectiveDetails : sanitizedDetails;
    final singleInserted = await _insertSingleIncomeInvoice(
      customerName: customerName,
      total: total,
      requestedNoInvoice: requestedInvoiceNumber,
      invoiceEntity: invoiceEntity,
      includePph: includePph,
      status: status,
      issueDate: parsedIssueDate,
      email: email,
      noTelp: noTelp,
      kopDate: kopDate,
      kopLocation: kopLocation,
      dueDate: dueDate,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: armadaStartDate,
      armadaEndDate: armadaEndDate,
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
      acceptedBy: acceptedBy,
      customerId: customerId,
      orderId: orderId,
      details: singleDetailList,
      createdBy: user.id,
      submissionRole: effectiveSubmissionRole,
      approvalStatus: effectiveApprovalStatus,
    );

    if (generateAutoSangu && effectiveApprovalStatus == 'approved') {
      await _createSanguExpenseFromIncomeBestEffort(
        invoiceId: singleInserted['id'],
        invoiceNumber: singleInserted['no_invoice'] ?? '-',
        expenseDate: parsedIssueDate,
        details: singleDetailList,
        fallbackPickup: pickup,
        fallbackDestination: destination,
        fallbackArmadaId: armadaId,
        fallbackCargo: muatan,
      );
    }
    if (effectiveSubmissionRole == 'pengurus' &&
        singleInserted['id'] != null &&
        '${singleInserted['id']}'.trim().isNotEmpty) {
      await _notifyStaffAboutPengurusIncomeBestEffort(
        invoiceId: '${singleInserted['id']}',
        customerName: customerName,
        pickup: pickup,
        destination: destination,
        invoiceDate: parsedIssueDate,
      );
    }

    await _setArmadaStatusBestEffort(
      selectedArmadaIds,
      status: 'Full',
    );
    await _syncArmadaStatusNowBestEffort();
  }

  Future<Map<String, String?>> _insertSingleIncomeInvoice({
    required String customerName,
    required double total,
    required bool includePph,
    required String status,
    required DateTime issueDate,
    required String createdBy,
    required String submissionRole,
    required String approvalStatus,
    String? requestedNoInvoice,
    String? invoiceEntity,
    String? email,
    String? noTelp,
    DateTime? kopDate,
    String? kopLocation,
    DateTime? dueDate,
    String? pickup,
    String? destination,
    String? armadaId,
    DateTime? armadaStartDate,
    DateTime? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? acceptedBy,
    String? customerId,
    String? orderId,
    List<Map<String, dynamic>>? details,
  }) async {
    final normalizedIssueDate = issueDate.toLocal();
    final date = _dateOnly(normalizedIssueDate);
    final normalizedKopLocation =
        kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim();
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );
    final pphValue = includePph ? max(0, (total * 0.02).floorToDouble()) : 0.0;
    final totalBayarValue = max(0, total - pphValue);
    final normalizedInvoiceEntity = _resolveInvoiceEntity(
      invoiceEntity: invoiceEntity,
      invoiceNumber: requestedNoInvoice,
      customerName: customerName,
      isCompany: _isCompanyCustomerName(customerName.trim()) ||
          _isCompanyInvoiceNumber(requestedNoInvoice ?? ''),
    );
    var currentCode = '';
    if ((requestedNoInvoice ?? '').trim().isNotEmpty) {
      final normalized = Formatters.invoiceNumber(
        requestedNoInvoice!.trim(),
        kopDate ?? issueDate,
        customerName: customerName,
        isCompany: Formatters.isCompanyInvoiceEntity(normalizedInvoiceEntity),
        invoiceEntity: normalizedInvoiceEntity,
      );
      currentCode = normalized == '-' ? requestedNoInvoice.trim() : normalized;
    }

    final basePayload = <String, dynamic>{
      'tanggal': date,
      'tanggal_kop': kopDate == null ? null : _dateOnly(kopDate),
      'lokasi_kop': normalizedKopLocation,
      'nama_pelanggan': customerName.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'no_telp': noTelp?.trim().isEmpty == true ? null : noTelp?.trim(),
      'due_date': dueDate == null ? null : _dateOnly(dueDate),
      'lokasi_muat': pickup?.trim().isEmpty == true ? null : pickup?.trim(),
      'lokasi_bongkar':
          destination?.trim().isEmpty == true ? null : destination?.trim(),
      'armada_start_date':
          armadaStartDate == null ? null : _dateOnly(armadaStartDate),
      'armada_end_date':
          armadaEndDate == null ? null : _dateOnly(armadaEndDate),
      'tonase': tonase,
      'harga': harga,
      'muatan': muatan?.trim().isEmpty == true ? null : muatan?.trim(),
      'nama_supir': driverNames,
      'status': status,
      'total_biaya': total,
      'pph': pphValue,
      'total_bayar': totalBayarValue,
      'diterima_oleh':
          acceptedBy?.trim().isEmpty == true ? null : acceptedBy?.trim(),
      'created_by': createdBy,
      'submission_role': submissionRole,
      'approval_status': approvalStatus,
      'invoice_entity': normalizedInvoiceEntity,
      'approval_requested_at':
          approvalStatus == 'pending' ? DateTime.now().toIso8601String() : null,
      'approval_requested_by': approvalStatus == 'pending' ? createdBy : null,
      'approved_at': approvalStatus == 'approved'
          ? DateTime.now().toIso8601String()
          : null,
      'approved_by': approvalStatus == 'approved' ? createdBy : null,
      'edit_request_status': 'none',
    };

    if (customerId != null && customerId.trim().isNotEmpty) {
      basePayload['customer_id'] = customerId.trim();
    }
    if (orderId != null && orderId.trim().isNotEmpty) {
      basePayload['order_id'] = orderId.trim();
    }
    if (armadaId != null && armadaId.trim().isNotEmpty) {
      basePayload['armada_id'] = armadaId.trim();
    }
    if (details != null && details.isNotEmpty) {
      basePayload['rincian'] = details;
    }

    String insertedInvoiceId = '';
    PostgrestException? pengurusRpcError;
    final payload = <String, dynamic>{
      ...basePayload,
      if (currentCode.isNotEmpty) 'no_invoice': currentCode,
    };
    if (submissionRole == 'pengurus') {
      // Income pengurus belum memiliki nomor invoice. Nomor baru dibuat saat print.
      payload.remove('no_invoice');
      currentCode = '';
    }
    if (submissionRole == 'pengurus') {
      try {
        final insertedRow = await _insertPengurusInvoiceViaRpc(payload);
        insertedInvoiceId = '${insertedRow?['id'] ?? ''}'.trim();
        currentCode = '${insertedRow?['no_invoice'] ?? currentCode}'.trim();
        return <String, String?>{
          'id': insertedInvoiceId,
          'no_invoice': currentCode,
        };
      } on PostgrestException catch (e) {
        pengurusRpcError = e;
        final msg = e.message.toLowerCase();
        final missingRpc = msg.contains('create_pengurus_income_invoice') &&
            (msg.contains('does not exist') ||
                msg.contains('could not find') ||
                msg.contains('schema cache'));
        final explicitPengurusDenied = msg.contains('hanya pengurus');
        if (explicitPengurusDenied) {
          throw Exception(
            'Akun ini belum dikenali sebagai pengurus oleh database. Jalankan file supabase/pengurus_save_rpc_minimal.sql di Supabase SQL Editor, lalu logout dan login ulang.',
          );
        }
        if (!missingRpc) {
          // Lanjut coba jalur insert biasa. Beberapa project belum punya RPC,
          // tetapi policy insert langsung sudah cukup untuk save pengurus.
        }
      }
    }

    final selectColumns = submissionRole == 'pengurus' ? '' : 'id,no_invoice';
    try {
      final insertedRow = await _insertInvoiceWithFallback(
        payload,
        selectColumns: selectColumns,
      );
      insertedInvoiceId = '${insertedRow?['id'] ?? ''}'.trim();
      currentCode = '${insertedRow?['no_invoice'] ?? currentCode}'.trim();
      if (submissionRole == 'pengurus' && insertedInvoiceId.isEmpty) {
        final lookedUp = await _findRecentPengurusInvoice(
          createdBy: createdBy,
          issueDate: date,
          customerName: customerName.trim(),
          total: total,
          pickup: pickup,
          destination: destination,
        );
        insertedInvoiceId = '${lookedUp?['id'] ?? ''}'.trim();
        currentCode = '${lookedUp?['no_invoice'] ?? currentCode}'.trim();
      }
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final duplicateNoInvoice = currentCode.isNotEmpty &&
          (e.code == '23505' ||
              msg.contains('duplicate key') ||
              msg.contains('invoices_no_invoice_key') ||
              msg.contains('no_invoice_key'));
      if (!duplicateNoInvoice) {
        final isPengurusRlsFailure = submissionRole == 'pengurus' &&
            msg.contains('row-level security policy');
        if (isPengurusRlsFailure) {
          final rpcDetail = pengurusRpcError == null
              ? ''
              : ' Jalur RPC: ${pengurusRpcError.message}.';
          throw Exception(
            'Save income pengurus gagal di database.${rpcDetail.isEmpty ? '' : rpcDetail} Jalur insert: ${e.message}. Jalankan file supabase/pengurus_save_rpc_minimal.sql di Supabase SQL Editor, lalu logout dan login ulang.',
          );
        }
        if (submissionRole == 'pengurus' && pengurusRpcError != null) {
          throw Exception(
            'Save income pengurus gagal di database. Jalur RPC: ${pengurusRpcError.message}. Jalur insert: ${e.message}.',
          );
        }
        throw Exception('Gagal menambah invoice: ${e.message}');
      }
      throw Exception(
        'Gagal menambah invoice: nomor invoice bentrok, silakan coba lagi.',
      );
    }

    return <String, String?>{
      'id': insertedInvoiceId,
      'no_invoice': currentCode,
    };
  }

  Future<Map<String, dynamic>?> _insertPengurusInvoiceViaRpc(
    Map<String, dynamic> payload,
  ) async {
    final result = await _supabase.rpc(
      'create_pengurus_income_invoice',
      params: <String, dynamic>{
        'p_payload': payload,
      },
    );
    final rows = _toMapList(result);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> _findRecentPengurusInvoice({
    required String createdBy,
    required String issueDate,
    required String customerName,
    required double total,
    String? pickup,
    String? destination,
  }) async {
    try {
      dynamic query = _supabase
          .from('invoices')
          .select(
            'id,no_invoice,invoice_entity,created_at,created_by,tanggal,nama_pelanggan,total_biaya,lokasi_muat,lokasi_bongkar,submission_role',
          )
          .eq('created_by', createdBy)
          .eq('submission_role', 'pengurus')
          .eq('tanggal', issueDate)
          .eq('nama_pelanggan', customerName)
          .eq('total_biaya', total)
          .order('created_at', ascending: false)
          .limit(1);
      final cleanedPickup = pickup?.trim() ?? '';
      final cleanedDestination = destination?.trim() ?? '';
      if (cleanedPickup.isNotEmpty) {
        query = query.eq('lokasi_muat', cleanedPickup);
      }
      if (cleanedDestination.isNotEmpty) {
        query = query.eq('lokasi_bongkar', cleanedDestination);
      }
      final rows = _toMapList(await query);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<String> generateIncomeInvoiceNumber({
    required DateTime issuedDate,
    required String invoiceEntity,
  }) async {
    if (_invoiceNumberColumnAvailable == false) {
      return '';
    }
    try {
      final localIssuedDate = issuedDate.toLocal();
      final res = await _runInvoiceSelectWithFallback(
        'no_invoice,invoice_entity,nama_pelanggan,tanggal_kop,tanggal',
        (columns) => _supabase.from('invoices').select(columns),
      );
      if (_invoiceNumberColumnAvailable == false) {
        return '';
      }

      final rows = _toMapList(res);
      var maxSeq = 0;
      final yearTwoDigits = localIssuedDate.year % 100;
      final normalizedTargetEntity = _resolveInvoiceEntity(
        invoiceEntity: invoiceEntity,
      );
      for (final row in rows) {
        final no = '${row['no_invoice'] ?? ''}';
        final customerName = '${row['nama_pelanggan'] ?? ''}'.trim();
        final rowEntity = _resolveInvoiceEntity(
          invoiceEntity: '${row['invoice_entity'] ?? ''}',
          invoiceNumber: no,
          customerName: customerName,
          isCompany: customerName.isNotEmpty
              ? _isCompanyCustomerName(customerName)
              : _isCompanyInvoiceNumber(no),
        );
        if (rowEntity != normalizedTargetEntity) continue;
        final seq = _extractInvoiceSequenceForMonth(
          noInvoice: no,
          month: localIssuedDate.month,
          yearTwoDigits: yearTwoDigits,
          invoiceEntity: normalizedTargetEntity,
          referenceDate:
              Formatters.parseDate(row['tanggal_kop'] ?? row['tanggal']),
        );
        if (seq > maxSeq) maxSeq = seq;
      }

      final mm = localIssuedDate.month.toString().padLeft(2, '0');
      final seq = (maxSeq + 1).toString().padLeft(2, '0');
      final yy = yearTwoDigits.toString().padLeft(2, '0');
      final code = Formatters.invoiceEntityCode(normalizedTargetEntity);
      return '$code$yy$mm$seq';
    } on PostgrestException catch (e) {
      throw Exception('Gagal menyiapkan nomor invoice: ${e.message}');
    }
  }

  Future<void> createExpense({
    required double total,
    String status = 'Unpaid',
    DateTime? expenseDate,
    String? note,
    String? kategori,
    String? keterangan,
    String? recordedBy,
    List<Map<String, dynamic>>? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    final issuedDate = (expenseDate ?? DateTime.now()).toLocal();
    final date = _dateOnly(issuedDate);

    var inserted = false;
    String? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = await generateExpenseNumberForDate(issuedDate);
      try {
        await _insertExpenseWithFallback({
          'no_expense': code,
          'tanggal': date,
          'kategori':
              kategori?.trim().isEmpty == true ? null : kategori?.trim(),
          'keterangan':
              keterangan?.trim().isEmpty == true ? null : keterangan?.trim(),
          'total_pengeluaran': total,
          'status': status,
          'dicatat_oleh': recordedBy?.trim().isNotEmpty == true
              ? recordedBy!.trim()
              : user.userMetadata?['username'] ??
                  user.userMetadata?['name'] ??
                  user.email ??
                  'unknown',
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'rincian': details,
          'created_by': user.id,
        });
        inserted = true;
        break;
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        final duplicate = e.code == '23505' ||
            msg.contains('no_expense') ||
            msg.contains('expenses_no_expense_key');
        if (!duplicate || attempt >= 4) {
          throw Exception('Gagal menambah expense: ${e.message}');
        }
        lastError = e.message;
      }
    }

    if (!inserted) {
      throw Exception(
        'Gagal menambah expense: ${lastError ?? 'nomor expense tidak dapat dibuat.'}',
      );
    }
  }

  Future<void> createArmada({
    required String name,
    required String plate,
    double? capacity,
    String status = 'Ready',
    bool active = true,
  }) async {
    try {
      await _supabase.from('armadas').insert({
        'nama_truk': name.trim(),
        'plat_nomor': plate.trim().toUpperCase(),
        'kapasitas': capacity ?? 0,
        'status': status,
        'is_active': active,
      });
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          await _supabase.from('armadas').insert({
            'nama_truk': name.trim(),
            'plat_nomor': plate.trim().toUpperCase(),
            'is_active': active,
          });
          return;
        } on PostgrestException catch (fallbackError) {
          throw Exception('Gagal menambah armada: ${fallbackError.message}');
        }
      }
      throw Exception('Gagal menambah armada: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceById(String id) async {
    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,tanggal,tanggal_kop,lokasi_kop,nama_pelanggan,email,no_telp,due_date,'
          'lokasi_muat,lokasi_bongkar,armada_start_date,armada_end_date,'
          'tonase,harga,muatan,nama_supir,status,total_biaya,pph,total_bayar,diterima_oleh,'
          'customer_id,armada_id,order_id,rincian,created_at,updated_at,created_by,'
          'submission_role,approval_status,approval_requested_at,approval_requested_by,'
          'approved_at,approved_by,rejected_at,rejected_by,edit_request_status,'
          'edit_requested_at,edit_requested_by,edit_resolved_at,edit_resolved_by';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .eq('id', id)
            .maybeSingle(),
      );
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat detail invoice: ${e.message}');
    }
  }

  Future<void> updateInvoice({
    required String id,
    required String customerName,
    required String date,
    required String status,
    required double totalBiaya,
    required double pph,
    required double totalBayar,
    String? invoiceEntity,
    String? email,
    String? noTelp,
    String? kopDate,
    String? kopLocation,
    String? dueDate,
    String? acceptedBy,
    String? pickup,
    String? destination,
    String? armadaId,
    String? armadaStartDate,
    String? armadaEndDate,
    double? tonase,
    double? harga,
    String? muatan,
    String? namaSupir,
    String? noInvoice,
    List<Map<String, dynamic>>? details,
    bool generateAutoSangu = true,
    bool clearApprovedPengurusEditRequest = false,
  }) async {
    final selectedArmadaIds =
        _collectArmadaIds(primaryArmadaId: armadaId, details: details);
    final effectiveDetails = _buildEffectiveIncomeDetails(
      details: details,
      pickup: pickup,
      destination: destination,
      armadaId: armadaId,
      armadaStartDate: Formatters.parseDate(armadaStartDate),
      armadaEndDate: Formatters.parseDate(armadaEndDate),
      tonase: tonase,
      harga: harga,
      muatan: muatan,
      namaSupir: namaSupir,
    );
    final driverNames = _resolveDriverNames(
      explicitName: namaSupir,
      details: details,
    );
    var effectiveInvoiceNumber = noInvoice?.trim() ?? '';
    try {
      final normalizedKopLocation =
          kopLocation?.trim().isEmpty == true ? null : kopLocation?.trim();
      DateTime? resolveIssueDateForUpdate() {
        for (final row in effectiveDetails) {
          final parsed = Formatters.parseDate(row['armada_start_date']);
          if (parsed != null) return parsed;
        }
        final primaryParsed = Formatters.parseDate(armadaStartDate);
        if (primaryParsed != null) return primaryParsed;
        return Formatters.parseDate(date);
      }

      final resolvedIssueDate = resolveIssueDateForUpdate() ?? DateTime.now();
      final normalizedInvoiceEntity = _resolveInvoiceEntity(
        invoiceEntity: invoiceEntity,
        invoiceNumber: noInvoice,
        customerName: customerName,
        isCompany: _isCompanyCustomerName(customerName),
      );
      final payload = <String, dynamic>{
        'nama_pelanggan': customerName.trim(),
        'tanggal': _dateOnly(resolvedIssueDate),
        'status': status,
        'total_biaya': totalBiaya,
        'pph': pph,
        'total_bayar': totalBayar,
        'invoice_entity': normalizedInvoiceEntity,
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'no_telp': noTelp?.trim().isEmpty == true ? null : noTelp?.trim(),
        'tanggal_kop': kopDate?.trim().isEmpty == true ? null : kopDate?.trim(),
        'lokasi_kop': normalizedKopLocation,
        'due_date': dueDate?.trim().isEmpty == true ? null : dueDate?.trim(),
        'diterima_oleh':
            acceptedBy?.trim().isEmpty == true ? null : acceptedBy?.trim(),
        'lokasi_muat': pickup?.trim().isEmpty == true ? null : pickup?.trim(),
        'lokasi_bongkar':
            destination?.trim().isEmpty == true ? null : destination?.trim(),
        'armada_start_date': armadaStartDate?.trim().isEmpty == true
            ? null
            : armadaStartDate?.trim(),
        'armada_end_date': armadaEndDate?.trim().isEmpty == true
            ? null
            : armadaEndDate?.trim(),
        'tonase': tonase,
        'harga': harga,
        'muatan': muatan?.trim().isEmpty == true ? null : muatan?.trim(),
        'nama_supir': driverNames,
        'rincian': effectiveDetails.isEmpty ? null : effectiveDetails,
        'updated_at': DateTime.now().toIso8601String(),
        if (clearApprovedPengurusEditRequest) 'edit_request_status': 'none',
      };

      if (noInvoice != null && noInvoice.trim().isNotEmpty) {
        final normalized = Formatters.invoiceNumber(
          noInvoice.trim(),
          (kopDate?.trim().isNotEmpty == true) ? kopDate : date,
          customerName: customerName,
          isCompany: Formatters.isCompanyInvoiceEntity(normalizedInvoiceEntity),
          invoiceEntity: normalizedInvoiceEntity,
        );
        payload['no_invoice'] =
            normalized == '-' ? noInvoice.trim() : normalized;
        effectiveInvoiceNumber = '${payload['no_invoice'] ?? ''}'.trim();
      }

      if (armadaId != null && armadaId.trim().isNotEmpty) {
        payload['armada_id'] = armadaId.trim();
      } else {
        payload['armada_id'] = null;
      }

      await _updateInvoiceWithFallback(id, payload);
      if (selectedArmadaIds.isNotEmpty) {
        await _setArmadaStatusBestEffort(
          selectedArmadaIds,
          status: 'Full',
        );
      }
      final expenseReferenceDate = _resolveExpenseReferenceDateFromDetails(
        effectiveDetails,
        fallbackDate: resolvedIssueDate,
      );
      if (generateAutoSangu) {
        await _createSanguExpenseFromIncomeBestEffort(
          invoiceId: id,
          invoiceNumber: effectiveInvoiceNumber,
          expenseDate: expenseReferenceDate,
          details: effectiveDetails,
          fallbackPickup: pickup,
          fallbackDestination: destination,
          fallbackArmadaId: armadaId,
          fallbackCargo: muatan,
        );
      }
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      throw Exception('Gagal update invoice: ${e.message}');
    }
  }

  Future<void> updateInvoicePrintMeta({
    required String id,
    String? noInvoice,
    String? kopDate,
    String? kopLocation,
  }) async {
    await updateInvoicesPrintMetaBulk(
      updates: [
        <String, String?>{
          'id': id,
          'no_invoice': noInvoice,
          'kop_date': kopDate,
          'kop_location': kopLocation,
        },
      ],
    );
  }

  Future<void> updateInvoicesPrintMetaBulk({
    required List<Map<String, String?>> updates,
  }) async {
    if (updates.isEmpty) return;
    try {
      final cleanUpdates = updates
          .map((item) => <String, String?>{
                'id': (item['id'] ?? '').trim(),
                'no_invoice': (item['no_invoice'] ?? '').trim(),
                'kop_date': (item['kop_date'] ?? '').trim(),
                'kop_location': (item['kop_location'] ?? '').trim(),
              })
          .where((item) => (item['id'] ?? '').isNotEmpty)
          .toList();
      if (cleanUpdates.isEmpty) return;

      final ids = cleanUpdates.map((item) => item['id']!).toSet().toList();
      final current = await _runInvoiceSelectWithFallback(
        'id,no_invoice,invoice_entity,nama_pelanggan,tanggal,tanggal_kop,lokasi_kop',
        (columns) =>
            _supabase.from('invoices').select(columns).inFilter('id', ids),
      );
      final currentRows = _toMapList(current);
      if (currentRows.isEmpty) {
        throw Exception('Invoice tidak ditemukan.');
      }
      final currentById = <String, Map<String, dynamic>>{
        for (final row in currentRows) '${row['id'] ?? ''}': row,
      };

      final nowIso = DateTime.now().toIso8601String();
      final payloads = <Map<String, dynamic>>[];
      for (final item in cleanUpdates) {
        final id = item['id']!;
        final currentMap = currentById[id];
        if (currentMap == null) continue;

        final customerName = '${currentMap['nama_pelanggan'] ?? ''}'.trim();
        final normalizedInvoiceEntity = _resolveInvoiceEntity(
          invoiceEntity: '${currentMap['invoice_entity'] ?? ''}',
          invoiceNumber: currentMap['no_invoice'],
          customerName: customerName,
          isCompany: _isCompanyCustomerName(customerName),
        );
        final rawNoInvoice = (item['no_invoice'] ?? '').isNotEmpty
            ? item['no_invoice']!
            : '${currentMap['no_invoice'] ?? ''}'.trim();
        final effectiveKopDate = (item['kop_date'] ?? '').isNotEmpty
            ? item['kop_date']!
            : '${currentMap['tanggal_kop'] ?? currentMap['tanggal'] ?? ''}'
                .trim();
        final effectiveKopLocation = (item['kop_location'] ?? '').isNotEmpty
            ? item['kop_location']!
            : '${currentMap['lokasi_kop'] ?? ''}'.trim();

        final parsedEffectiveDate = Formatters.parseDate(effectiveKopDate) ??
            Formatters.parseDate(
                currentMap['tanggal_kop'] ?? currentMap['tanggal']) ??
            DateTime.now();
        final normalizedNoInvoice = rawNoInvoice.isEmpty
            ? rawNoInvoice
            : (() {
                final normalized = Formatters.invoiceNumber(
                  rawNoInvoice,
                  parsedEffectiveDate,
                  customerName: customerName,
                  isCompany: Formatters.isCompanyInvoiceEntity(
                    normalizedInvoiceEntity,
                  ),
                  invoiceEntity: normalizedInvoiceEntity,
                );
                return normalized == '-' ? rawNoInvoice : normalized;
              })();

        final payload = <String, dynamic>{
          'id': id,
          'updated_at': nowIso,
          'invoice_entity': normalizedInvoiceEntity,
          'tanggal_kop': effectiveKopDate.isEmpty ? null : effectiveKopDate,
          'lokasi_kop':
              effectiveKopLocation.isEmpty ? null : effectiveKopLocation,
        };
        if (normalizedNoInvoice.isNotEmpty &&
            _invoiceNumberColumnAvailable != false) {
          payload['no_invoice'] = normalizedNoInvoice;
        }
        payloads.add(payload);
      }

      if (payloads.isEmpty) return;

      for (final payload in payloads) {
        final id = '${payload['id'] ?? ''}'.trim();
        if (id.isEmpty) continue;
        final updatePayload = Map<String, dynamic>.from(payload)..remove('id');
        await _updateInvoiceWithFallback(id, updatePayload);
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal update KOP invoice: ${e.message}');
    }
  }

  Future<void> deleteInvoice(String id) async {
    final cleanedId = id.trim();
    final currentRole = await _loadCurrentRole();
    final isPengurus = currentRole == 'pengurus';
    try {
      final deletedRows = _toMapList(
        await _supabase
            .from('invoices')
            .delete()
            .eq('id', cleanedId)
            .select('id'),
      );
      if (deletedRows.isEmpty) {
        if (isPengurus) {
          final deletedByRpc = await _deletePengurusInvoiceViaRpc(cleanedId);
          if (!deletedByRpc) {
            throw Exception(
              'Invoice tidak dapat dihapus. Pastikan data belum disetujui admin/owner dan patch SQL delete pengurus di Supabase sudah aktif.',
            );
          }
        } else {
          throw Exception(
            'Invoice tidak dapat dihapus. Pastikan data belum disetujui admin/owner dan policy delete pengurus di Supabase sudah aktif.',
          );
        }
      }
      await _syncArmadaStatusNowBestEffort();
    } on PostgrestException catch (e) {
      if (isPengurus) {
        final deletedByRpc = await _deletePengurusInvoiceViaRpc(cleanedId);
        if (deletedByRpc) {
          await _syncArmadaStatusNowBestEffort();
          return;
        }
      }
      throw Exception('Gagal hapus invoice: ${e.message}');
    }
  }

  Future<bool> _deletePengurusInvoiceViaRpc(String id) async {
    try {
      final result = await _supabase.rpc(
        'delete_pengurus_income_invoice',
        params: <String, dynamic>{
          'p_invoice_id': id,
        },
      );
      if (result is bool) return result;
      if (result is num) return result != 0;
      if (result is Map<String, dynamic>) {
        final deleted = result['deleted'];
        if (deleted is bool) return deleted;
        if (deleted is num) return deleted != 0;
      }
      if (result is List && result.isNotEmpty) {
        final first = result.first;
        if (first is Map<String, dynamic>) {
          final deleted = first['deleted'];
          if (deleted is bool) return deleted;
          if (deleted is num) return deleted != 0;
        }
      }
      return false;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final missingRpc = msg.contains('delete_pengurus_income_invoice') &&
          (msg.contains('does not exist') ||
              msg.contains('could not find') ||
              msg.contains('schema cache'));
      if (missingRpc) {
        throw Exception(
          'Invoice tidak dapat dihapus. Jalankan patch SQL delete pengurus terbaru di Supabase agar pengurus bisa menghapus income yang belum diterima admin/owner.',
        );
      }
      throw Exception('Gagal hapus invoice: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> fetchExpenseById(String id) async {
    try {
      final res = await _supabase
          .from('expenses')
          .select(
            'id,no_expense,tanggal,kategori,keterangan,total_pengeluaran,'
            'status,dicatat_oleh,note,rincian,created_at,updated_at',
          )
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return _normalizeExpenseRow(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat detail expense: ${e.message}');
    }
  }

  Future<void> updateExpense({
    required String id,
    required String date,
    required String status,
    required double total,
    String? noExpense,
    String? kategori,
    String? keterangan,
    String? note,
    String? recordedBy,
    List<Map<String, dynamic>>? details,
  }) async {
    try {
      final payload = <String, dynamic>{
        'tanggal': date,
        'status': status,
        'total_pengeluaran': total,
        'kategori': kategori?.trim().isEmpty == true ? null : kategori?.trim(),
        'keterangan':
            keterangan?.trim().isEmpty == true ? null : keterangan?.trim(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'dicatat_oleh':
            recordedBy?.trim().isEmpty == true ? null : recordedBy?.trim(),
        'rincian': details,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (noExpense != null && noExpense.trim().isNotEmpty) {
        payload['no_expense'] = noExpense.trim();
      }
      await _supabase.from('expenses').update(payload).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal update expense: ${e.message}');
    }
  }

  Future<String> generateExpenseNumberForDate(
    DateTime issuedDate, {
    String? excludeExpenseId,
  }) async {
    final localIssuedDate = issuedDate.toLocal();
    final month = localIssuedDate.month.toString().padLeft(2, '0');
    final year = localIssuedDate.year.toString();
    final yearInt = localIssuedDate.year;
    final monthInt = localIssuedDate.month;
    final startDate = DateTime(yearInt, monthInt, 1);
    final endDate = (monthInt == 12)
        ? DateTime(yearInt + 1, 1, 1).subtract(const Duration(days: 1))
        : DateTime(yearInt, monthInt + 1, 1).subtract(const Duration(days: 1));
    final startIso = _dateOnly(startDate);
    final endIso = _dateOnly(endDate);

    try {
      final rows = _toMapList(
        await _supabase
            .from('expenses')
            .select('id,no_expense,tanggal')
            .gte('tanggal', startIso)
            .lte('tanggal', endIso),
      );
      final excludedId = excludeExpenseId?.trim() ?? '';
      var maxSeq = 0;
      for (final row in rows) {
        final id = '${row['id'] ?? ''}'.trim();
        if (excludedId.isNotEmpty && id == excludedId) continue;
        final no = '${row['no_expense'] ?? ''}'.trim().toUpperCase();
        final match = RegExp(r'^EXP-(\d{2})-(\d{4})-(\d{1,4})$').firstMatch(no);
        if (match == null) continue;
        final rowMonth = int.tryParse(match.group(1) ?? '') ?? 0;
        final rowYear = int.tryParse(match.group(2) ?? '') ?? 0;
        if (rowMonth != monthInt || rowYear != yearInt) continue;
        final seq = int.tryParse(match.group(3) ?? '') ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }

      final next = maxSeq + 1;
      if (next > 9999) {
        throw Exception(
          'Nomor expense bulan ini sudah mencapai batas 9999. Ganti periode bulan/tahun.',
        );
      }
      final seq4 = next.toString().padLeft(4, '0');
      return 'EXP-$month-$year-$seq4';
    } on PostgrestException catch (e) {
      throw Exception('Gagal menyiapkan nomor expense: ${e.message}');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal hapus expense: ${e.message}');
    }
  }

  Future<void> updateArmada({
    required String id,
    required String name,
    required String plate,
    double? capacity,
    String? status,
    bool? active,
  }) async {
    try {
      await _supabase.from('armadas').update({
        'nama_truk': name.trim(),
        'plat_nomor': plate.trim().toUpperCase(),
        'kapasitas': capacity ?? 0,
        'status': status ?? (active == false ? 'Inactive' : 'Ready'),
        'is_active': active ?? true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('column') || message.contains('does not exist')) {
        try {
          await _supabase.from('armadas').update({
            'nama_truk': name.trim(),
            'plat_nomor': plate.trim().toUpperCase(),
            'is_active': active ?? true,
          }).eq('id', id);
          return;
        } on PostgrestException catch (fallbackError) {
          throw Exception('Gagal update armada: ${fallbackError.message}');
        }
      }
      throw Exception('Gagal update armada: ${e.message}');
    }
  }

  Future<void> deleteArmada(String id) async {
    try {
      await _supabase.from('armadas').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal hapus armada: ${e.message}');
    }
  }

  Future<void> createCustomerOrder({
    required String pickup,
    required String destination,
    required DateTime pickupDate,
    required String service,
    required double total,
    String pickupTime = '00:00',
    String fleet = '-',
    String? cargo,
    double? weight,
    double? distance,
    String? notes,
    bool insurance = false,
    double estimate = 0,
    double insuranceFee = 0,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }

    final code = _makeDocumentCode('ORD');

    try {
      await _supabase.from('customer_orders').insert({
        'order_code': code,
        'customer_id': user.id,
        'pickup': pickup.trim(),
        'destination': destination.trim(),
        'pickup_date': _dateOnly(pickupDate),
        'pickup_time': pickupTime,
        'service': service.trim(),
        'fleet': fleet.trim(),
        'cargo': cargo?.trim().isEmpty == true ? null : cargo?.trim(),
        'weight': weight,
        'distance': distance,
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'insurance': insurance,
        'estimate': estimate,
        'insurance_fee': insuranceFee,
        'total': total,
        'status': 'Pending Payment',
      });
    } on PostgrestException catch (e) {
      throw Exception('Gagal membuat order: ${e.message}');
    }
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      await _supabase.from('customer_orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
    } on PostgrestException catch (e) {
      throw Exception('Gagal update status order: ${e.message}');
    }
  }

  Future<void> payOrder({
    required String orderId,
    required String method,
    String? invoiceId,
  }) async {
    try {
      await _supabase.from('customer_orders').update({
        'status': 'Paid',
        'payment_method': method,
        'paid_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      if (invoiceId != null && invoiceId.trim().isNotEmpty) {
        await _supabase.from('invoices').update({
          'status': 'Paid',
          'order_id': orderId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', invoiceId.trim());
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal memproses pembayaran: ${e.message}');
    }
  }

  Future<Map<String, dynamic>?> findInvoiceForOrder(String orderId) async {
    try {
      const invoiceColumns =
          'id,no_invoice,invoice_entity,status,total_biaya,pph,total_bayar,'
          'lokasi_muat,lokasi_bongkar,armada_id,tanggal,order_id,created_at';
      final res = await _runInvoiceSelectWithFallback(
        invoiceColumns,
        (columns) => _supabase
            .from('invoices')
            .select(columns)
            .eq('order_id', orderId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      );
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memuat invoice order: ${e.message}');
    }
  }

  Future<InvoiceDeliveryResult> dispatchInvoiceDelivery({
    required String invoiceId,
    required String invoiceNumber,
    required String customerName,
    String? customerId,
    String? customerEmail,
  }) async {
    final normalizedEmail = (customerEmail ?? '').trim().toLowerCase();
    final targetCustomer = await _resolveRegisteredCustomer(
      customerId: customerId,
      customerEmail: normalizedEmail,
    );

    if (targetCustomer != null) {
      final targetId = '${targetCustomer['id'] ?? ''}'.trim();
      if (targetId.isNotEmpty) {
        try {
          await _insertCustomerNotification(
            userId: targetId,
            title: 'Invoice Baru',
            message:
                'Invoice $invoiceNumber untuk $customerName sudah dikirim. Silakan cek detail invoice Anda.',
            kind: 'invoice',
            sourceType: 'invoice',
            sourceId: invoiceId,
            payload: <String, dynamic>{
              'invoice_id': invoiceId,
              'invoice_number': invoiceNumber,
              'customer_name': customerName,
            },
          );
          return InvoiceDeliveryResult(
            target: InvoiceDeliveryTarget.customerNotification,
            customerId: targetId,
          );
        } catch (_) {
          // Fallback: jika tabel notifikasi belum siap, tetap kirim via email.
          if (normalizedEmail.isNotEmpty) {
            return InvoiceDeliveryResult(
              target: InvoiceDeliveryTarget.email,
              email: normalizedEmail,
              customerId: targetId,
            );
          }
          rethrow;
        }
      }
    }

    if (normalizedEmail.isEmpty) {
      throw Exception(
        'Email customer tidak tersedia. Lengkapi email invoice agar bisa dikirim.',
      );
    }

    return InvoiceDeliveryResult(
      target: InvoiceDeliveryTarget.email,
      email: normalizedEmail,
    );
  }

  Future<void> updateMyProfile({
    required String name,
    required String email,
    String? username,
    String? avatarUrl,
    String? phone,
    String? gender,
    String? birthDate,
    String? address,
    String? city,
    String? company,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    try {
      final requestedEmail = email.trim().toLowerCase();
      final currentAuthEmail = (user.email ?? '').trim().toLowerCase();
      var profileEmail =
          currentAuthEmail.isEmpty ? requestedEmail : currentAuthEmail;

      if (requestedEmail.isNotEmpty && requestedEmail != currentAuthEmail) {
        try {
          await _supabase.auth.updateUser(
            UserAttributes(email: requestedEmail),
          );
          profileEmail = requestedEmail;
        } on AuthException catch (e) {
          throw Exception('Gagal memperbarui email akun: ${e.message}');
        }
      }

      final payload = <String, dynamic>{
        'name': name.trim(),
        'email': profileEmail,
        'username': username?.trim().isEmpty == true
            ? null
            : username?.trim().toLowerCase(),
        'avatar_url':
            avatarUrl?.trim().isEmpty == true ? null : avatarUrl?.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'gender': gender?.trim().isEmpty == true ? null : gender?.trim(),
        'birth_date':
            birthDate?.trim().isEmpty == true ? null : birthDate?.trim(),
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'city': city?.trim().isEmpty == true ? null : city?.trim(),
        'company': company?.trim().isEmpty == true ? null : company?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _supabase.from('profiles').update(payload).eq('id', user.id);
      } on PostgrestException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('avatar_url') &&
            (message.contains('column') ||
                message.contains('does not exist'))) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('avatar_url');
          await _supabase.from('profiles').update(fallback).eq('id', user.id);
        } else {
          rethrow;
        }
      }

      final metadata = <String, dynamic>{
        'name': name.trim(),
      };
      if (username != null && username.trim().isNotEmpty) {
        metadata['username'] = username.trim().toLowerCase();
      }
      if (avatarUrl != null) {
        metadata['avatar_url'] =
            avatarUrl.trim().isEmpty ? null : avatarUrl.trim();
      }
      try {
        await _supabase.auth.updateUser(UserAttributes(data: metadata));
      } catch (_) {
        // Metadata sync is best-effort only.
      }
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui profil: ${e.message}');
    }
  }

  Future<void> updateMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Session tidak ditemukan. Silakan login ulang.');
    }
    try {
      // Re-auth untuk validasi password lama.
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception(e.message);
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui password: ${e.message}');
    }
  }
}
