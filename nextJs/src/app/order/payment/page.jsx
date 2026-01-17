import CustomerPaymentLayer from "@/components/CustomerPaymentLayer";
import CustomerLayout from "@/masterLayout/CustomerLayout";

export const metadata = {
  title: "Payment | CV ANT",
  description: "Payment gateway customer CV ANT.",
};

export default function PaymentPage() {
  return (
    <CustomerLayout>
      <CustomerPaymentLayer />
    </CustomerLayout>
  );
}
