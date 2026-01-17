import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerNotificationsLayer from "@/components/CustomerNotificationsLayer";

export const metadata = {
  title: "Notifikasi | CV ANT",
  description: "Notifikasi aktivitas customer CV ANT.",
};

export default function CustomerNotificationsPage() {
  return (
    <CustomerLayout>
      <CustomerNotificationsLayer />
    </CustomerLayout>
  );
}
