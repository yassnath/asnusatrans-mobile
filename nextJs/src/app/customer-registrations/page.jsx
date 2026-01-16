import MasterLayout from "@/masterLayout/MasterLayout";
import Breadcrumb from "@/components/Breadcrumb";
import CustomerRegistrationsLayer from "@/components/CustomerRegistrationsLayer";

export const metadata = {
  title: "Pendaftaran Customer | CV ANT",
  description: "Daftar pendaftaran customer.",
};

export default function CustomerRegistrationsPage() {
  return (
    <MasterLayout>
      <Breadcrumb title="Pendaftaran Customer" subtitle="Customer" />
      <CustomerRegistrationsLayer />
    </MasterLayout>
  );
}
