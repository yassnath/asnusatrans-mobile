import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerNotificationsLayer from "@/components/CustomerNotificationsLayer";

export const metadata = {
  title: "Notifications | CV ANT",
  description: "Customer activity notifications for CV ANT.",
};

export default function CustomerNotificationsPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Notifications"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerNotificationsLayer />
    </CustomerLayout>
  );
}
