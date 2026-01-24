import CustomerPaymentLayer from "@/components/CustomerPaymentLayer";
import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";

export const metadata = {
  title: "Payment | CV ANT",
  description: "Payment gateway customer CV ANT.",
};

export default function PaymentPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Payment"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerPaymentLayer />
    </CustomerLayout>
  );
}
