import MasterLayout from "@/masterLayout/MasterLayout";
import DashboardLayerOne from "@/components/DashboardLayerOne";

export const metadata = {
  title: "Dashboard | CV ANT",
  description: "Main dashboard CV ANT",
};

export default function DashboardPage() {
  return (
    <MasterLayout>
      <DashboardLayerOne />
    </MasterLayout>
  );
}
