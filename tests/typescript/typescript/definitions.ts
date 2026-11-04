function plain(a: number): number {
  function inner(): void {}
  return a;
}

function* generate(): Generator<number> {
  yield 1;
}

function overload(a: string): void;
function overload(a: number): void;
function overload(a: unknown): void {}

declare function ambient(): void;

class Shape<T> {
  constructor(private readonly t: T) {}
  static create(): void {}
  get size(): number { return 1; }
  method(a: string): void;
  method(a: unknown): void {}
  #hidden(): void {}
  field = 1;
}

abstract class Base {
  abstract area(): number;
  describe(): string { return ""; }
}

@sealed
class Decorated {
  @logged
  method(): void {}
}

interface Point {
  x: number;
  move(dx: number): void;
}

type Pair<T> = [T, T];

enum Color { Red, Green }

const enum Flag { On }

namespace Outer.Inner {
  export function nested(): void {}
}

module Legacy {}

declare module "ambient-module" {}

const arrow = <T,>(x: T): T => x;
let block = (): number => {
  return 2;
};
var expression = function named(): void {};
const value: number = 1;

export function exported(): void {}

export default function fallback(): void {}

@registered
export class Exported {}

export abstract class ExportedBase {}

export interface ExportedShape {}

export type Alias = string;

export const exportedArrow = async (): Promise<void> => {};

class Handlers {
  onClick = (): void => {};
  private onKey = function (): void {};
  static items = function* (): Generator<number> {};
  #secret = async (): Promise<number> => 1;
  count: number = 0;
}
