import XCTest

@testable import YomidoriCore

final class MarkdownBlocksTests: XCTestCase {
    func testTheNoticesFileShape() {
        let markdown = """
            # Third-party notices

            Yomidori is MIT licensed (see [LICENSE](LICENSE)). It bundles
            the following.

            ## JMdict

            > This application uses the JMdict dictionary files.
            > Used in conformance with the license.

            ## MeCab

            ```text
            Copyright (c) 2001-2008, Taku Kudo
            All rights reserved.
            ```
            """
        XCTAssertEqual(
            MarkdownBlock.parse(markdown),
            [
                .heading(level: 1, text: "Third-party notices"),
                .paragraph(
                    "Yomidori is MIT licensed (see [LICENSE](LICENSE)). It bundles the following."),
                .heading(level: 2, text: "JMdict"),
                .quote(
                    "This application uses the JMdict dictionary files. Used in conformance with the license."
                ),
                .heading(level: 2, text: "MeCab"),
                .code("Copyright (c) 2001-2008, Taku Kudo\nAll rights reserved."),
            ])
    }

    func testCodeKeepsItsBlankLinesAndAHashIsNotAHeadingWithoutASpace() {
        XCTAssertEqual(
            MarkdownBlock.parse("```\na\n\nb\n```"), [.code("a\n\nb")])
        XCTAssertEqual(MarkdownBlock.parse("#tag"), [.paragraph("#tag")])
        XCTAssertEqual(MarkdownBlock.parse("### Three"), [.heading(level: 3, text: "Three")])
    }

    func testAnUnclosedFenceStillEnds() {
        XCTAssertEqual(MarkdownBlock.parse("```\nend"), [.code("end")])
    }
}
