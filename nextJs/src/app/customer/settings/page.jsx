import Breadcrumb from "@/components/Breadcrumb";
import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerSettingsLayer from "@/components/CustomerSettingsLayer";

export const metadata = {
  title: "Customer Settings | CV ANT",
  description: "Customer account settings for CV ANT.",
};

export default function CustomerSettingsPage() {
  return (
    <CustomerLayout>
      <Breadcrumb
        title="Settings"
        rootHref="/customer/dashboard"
        rootLabel="Dashboard"
      />
      <CustomerSettingsLayer />
    </CustomerLayout>
  );
}
