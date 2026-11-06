function plain(a) {
  function inner() {}
  return inner;
}

function* generate() {
  yield 1;
}

async function later() {}

class Shape {
  constructor() {}
  static create() {}
  get size() { return 1; }
  set size(v) {}
  *items() {}
  async load() {}
  #hidden() {}
  ["computed"]() {}
  field = 1;
}

@sealed
class Decorated {
  @logged
  method() {}
}

const arrow = (x) => x + 1;
let block = () => {
  return 2;
};
var expression = function named() {};
const generator = function* () {};
const first = () => {}, second = function () {};

const value = 1;
const other = class {};
const object = { method() {} };

export function exported() {}

export default function fallback() {}

@registered
export class Exported {}

export const exportedArrow = async () => {};

class Handlers {
  onClick = () => {};
  onKey = function () {};
  static items = function* () {};
  #secret = async () => 1;
  count = 0;
}
