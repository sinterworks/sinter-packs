import unittest
from unittest import TestCase, expectedFailure, skip, skipIf, skipUnless

import pytest
import pytest_asyncio
from pytest import fixture, mark


def helper():
    pass


def test_plain():
    pass


async def test_async():
    pass


def testing_prefix():
    pass


def tests_prefix_plural():
    pass


def not_a_test_name():
    pass


def outer():
    def test_inner():
        pass


@pytest.fixture
def test_fixture():
    pass


@pytest.fixture(scope="module")
def test_fixture_with_arguments():
    pass


@fixture
def test_short_fixture():
    pass


@pytest.mark.usefixtures("db")
@pytest.fixture
def test_fixture_after_another_decorator():
    pass


@pytest.mark.skip
@fixture()
def test_fixture_with_a_label():
    pass


@pytest.fixture  # A comment after the decorator.
def test_fixture_with_a_comment():
    pass


@pytest.mark.skip
@pytest.fixture  # A comment after the decorator.
def test_fixture_with_a_label_and_a_comment():
    pass


@pytest_asyncio.fixture
async def test_asyncio_fixture():
    pass


@fixture.helper
def test_decorator_that_is_not_a_fixture():
    pass


@pytest.mark.usefixtures("db")
def test_with_another_decorator():
    pass


@pytest.mark.parametrize("value", [1, 2])
def test_parametrize(value):
    pass


@mark.parametrize("value", [1, 2])
def test_short_parametrize(value):
    pass


@pytest.mark.skip
def test_skip():
    pass


@pytest.mark.skip(reason="slow")
def test_skip_with_reason():
    pass


@pytest.mark.skipif(True, reason="never")
def test_skipif():
    pass


@mark.skip
def test_short_skip():
    pass


@pytest.mark.xfail
def test_xfail():
    pass


@mark.xfail(strict=True)
def test_short_xfail():
    pass


@pytest.mark.parametrize("value", [1, 2])
# A comment between the decorators.
@pytest.mark.usefixtures("db")
@pytest.mark.skip
def test_two_labels(value):
    pass


@pytest.mark.skip
async def test_async_skip():
    pass


@pytest.mark.skip \

def test_line_continuation():
    pass


class TestPlain:
    def test_method(self):
        pass

    async def test_async_method(self):
        pass

    def helper(self):
        pass

    @pytest.fixture
    def test_fixture_method(self):
        pass

    @pytest.fixture  # A comment after the decorator.
    def test_fixture_method_with_a_comment(self):
        pass

    @pytest.mark.xfail
    def test_xfail_method(self):
        pass

    @staticmethod
    def test_static():
        pass

    class TestNested:
        def test_in_nested(self):
            pass

        class TestDeeper:
            def test_in_deeper(self):
                pass

    class Helper:
        def test_in_helper(self):
            pass


@pytest.mark.skip
class TestSkippedClass:
    def test_in_skipped_class(self):
        pass


class ReaderTests(unittest.TestCase):
    def test_reads(self):
        pass

    @unittest.skip("broken")
    def test_skip_long(self):
        pass

    @unittest.skipIf(True, "never")
    def test_skipif_long(self):
        pass

    @unittest.skipUnless(False, "never")
    def test_skipunless_long(self):
        pass

    @unittest.expectedFailure
    def test_expected_failure_long(self):
        pass

    def setUp(self):
        pass


class WriterTests(Base, TestCase):
    @skip("broken")
    def test_skip_short(self):
        pass

    @skipIf(True, "never")
    def test_skipif_short(self):
        pass

    @skipUnless(False, "never")
    def test_skipunless_short(self):
        pass

    @expectedFailure
    def test_expected_failure_short(self):
        pass


@mark.parametrize("value", [1, 2])
class TestParametrizedClass:
    @pytest.mark.skip
    def test_skip_in_parametrized_class(self, value):
        pass


@pytest.mark.usefixtures("db")
class TestDecoratedClass:
    def test_in_decorated_class(self):
        pass


class TestOuter:
    @pytest.mark.skip
    class TestSkippedNested:
        @pytest.mark.parametrize("value", [1, 2])
        def test_parametrize_in_nested(self, value):
            pass

    @pytest.mark.usefixtures("db")
    class TestDecoratedNested:
        def test_in_decorated_nested(self):
            pass

    class NestedTests(unittest.TestCase):
        def test_in_nested_case(self):
            pass


@unittest.skip("broken")
class SkippedTests(
    # A comment in the superclasses.
    unittest.TestCase,
):
    def test_in_skipped_case(self):
        pass


class AsyncReaderTests(unittest.IsolatedAsyncioTestCase):
    async def test_reads_async(self):
        pass


class ViewTests(django.test.SimpleTestCase):
    def test_view(self):
        pass


class ModelTests(TransactionTestCase):
    def test_model(self):
        pass


class Helper:
    def test_not_in_a_group(self):
        pass


class NotTestCase(TestCaseMixin, metaclass=TestCase):
    def test_not_in_a_group(self):
        pass


def make_class():
    class TestInFunction:
        def test_in_function(self):
            pass
