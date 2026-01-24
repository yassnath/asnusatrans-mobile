import Breadcrumb from "@/components/Breadcrumb";
import CustomerOrderLayer from "@/components/CustomerOrderLayer";
import CustomerLayout from "@/masterLayout/CustomerLayout";

export const metadata = {
  title: "Order | CV ANT",
  description: "Customer order form for CV ANT.",
};

export default function OrderPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Order & Payment"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerOrderLayer />
    </CustomerLayout>
  );
}
