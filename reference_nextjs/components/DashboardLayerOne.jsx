import LatestRegisteredOne from "./child/LatestRegisteredOne";
import RecentActivity from "./child/RecentActivity";
import UnitCountOne from "./child/UnitCountOne";
import ArmadaOverview from "./child/ArmadaOverview";
import RecentTransactions from "./child/RecentTransactions";
import IncomeVsExpense from "./child/IncomeVsExpense";

const DashBoardLayerOne = () => {
  return (
    <>
      <UnitCountOne />
      <section className='row gy-4 mt-1'>
        <IncomeVsExpense />
        <ArmadaOverview />
        <LatestRegisteredOne />
        <RecentActivity />
        <RecentTransactions />
      </section>
    </>
  );
};

export default DashBoardLayerOne;
