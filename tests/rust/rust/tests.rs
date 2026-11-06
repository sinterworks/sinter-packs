fn helper() {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn adds() {}

    #[test]
    #[ignore]
    fn ignored_after() {}

    #[ignore = "slow"]
    #[test]
    fn ignored_before() {}

    #[test]
    // A comment between the attributes.
    #[should_panic]
    fn panics() {}

    #[tokio::test(flavor = "multi_thread")]
    async fn runs_async() {}

    #[rstest]
    #[case(1)]
    #[case(2)]
    fn cases(#[case] x: u8) {}

    #[rstest::rstest]
    fn with_path() {}

    #[inline]
    fn not_a_test() {}

    mod nested {
        #[test]
        fn in_nested() {}
    }
}

mod plain_tests {
    #[test]
    fn outside_cfg_test() {}
}

#[cfg(not(test))]
mod not_tests {}

#[cfg(all(test, unix))]
mod unix_tests {}
