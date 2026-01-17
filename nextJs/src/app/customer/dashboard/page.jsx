import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerDashboardLayer from "@/components/CustomerDashboardLayer";

export const metadata = {
  title: "Customer Dashboard | CV ANT",
  description: "Dashboard customer untuk memantau order dan pembayaran.",
};

export default function CustomerDashboardPage() {
  return (
    <CustomerLayout>
      <CustomerDashboardLayer />
    </CustomerLayout>
  );
}
