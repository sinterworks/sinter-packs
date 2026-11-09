MAX_SIZE = 10
LIMIT: int = 20
NAMES: list[str]
first, second = 1, 2
one = two = 3
config.debug = True
items[0] = 4
MAX_SIZE += 1
type Alias = int
type Pair[T] = tuple[T, T]


def plain(x):
    local = 1

    def nested():
        return local

    return nested


async def fetch():
    pass


class Shape:
    SIDES = 0
    type Unit = str

    def area(self):
        return 0

    class Inner:
        pass


@dataclass
class Point:
    x: int


@cache
@other(1)
def decorated():
    pass


if DEBUG:
    LEVEL = 1
