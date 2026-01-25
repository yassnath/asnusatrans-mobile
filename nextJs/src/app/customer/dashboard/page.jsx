import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerDashboardLayer from "@/components/CustomerDashboardLayer";

export const metadata = {
  title: "Customer Dashboard | CV ANT",
  description: "Customer dashboard to track orders and payments.",
};

export default function CustomerDashboardPage() {
  return (
    <CustomerLayout>
      <CustomerDashboardLayer />
    </CustomerLayout>
  );
}
