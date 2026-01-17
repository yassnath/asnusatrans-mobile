const parseDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

export const formatNotificationTime = (value) => {
  const date = parseDate(value);
  return date ? date.toLocaleString("id-ID") : "-";
};

export const buildCustomerNotifications = (orders) => {
  const list = Array.isArray(orders) ? orders : [];
  const items = [];

  list.forEach((order) => {
    const code = order?.order_code || `ORD-${order?.id ?? "-"}`;

    if (order?.created_at) {
      items.push({
        id: `order-${order?.id}-created`,
        title: "Order dibuat",
        message: `Order ${code} berhasil dibuat.`,
        time: order.created_at,
      });
    }

    if (order?.paid_at) {
      items.push({
        id: `order-${order?.id}-paid`,
        title: "Pembayaran berhasil",
        message: `Pembayaran order ${code} berhasil.`,
        time: order.paid_at,
      });
    }

    if (order?.status && ["Accepted", "Rejected"].includes(order.status) && order?.updated_at) {
      items.push({
        id: `order-${order?.id}-status`,
        title: "Status order diperbarui",
        message: `Order ${code} ${order.status.toLowerCase()}.`,
        time: order.updated_at,
      });
    }
  });

  return items.sort((a, b) => {
    const aTime = parseDate(a.time)?.getTime() || 0;
    const bTime = parseDate(b.time)?.getTime() || 0;
    return bTime - aTime;
  });
};

export const buildAdminNotifications = (customers, orders) => {
  const items = [];
  const customerList = Array.isArray(customers) ? customers : [];
  const orderList = Array.isArray(orders) ? orders : [];

  customerList.forEach((customer) => {
    if (!customer?.created_at) return;
    items.push({
      id: `customer-${customer?.id}`,
      title: "Customer baru",
      message: `${customer?.name || "Customer"} mendaftar.`,
      time: customer.created_at,
    });
  });

  orderList.forEach((order) => {
    const code = order?.order_code || `ORD-${order?.id ?? "-"}`;
    const customerName = order?.customer?.name || "Customer";

    if (order?.created_at) {
      items.push({
        id: `order-${order?.id}-created`,
        title: "Order baru",
        message: `${customerName} membuat order ${code}.`,
        time: order.created_at,
      });
    }

    if (order?.paid_at) {
      items.push({
        id: `order-${order?.id}-paid`,
        title: "Order dibayar",
        message: `Order ${code} sudah dibayar.`,
        time: order.paid_at,
      });
    }

    if (order?.status && ["Accepted", "Rejected"].includes(order.status) && order?.updated_at) {
      items.push({
        id: `order-${order?.id}-status`,
        title: "Status order diperbarui",
        message: `Order ${code} ${order.status.toLowerCase()}.`,
        time: order.updated_at,
      });
    }
  });

  return items.sort((a, b) => {
    const aTime = parseDate(a.time)?.getTime() || 0;
    const bTime = parseDate(b.time)?.getTime() || 0;
    return bTime - aTime;
  });
};
