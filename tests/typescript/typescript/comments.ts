// A line comment.
/* A block comment. */
/**
 * A doc comment.
 * @param x - the input
 * @satisfies some-requirement
 */
function f(x: number): number {
  return x; // A comment after code.
}
/* first */ /* second */
let s: string = "// not a comment";
<!-- An HTML-like comment.
let after = 1;
--> A closing HTML-like comment.
