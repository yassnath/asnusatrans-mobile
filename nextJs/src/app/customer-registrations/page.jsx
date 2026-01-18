import MasterLayout from "@/masterLayout/MasterLayout";
import Breadcrumb from "@/components/Breadcrumb";
import CustomerRegistrationsLayer from "@/components/CustomerRegistrationsLayer";

export const metadata = {
  title: "Data Customer | CV ANT",
  description: "Data customer.",
};

export default function CustomerRegistrationsPage() {
  return (
    <MasterLayout>
      <Breadcrumb title="Data Customer" subtitle="Customer" />
      <CustomerRegistrationsLayer />
    </MasterLayout>
  );
}
