//! An inner doc comment.
//! @satisfies some-requirement

// A line comment.
/// An outer doc comment.
/* A block comment. */
/** An outer block doc comment. */
/*! An inner block doc comment. */
/*
 * A block comment
 * with inner lines.
 */
/* outer /* nested */ outer */
fn f() -> &'static str {
    "// not a comment" // A comment after code.
}
