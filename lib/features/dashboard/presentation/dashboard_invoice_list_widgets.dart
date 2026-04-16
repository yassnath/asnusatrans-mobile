part of 'dashboard_page.dart';

typedef _InvoiceRowActionButtonStyleBuilder = ButtonStyle Function(Color color);

class _AdminInvoiceListRowCard extends StatelessWidget {
  const _AdminInvoiceListRowCard({
    required this.item,
    required this.isIncome,
    required this.translate,
    required this.invoiceTypeLabel,
    required this.invoiceTypeColor,
    required this.mobileActionButtonStyle,
    required this.primaryActionIcon,
    required this.primaryActionColor,
    required this.onPreview,
    this.pengurusStatusMessage,
    this.pengurusStatusColor,
    this.onPrimaryAction,
    this.onSend,
    this.onDelete,
  });

  final Map<String, dynamic> item;
  final bool isIncome;
  final String Function(String id, String en) translate;
  final String invoiceTypeLabel;
  final Color invoiceTypeColor;
  final String? pengurusStatusMessage;
  final Color? pengurusStatusColor;
  final _InvoiceRowActionButtonStyleBuilder mobileActionButtonStyle;
  final VoidCallback? onPrimaryAction;
  final IconData primaryActionIcon;
  final Color primaryActionColor;
  final VoidCallback onPreview;
  final VoidCallback? onSend;
  final VoidCallback? onDelete;

  bool get _shouldShowRoute {
    final routeLabel = '${item['__route'] ?? '-'}'.trim();
    final nameLabel = '${item['__name'] ?? ''}'.trim();
    if (routeLabel.isEmpty || routeLabel == '-') return false;
    return routeLabel.toLowerCase() != nameLabel.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final total = _toNum(item['__total']);
    final nameLabel = item['__is_auto_sangu'] == true
        ? translate('Nama Sopir', 'Driver')
        : translate('Nama', 'Name');

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['__type']} • ${Formatters.dmy(item['__date'])}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isIncome ? AppColors.blue : AppColors.danger,
                  ),
                ),
              ),
              _StatusPill(label: '${item['__status'] ?? '-'}'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$nameLabel: ${item['__name'] ?? '-'}',
            style: TextStyle(color: AppColors.textMutedFor(context)),
          ),
          const SizedBox(height: 2),
          if (_shouldShowRoute) ...[
            Text(
              '${item['__route'] ?? '-'}',
              style: TextStyle(color: AppColors.textMutedFor(context)),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 6),
          if ((pengurusStatusMessage ?? '').trim().isNotEmpty) ...[
            Text(
              pengurusStatusMessage!,
              style: TextStyle(
                color: pengurusStatusColor ?? AppColors.textMutedFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            Formatters.rupiah(total),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isIncome)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      invoiceTypeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: invoiceTypeColor,
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: onPrimaryAction,
                    style: mobileActionButtonStyle(primaryActionColor),
                    child: Icon(primaryActionIcon, size: 18),
                  ),
                  OutlinedButton(
                    onPressed: onPreview,
                    style: mobileActionButtonStyle(AppColors.warning),
                    child: const Icon(Icons.visibility_outlined, size: 18),
                  ),
                  if (onSend != null)
                    OutlinedButton(
                      onPressed: onSend,
                      style: mobileActionButtonStyle(const Color(0xFF2563EB)),
                      child: const Icon(Icons.send_outlined, size: 18),
                    ),
                  if (onDelete != null)
                    OutlinedButton(
                      onPressed: onDelete,
                      style: mobileActionButtonStyle(AppColors.danger),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
