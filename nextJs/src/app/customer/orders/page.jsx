import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerOrdersLayer from "@/components/CustomerOrdersLayer";

export const metadata = {
  title: "Riwayat Order | CV ANT",
  description: "Riwayat order customer CV ANT.",
};

export default function CustomerOrdersPage() {
  return (
    <CustomerLayout>
      <CustomerOrdersLayer />
    </CustomerLayout>
  );
}
