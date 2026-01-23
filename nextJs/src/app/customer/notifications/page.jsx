import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerNotificationsLayer from "@/components/CustomerNotificationsLayer";

export const metadata = {
  title: "Notifikasi | CV ANT",
  description: "Notifikasi aktivitas customer CV ANT.",
};

export default function CustomerNotificationsPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Notifikasi"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerNotificationsLayer />
    </CustomerLayout>
  );
}
