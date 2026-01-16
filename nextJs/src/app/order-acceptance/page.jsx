import MasterLayout from "@/masterLayout/MasterLayout";
import Breadcrumb from "@/components/Breadcrumb";
import OrderAcceptanceLayer from "@/components/OrderAcceptanceLayer";

export const metadata = {
  title: "Penerimaan Order | CV ANT",
  description: "Penerimaan order customer.",
};

export default function OrderAcceptancePage() {
  return (
    <MasterLayout>
      <Breadcrumb title="Penerimaan Order" subtitle="Customer" />
      <OrderAcceptanceLayer />
    </MasterLayout>
  );
}
