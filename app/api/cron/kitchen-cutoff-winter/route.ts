import { GET as runKitchenCutoff } from "../kitchen-cutoff/route";

export const runtime = "nodejs";

export async function GET(request: Request) {
  return runKitchenCutoff(request);
}
