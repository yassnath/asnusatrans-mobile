"use client";

import { useEffect, useState } from "react";
import { Icon } from "@iconify/react/dist/iconify.js";
import { api } from "@/lib/api";

const CustomerRegistrationsLayer = () => {
  const [customers, setCustomers] = useState([]);

  const loadCustomers = async () => {
    try {
      const data = await api.get("/customer-registrations");
      setCustomers(Array.isArray(data) ? data : []);
    } catch {
      setCustomers([]);
    }
  };

  useEffect(() => {
    loadCustomers();
  }, []);

  const formatDate = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleDateString("id-ID");
  };

  const formatDateTime = (value) => {
    if (!value) return "-";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleString("id-ID");
  };

  return (
    <div className="row">
      <div className="col-12">
        <div className="card h-100">
          <div className="card-body p-24">
            <div className="d-flex align-items-center justify-content-between flex-wrap gap-3 mb-20">
              <div>
                <h6 className="mb-4 fw-bold">Pendaftaran Customer</h6>
                <p className="text-secondary-light mb-0">
                  Data biodata customer yang sudah mendaftar.
                </p>
              </div>
              <button className="btn btn-primary radius-8" onClick={loadCustomers}>
                <Icon icon="solar:refresh-linear" className="me-6" />
                Refresh
              </button>
            </div>

            {customers.length === 0 ? (
              <div className="text-center py-40">
                <Icon icon="solar:inbox-linear" className="text-2xl text-secondary-light" />
                <p className="text-secondary-light mt-12 mb-0">
                  Belum ada customer yang mendaftar.
                </p>
              </div>
            ) : (
              <div className="table-responsive scroll-sm">
                <table className="table bordered-table align-middle mb-0">
                  <thead>
                    <tr>
                      <th>No</th>
                      <th>Nama</th>
                      <th>Email</th>
                      <th>HP</th>
                      <th>Gender</th>
                      <th>Tgl Lahir</th>
                      <th>Alamat</th>
                      <th>Kota</th>
                      <th>Perusahaan</th>
                      <th>Terdaftar</th>
                    </tr>
                  </thead>
                  <tbody>
                    {customers.map((customer, index) => (
                      <tr key={customer.id || index}>
                        <td>{index + 1}</td>
                        <td>{customer.name || "-"}</td>
                        <td>{customer.email || "-"}</td>
                        <td>{customer.phone || "-"}</td>
                        <td>{customer.gender || "-"}</td>
                        <td>{formatDate(customer.birth_date)}</td>
                        <td>{customer.address || "-"}</td>
                        <td>{customer.city || "-"}</td>
                        <td>{customer.company || "-"}</td>
                        <td>{formatDateTime(customer.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default CustomerRegistrationsLayer;
