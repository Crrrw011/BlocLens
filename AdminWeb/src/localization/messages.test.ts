import { describe, expect, it } from "vitest";

import { messages } from "./messages";

describe("English portal messages", () => {
  it("provides the operations metadata title used by the root layout", () => {
    expect(messages.en.metadata.operationsTitle).toBe("BlocLens Operations");
  });
});
