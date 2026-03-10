class MetricSummary {
  const MetricSummary({
    required this.totalCustomers,
    required this.totalIncome,
    required this.totalExpense,
  });

  final int totalCustomers;
  final double totalIncome;
  final double totalExpense;
}

class MonthlySeries {
  const MonthlySeries({
    required this.income,
    required this.expense,
  });

  final List<double> income;
  final List<double> expense;
}

class ArmadaUsage {
  const ArmadaUsage({
    required this.name,
    required this.plate,
    required this.count,
  });

  final String name;
  final String plate;
  final int count;
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.number,
    required this.customer,
    required this.dateLabel,
    required this.total,
    required this.status,
    required this.link,
  });

  final String id;
  final String type;
  final String number;
  final String customer;
  final String dateLabel;
  final double total;
  final String status;
  final String link;
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final String dateLabel;
  final String kind;
}

class DashboardBundle {
  const DashboardBundle({
    required this.metrics,
    required this.monthlySeries,
    required this.armadaUsages,
    required this.latestCustomers,
    required this.biggestTransactions,
    required this.recentActivities,
    required this.recentTransactions,
  });

  final MetricSummary metrics;
  final MonthlySeries monthlySeries;
  final List<ArmadaUsage> armadaUsages;
  final List<TransactionItem> latestCustomers;
  final List<TransactionItem> biggestTransactions;
  final List<ActivityItem> recentActivities;
  final List<TransactionItem> recentTransactions;
}

class DashboardLiveSections {
  const DashboardLiveSections({
    required this.armadaUsages,
    required this.recentActivities,
  });

  final List<ArmadaUsage> armadaUsages;
  final List<ActivityItem> recentActivities;
}

class CustomerOrderSummary {
  const CustomerOrderSummary({
    required this.code,
    required this.routeLabel,
    required this.scheduleLabel,
    required this.service,
    required this.total,
    required this.status,
  });

  final String code;
  final String routeLabel;
  final String scheduleLabel;
  final String service;
  final double total;
  final String status;
}

class CustomerDashboardBundle {
  const CustomerDashboardBundle({
    required this.totalOrders,
    required this.pendingPayments,
    required this.totalSpend,
    required this.latestOrders,
  });

  final int totalOrders;
  final int pendingPayments;
  final double totalSpend;
  final List<CustomerOrderSummary> latestOrders;
}
