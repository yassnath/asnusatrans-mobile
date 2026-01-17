import CustomerLayout from "@/masterLayout/CustomerLayout";
import CustomerSettingsLayer from "@/components/CustomerSettingsLayer";

export const metadata = {
  title: "Settings Customer | CV ANT",
  description: "Pengaturan akun customer CV ANT.",
};

export default function CustomerSettingsPage() {
  return (
    <CustomerLayout>
      <CustomerSettingsLayer />
    </CustomerLayout>
  );
}
