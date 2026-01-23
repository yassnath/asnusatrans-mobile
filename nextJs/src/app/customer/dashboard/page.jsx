import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerDashboardLayer from "@/components/CustomerDashboardLayer";

export const metadata = {
  title: "Customer Dashboard | CV ANT",
  description: "Dashboard customer untuk memantau order dan pembayaran.",
};

export default function CustomerDashboardPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Dashboard Customer"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerDashboardLayer />
    </CustomerLayout>
  );
}
