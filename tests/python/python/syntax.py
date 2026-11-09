# Syntax of Python 3.10 and later.
def first[T](items: list[T]) -> T:
    return items[0]


class Box[T]:
    def get(self) -> T: ...


type Vector = list[float]
type Pair[T] = tuple[T, T]


def handle(command):
    match command:
        case ["go", direction]:
            return direction
        case _:
            return None


try:
    pass
except* ValueError:
    pass

try:
    pass
except KeyError, IndexError:
    pass

GREETING = t"Hello {name}"
