const parseDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const invoiceNotificationKey = "cvant_customer_invoice_notifications";

const normalizeEmail = (value) => String(value || "").trim().toLowerCase();

export const formatNotificationTime = (value) => {
  const date = parseDate(value);
  return date ? date.toLocaleString("id-ID") : "-";
};

export const getStoredInvoiceNotifications = () => {
  if (typeof window === "undefined") return [];
  const raw = window.localStorage.getItem(invoiceNotificationKey);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
};

export const storeInvoiceNotification = ({
  invoiceId,
  customerEmail,
  customerName,
  invoiceNumber,
  time,
} = {}) => {
  if (typeof window === "undefined") return null;
  if (!invoiceId) return null;

  const email = normalizeEmail(customerEmail);
  if (!email) return null;

  const now = time || new Date().toISOString();
  const id = `invoice-${invoiceId}-${email}`;
  const entry = {
    id,
    invoiceId,
    customerEmail: email,
    customerName: customerName || "",
    invoiceNumber: invoiceNumber || "",
    time: now,
  };

  const current = getStoredInvoiceNotifications();
  const next = [entry, ...current.filter((item) => item?.id !== id)].slice(0, 200);
  window.localStorage.setItem(invoiceNotificationKey, JSON.stringify(next));
  return entry;
};

export const buildCustomerNotifications = (
  orders,
  customer,
  invoiceNotifications = []
) => {
  const list = Array.isArray(orders) ? orders : [];
  const items = [];
  const ordersHref = "/customer/orders";
  const customerEmail = normalizeEmail(customer?.email);

  list.forEach((order) => {
    const code = order?.order_code || `ORD-${order?.id ?? "-"}`;

    if (order?.created_at) {
      items.push({
        id: `order-${order?.id}-created`,
        title: "Order dibuat",
        message: `Order ${code} berhasil dibuat.`,
        time: order.created_at,
        href: ordersHref,
      });
    }

    if (order?.paid_at) {
      items.push({
        id: `order-${order?.id}-paid`,
        title: "Pembayaran berhasil",
        message: `Pembayaran order ${code} berhasil.`,
        time: order.paid_at,
        href: ordersHref,
      });
    }

    if (order?.status && ["Accepted", "Rejected"].includes(order.status) && order?.updated_at) {
      items.push({
        id: `order-${order?.id}-status`,
        title: "Status order diperbarui",
        message: `Order ${code} ${order.status.toLowerCase()}.`,
        time: order.updated_at,
        href: ordersHref,
      });
    }
  });

  const invoiceList = Array.isArray(invoiceNotifications)
    ? invoiceNotifications
    : [];

  invoiceList.forEach((entry) => {
    if (!customerEmail) return;
    const entryEmail = normalizeEmail(entry?.customerEmail);
    if (!entryEmail || entryEmail !== customerEmail) return;

    const invoiceNumber = entry?.invoiceNumber || `#${entry?.invoiceId ?? "-"}`;
    items.push({
      id: entry?.id || `invoice-${entry?.invoiceId ?? "-"}`,
      title: "Invoice tersedia",
      message: `Invoice ${invoiceNumber} telah dikirim.`,
      time: entry?.time,
      href: `/invoice/${entry?.invoiceId}`,
    });
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
  const customerHref = "/customer-registrations";
  const orderHref = "/order-acceptance";

  customerList.forEach((customer) => {
    if (!customer?.created_at) return;
    items.push({
      id: `customer-${customer?.id}`,
      title: "Customer baru",
      message: `${customer?.name || "Customer"} mendaftar.`,
      time: customer.created_at,
      href: customerHref,
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
        href: orderHref,
      });
    }

    if (order?.paid_at) {
      items.push({
        id: `order-${order?.id}-paid`,
        title: "Order dibayar",
        message: `Order ${code} sudah dibayar.`,
        time: order.paid_at,
        href: orderHref,
      });
    }

    if (order?.status && ["Accepted", "Rejected"].includes(order.status) && order?.updated_at) {
      items.push({
        id: `order-${order?.id}-status`,
        title: "Status order diperbarui",
        message: `Order ${code} ${order.status.toLowerCase()}.`,
        time: order.updated_at,
        href: orderHref,
      });
    }
  });

  return items.sort((a, b) => {
    const aTime = parseDate(a.time)?.getTime() || 0;
    const bTime = parseDate(b.time)?.getTime() || 0;
    return bTime - aTime;
  });
};
