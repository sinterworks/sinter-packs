#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""A module docstring with @satisfies some-requirement in it."""

# A comment alone.

# A run
# of several
#   lines.
#
LIMIT = 10  # A comment after code.
TEXT = "# not a comment"
RAW = r'''# not a comment
either'''


# @satisfies some-requirement
# Prose after the tag.
@decorator
# A comment between a decorator and a definition.
def read(path):
    """A docstring with @cites some-record in it.

    @verifies some-requirement
    """
    return f"{path} # not a comment"  # A comment after a string.
#No space after the sigil.
