"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Icon } from "@iconify/react/dist/iconify.js";
import { customerApi } from "@/lib/customerApi";

const CustomerPaymentLayer = () => {
  const searchParams = useSearchParams();
  const orderId = searchParams.get("id");
  const invoiceId = searchParams.get("invoice");
  const [order, setOrder] = useState(null);
  const [invoice, setInvoice] = useState(null);
  const [invoiceLoading, setInvoiceLoading] = useState(false);
  const [method, setMethod] = useState("");
  const [processing, setProcessing] = useState(false);
  const [popup, setPopup] = useState(null);

  useEffect(() => {
    const loadLatest = async () => {
      try {
        if (orderId) {
          const selected = await customerApi.get(`/customer/orders/${orderId}`);
          setOrder(selected || null);
          return;
        }

        const latest = await customerApi.get("/customer/orders?latest=1");
        setOrder(latest || null);
      } catch {
        setOrder(null);
      }
    };

    loadLatest();
  }, [orderId]);

  useEffect(() => {
    const loadInvoice = async () => {
      if (!order?.id && !invoiceId) {
        setInvoice(null);
        return;
      }

      setInvoiceLoading(true);
      try {
        if (invoiceId) {
          const data = await customerApi.get(`/customer/invoices/${invoiceId}`);
          setInvoice(data || null);
          return;
        }

        const data = await customerApi.get(`/customer/orders/${order.id}/invoice`);
        setInvoice(data || null);
      } catch {
        setInvoice(null);
      } finally {
        setInvoiceLoading(false);
      }
    };

    loadInvoice();
  }, [order, invoiceId]);

  useEffect(() => {
    const syncOrder = async () => {
      if (!invoice?.order_id || !invoiceId) return;
      if (order && String(order.id) === String(invoice.order_id)) return;

      try {
        const data = await customerApi.get(
          `/customer/orders/${invoice.order_id}`
        );
        setOrder(data || null);
      } catch {
        // ignore
      }
    };

    syncOrder();
  }, [invoice, invoiceId, order]);

  const formatCurrency = (value) => {
    const parsed = Number(value);
    const safeValue = Number.isFinite(parsed) ? parsed : 0;
    return `Rp ${safeValue.toLocaleString("id-ID")}`;
  };

  const formatScheduleDate = (value) => {
    if (!value) return "-";
    const raw = String(value);
    const match = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (match) return `${match[3]}-${match[2]}-${match[1]}`;
    const parsed = new Date(raw);
    if (Number.isNaN(parsed.getTime())) return raw;
    const day = String(parsed.getDate()).padStart(2, "0");
    const month = String(parsed.getMonth() + 1).padStart(2, "0");
    const year = String(parsed.getFullYear());
    return `${day}-${month}-${year}`;
  };

  const formatStatusLabel = (status) => {
    if (!status) return "Pending";
    const normalized = String(status).toLowerCase();
    if (normalized.includes("pending")) return "Pending";
    if (normalized.includes("accepted")) return "Accepted";
    if (normalized.includes("rejected")) return "Rejected";
    if (normalized.includes("paid")) return "Paid";
    if (normalized.includes("unpaid")) return "Unpaid";
    if (normalized.includes("waiting")) return "Waiting";
    return status;
  };

  const resolveArmadaLabel = (invoiceData, orderData) => {
    const rincianList = Array.isArray(invoiceData?.rincian)
      ? invoiceData.rincian
      : [];
    const rincianArmada = rincianList.find(
      (item) =>
        item?.armada?.nama_truk ||
        item?.armada?.plat_nomor ||
        item?.armada_plat ||
        item?.plat_nomor ||
        item?.plat
    );

    const name =
      invoiceData?.armada?.nama_truk ||
      rincianArmada?.armada?.nama_truk ||
      "";
    const plate =
      invoiceData?.armada?.plat_nomor ||
      rincianArmada?.armada?.plat_nomor ||
      rincianArmada?.armada_plat ||
      rincianArmada?.plat_nomor ||
      rincianArmada?.plat ||
      "";

    if (name) {
      return plate ? `${name} (${plate})` : name;
    }

    if (plate) return plate;

    return orderData?.fleet || "-";
  };

  const handlePay = async () => {
    if (!method) {
      setPopup({
        type: "error",
        text: "Pilih metode pembayaran terlebih dulu.",
      });
      return;
    }

    const targetOrderId = order?.id || invoice?.order_id || orderId;
    if (!targetOrderId) {
      setPopup({
        type: "error",
        text: "Order tidak ditemukan. Silakan buka ulang dari notifikasi.",
      });
      return;
    }

    setProcessing(true);
    setPopup(null);

    try {
      const updated = await customerApi.post(
        `/customer/orders/${targetOrderId}/pay`,
        {
          payment_method: method,
          invoice_id: invoice?.id || invoiceId || null,
        }
      );
      setOrder(updated);
      setInvoice((prev) => (prev ? { ...prev, status: "Paid" } : prev));
      setPopup({
        type: "success",
        text: "Pembayaran berhasil. Tim kami akan segera memproses order.",
      });
    } catch (error) {
      const rawMessage = error?.message || "Pembayaran gagal. Coba lagi.";
      const sanitized = /sqlstate|unknown column|exception/i.test(rawMessage)
        ? "Pembayaran gagal. Silakan coba lagi atau hubungi admin."
        : rawMessage;
      setPopup({
        type: "error",
        text: sanitized,
      });
    } finally {
      setProcessing(false);
    }
  };

  const invoiceNumber = invoice?.no_invoice || "-";
  const summaryRoute = invoice
    ? `${invoice.lokasi_muat || "-"} - ${invoice.lokasi_bongkar || "-"}`
    : `${order?.pickup || "-"} - ${order?.destination || "-"}`;
  const scheduleDate = formatScheduleDate(
    invoice?.armada_start_date || invoice?.tanggal || order?.pickup_date || order?.date
  );
  const armadaLabel = resolveArmadaLabel(invoice, order);
  const normalizedStatus = String(order?.status || "").toLowerCase();
  const hasInvoice = !!invoice;
  const isOrderApproved =
    normalizedStatus.includes("accepted") || normalizedStatus.includes("paid");
  const isPaymentAvailable = hasInvoice && (isOrderApproved || !order);
  const isAwaitingApproval = order && !hasInvoice && !isOrderApproved;
  const isLoadingInvoice = (order || invoiceId) && !isAwaitingApproval && invoiceLoading;
  const isAwaitingInvoice =
    (order || invoiceId) && !isAwaitingApproval && !hasInvoice && !invoiceLoading;

  const methods = [
    { id: "va", label: "Virtual Account", icon: "solar:card-transfer-linear" },
    { id: "transfer", label: "Transfer Bank", icon: "solar:bank-linear" },
    { id: "qris", label: "QRIS", icon: "solar:qr-code-linear" },
    { id: "ewallet", label: "E-Wallet", icon: "solar:wallet-linear" },
  ];

  return (
    <div className="container-fluid py-4">
      <div className="d-flex justify-content-end mb-4">
        <Link href="/order" className="btn btn-outline-primary btn-sm">
          Ubah Order
        </Link>
      </div>

      {!order ? (
        <div className="card shadow-none border">
          <div className="card-body">
            <h6 className="mb-2">Order belum tersedia</h6>
            <p className="text-secondary-light mb-0">
              Buat order terlebih dahulu sebelum melanjutkan pembayaran.
            </p>
            <Link href="/order" className="btn btn-primary mt-3">
              Ke Form Order
            </Link>
          </div>
        </div>
      ) : isAwaitingApproval ? (
        <div className="card shadow-none border">
          <div className="card-body">
            <h6 className="mb-2">Menunggu Persetujuan</h6>
            <p className="text-secondary-light mb-0">
              Order Anda sedang ditinjau oleh owner/admin. Invoice akan
              dikirimkan melalui notifikasi setelah disetujui.
            </p>
            <Link href="/customer/notifications" className="btn btn-primary mt-3">
              Lihat Notifikasi
            </Link>
          </div>
        </div>
      ) : isLoadingInvoice ? (
        <div className="card shadow-none border">
          <div className="card-body">
            <h6 className="mb-2">Memuat Invoice</h6>
            <p className="text-secondary-light mb-0">
              Menyiapkan ringkasan pembayaran dari invoice.
            </p>
          </div>
        </div>
      ) : isAwaitingInvoice ? (
        <div className="card shadow-none border">
          <div className="card-body">
            <h6 className="mb-2">Invoice Belum Tersedia</h6>
            <p className="text-secondary-light mb-0">
              Invoice sedang dipersiapkan oleh admin/owner. Silakan cek notifikasi
              untuk melanjutkan pembayaran.
            </p>
            <Link href="/customer/notifications" className="btn btn-primary mt-3">
              Lihat Notifikasi
            </Link>
          </div>
        </div>
      ) : (
        <div className="row g-4">
          <div className="col-lg-5">
            <div className="card shadow-none border h-100">
              <div className="card-header bg-transparent">
                <h6 className="mb-0">Ringkasan Order</h6>
              </div>
              <div className="card-body">
                <div className="d-md-none cvant-mobile-card">
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Invoice</span>
                    <span className="cvant-mobile-card-value">
                      {invoiceNumber}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Rute</span>
                    <span className="cvant-mobile-card-value">
                      {summaryRoute}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Jadwal</span>
                    <span className="cvant-mobile-card-value">
                      {scheduleDate}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Armada</span>
                    <span className="cvant-mobile-card-value">
                      {armadaLabel}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">PPH (2%)</span>
                    <span className="cvant-mobile-card-value">
                      {formatCurrency(invoice?.pph)}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Total</span>
                    <span className="cvant-mobile-card-value">
                      {formatCurrency(invoice?.total_bayar)}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Status</span>
                    <span className="cvant-mobile-card-value">
                      {formatStatusLabel(invoice?.status)}
                    </span>
                  </div>
                </div>

                <div className="d-none d-md-block">
                  <table className="table table-borderless mb-0 cvant-summary-table">
                    <tbody>
                      <tr>
                        <td className="text-secondary-light">Invoice</td>
                        <td className="text-end fw-semibold">{invoiceNumber}</td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Rute</td>
                        <td className="text-end fw-semibold">
                          {summaryRoute}
                        </td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Jadwal</td>
                        <td className="text-end fw-semibold">
                          {scheduleDate}
                        </td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Armada</td>
                        <td className="text-end fw-semibold">{armadaLabel}</td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">PPH (2%)</td>
                        <td className="text-end fw-semibold">
                          {formatCurrency(invoice?.pph)}
                        </td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Total</td>
                        <td className="text-end fw-semibold">
                          {formatCurrency(invoice?.total_bayar)}
                        </td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Status</td>
                        <td className="text-end fw-semibold">
                          {formatStatusLabel(invoice?.status)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>

          <div className="col-lg-7">
            <div className="card shadow-none border h-100">
              <div className="card-header bg-transparent">
                <h6 className="mb-0">Pilih Metode Pembayaran</h6>
              </div>
              <div className="card-body">
                <div className="d-grid gap-3">
                  {methods.map((option) => (
                    <div key={option.id}>
                      <input
                        className="payment-gateway-input d-none"
                        type="radio"
                        id={`payment-${option.id}`}
                        name="paymentMethod"
                        checked={method === option.id}
                        onChange={() => setMethod(option.id)}
                      />
                      <label
                        htmlFor={`payment-${option.id}`}
                        className="payment-gateway-label border radius-8 p-12 w-100 d-flex align-items-center gap-3"
                      >
                        <Icon icon={option.icon} style={{ fontSize: "20px" }} />
                        <span className="fw-semibold">{option.label}</span>
                      </label>
                    </div>
                  ))}
                </div>

                <button
                  type="button"
                  className="btn btn-primary w-100 mt-4"
                  onClick={handlePay}
                  disabled={processing || !isPaymentAvailable}
                >
                  {processing ? "Memproses..." : "Bayar Sekarang"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {popup && (
        <div
          className="position-fixed top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center"
          style={{
            zIndex: 9999,
            background: "rgba(0,0,0,0.55)",
            padding: "16px",
          }}
          onClick={() => setPopup(null)}
        >
          <div
            className={`cvant-order-modal ${
              popup.type === "success" ? "is-success" : "is-error"
            }`}
            style={{ maxWidth: "420px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div
              className={`cvant-order-modal-header ${
                popup.type === "success"
                  ? "cvant-order-modal-header-success"
                  : "cvant-order-modal-header-error"
              }`}
            >
              <h6 className="mb-0">
                {popup.type === "success" ? "Payment Success" : "Payment Failed"}
              </h6>
            </div>
            <div className="cvant-order-modal-body text-center">
              <p className="text-secondary-light mb-20">{popup.text}</p>
              <button
                type="button"
                className={`btn px-24 ${
                  popup.type === "success" ? "btn-success" : "btn-danger"
                }`}
                onClick={() => setPopup(null)}
              >
                OK
              </button>
            </div>
          </div>
        </div>
      )}

      <style jsx global>{`
        .cvant-order-modal {
          background: var(--white);
          border-radius: 16px;
          box-shadow: 0px 13px 30px 10px rgba(46, 45, 116, 0.05);
          border: 0;
          overflow: hidden;
        }

        .cvant-order-modal-header {
          padding: 14px 18px;
          background: var(--primary-50);
          border-bottom: 1px solid rgba(148, 163, 184, 0.2);
        }

        .cvant-order-modal-header-success {
          background: rgba(34, 197, 94, 0.12);
          color: #16a34a;
        }

        .cvant-order-modal-header-error {
          background: rgba(239, 68, 68, 0.12);
          color: #dc2626;
        }

        .cvant-order-modal-body {
          padding: 22px 20px 24px;
        }

        .cvant-summary-table,
        .cvant-summary-table td,
        .cvant-summary-table th {
          background: transparent !important;
        }

        .cvant-summary-table {
          --bs-table-bg: transparent;
          --bs-table-striped-bg: transparent;
          --bs-table-hover-bg: transparent;
        }
      `}</style>
    </div>
  );
};

export default CustomerPaymentLayer;
