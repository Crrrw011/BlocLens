import { notFound } from "next/navigation";

import { ShellTestHarness } from "@/components/shell/shell-test-harness";
import { requireStaff } from "@/lib/auth/access";

export default async function ShellTestHarnessPage() {
  await requireStaff();

  if (process.env.PLAYWRIGHT_TEST_HARNESS !== "1") {
    notFound();
  }

  return <ShellTestHarness />;
}
