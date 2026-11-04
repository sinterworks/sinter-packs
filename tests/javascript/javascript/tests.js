describe("math", () => {
  it("adds", () => {});
  test("subtracts", () => {});
  it.skip("skips", () => {});
  it.only("runs alone", () => {});
  it.todo("waits");
  test.each([[1, 2]])("doubles %i to %i", (a, b) => {});
  it.each`
    a    | b
    ${1} | ${2}
  `("adds $a to $b", ({ a, b }) => {});
});

describe.skip("skipped group", () => {});
describe.only(`only group`, () => {});
describe.todo("later group");
describe.each([1, 2])("group %i", (n) => {});

it("line\nbreak and \"quote\"", () => {});
test(`count ${n} of ${total}`, () => {});
it(`tab\there`, () => {});
it("", () => {});

it.concurrent("not a form of the pack", () => {});
it.skip.each([1])("not a form of the pack", () => {});
expect("not a test");
it(name, () => {});
describe.each([1]);

describe(suiteName, () => {
  it.each(rows)(title, () => {});
  test(prefix + " suffix", () => {});
  it.skip(names[0], () => {});
  it(makeTitle(), () => {});
  it(table.title, () => {});
  it(fast ? "fast" : "slow", () => {});
  it(("parenthesized"), () => {});
});
