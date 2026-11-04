// A line comment.
/** A doc comment. */
export function View(props: { value: number }): JSX.Element {
  return (
    <div>
      {/* A JSX comment. */}
      <span>{props.value /* after code */}</span>
    </div>
  );
}

const Arrow = <T,>(x: T) => <b>{String(x)}</b>;

interface Props {
  render(): JSX.Element;
}

describe("view", () => {
  it.skip(`renders ${"a"}\n`, () => {});
});
