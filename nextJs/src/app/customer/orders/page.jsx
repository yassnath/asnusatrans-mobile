import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerOrdersLayer from "@/components/CustomerOrdersLayer";

export const metadata = {
  title: "Order History | CV ANT",
  description: "Customer order history for CV ANT.",
};

export default function CustomerOrdersPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Order History"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerOrdersLayer />
    </CustomerLayout>
  );
}
