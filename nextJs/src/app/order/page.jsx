import CustomerOrderLayer from "@/components/CustomerOrderLayer";
import CustomerLayout from "@/masterLayout/CustomerLayout";

export const metadata = {
  title: "Order | CV ANT",
  description: "Form order customer CV ANT.",
};

export default function OrderPage() {
  return (
    <CustomerLayout>
      <CustomerOrderLayer />
    </CustomerLayout>
  );
}
