"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Icon } from "@iconify/react/dist/iconify.js";
import { customerApi } from "@/lib/customerApi";

const CustomerPaymentLayer = () => {
  const searchParams = useSearchParams();
  const orderId = searchParams.get("id");
  const [order, setOrder] = useState(null);
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
    return status;
  };

  const handlePay = async () => {
    if (!method) {
      setPopup({
        type: "error",
        text: "Pilih metode pembayaran terlebih dulu.",
      });
      return;
    }

    if (!order) return;
    setProcessing(true);
    setPopup(null);

    try {
      const updated = await customerApi.post(`/customer/orders/${order.id}/pay`, {
        payment_method: method,
      });
      setOrder(updated);
      setPopup({
        type: "success",
        text: "Pembayaran berhasil. Tim kami akan segera memproses order.",
      });
    } catch (error) {
      setPopup({
        type: "error",
        text: error?.message || "Pembayaran gagal. Coba lagi.",
      });
    } finally {
      setProcessing(false);
    }
  };

  const orderCode = order?.order_code || order?.id || "-";
  const scheduleDate = formatScheduleDate(order?.pickup_date || order?.date);
  const normalizedStatus = String(order?.status || "").toLowerCase();
  const isPaymentAvailable =
    normalizedStatus.includes("accepted") || normalizedStatus.includes("paid");
  const isAwaitingApproval = order && !isPaymentAvailable;

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
                    <span className="cvant-mobile-card-label">ID Order</span>
                    <span className="cvant-mobile-card-value">{orderCode}</span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Rute</span>
                    <span className="cvant-mobile-card-value">
                      {order.pickup} - {order.destination}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Jadwal</span>
                    <span className="cvant-mobile-card-value">
                      {scheduleDate}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">PPH (2%)</span>
                    <span className="cvant-mobile-card-value">
                      {formatCurrency(order.insurance_fee)}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Total</span>
                    <span className="cvant-mobile-card-value">
                      {formatCurrency(order.total)}
                    </span>
                  </div>
                  <div className="cvant-mobile-card-row">
                    <span className="cvant-mobile-card-label">Status</span>
                    <span className="cvant-mobile-card-value">{order.status}</span>
                  </div>
                </div>

                <div className="d-none d-md-block">
                  <table className="table table-borderless mb-0">
                    <tbody>
                      <tr>
                        <td className="text-secondary-light">ID Order</td>
                        <td className="text-end fw-semibold">{orderCode}</td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Rute</td>
                        <td className="text-end fw-semibold">
                          {order.pickup} - {order.destination}
                        </td>
                      </tr>
                      <tr>
                      <td className="text-secondary-light">Jadwal</td>
                      <td className="text-end fw-semibold">
                        {scheduleDate}
                      </td>
                    </tr>
                      <tr>
                        <td className="text-secondary-light">PPH (2%)</td>
                        <td className="text-end fw-semibold">
                          {formatCurrency(order.insurance_fee)}
                        </td>
                      </tr>
                      <tr>
                        <td className="text-secondary-light">Total</td>
                        <td className="text-end fw-semibold">
                          {formatCurrency(order.total)}
                        </td>
                      </tr>
                    <tr>
                      <td className="text-secondary-light">Status</td>
                      <td className="text-end fw-semibold">
                        {formatStatusLabel(order.status)}
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
                  disabled={processing}
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
            className="cvant-order-modal"
            style={{ maxWidth: "420px", width: "100%" }}
            onClick={(event) => event.stopPropagation()}
          >
            <div className="cvant-order-modal-header">
              <h6 className="mb-0">
                {popup.type === "success" ? "Payment Success" : "Payment Failed"}
              </h6>
            </div>
            <div className="cvant-order-modal-body text-center">
              <p className="text-secondary-light mb-20">{popup.text}</p>
              <button
                type="button"
                className="btn btn-primary px-24"
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

        .cvant-order-modal-body {
          padding: 22px 20px 24px;
        }
      `}</style>
    </div>
  );
};

export default CustomerPaymentLayer;
