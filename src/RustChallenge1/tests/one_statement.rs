//! Enforces the challenge rule on `main`: no `;`, no `let`, no `return`, anywhere
//! in its body (string literals and comments excluded) and exactly one `for`.
//!
//! This is a small hand-rolled scanner, not a Rust parser. It understands line and
//! block comments, string and raw-string literals, and char literals, which is
//! enough for `main.rs`.

/// `source` with comments and string/char literal contents replaced by spaces.
fn code_only(source: &str) -> String {
    let chars: Vec<char> = source.chars().collect();
    let mut out = String::new();
    let mut i = 0;
    let blank = |c: char| if c == '\n' { '\n' } else { ' ' };
    while i < chars.len() {
        let rest: String = chars[i..chars.len().min(i + 3)].iter().collect();
        if rest.starts_with("//") {
            while i < chars.len() && chars[i] != '\n' {
                out.push(' ');
                i += 1;
            }
        } else if rest.starts_with("/*") {
            while i < chars.len() && !(chars[i] == '*' && chars.get(i + 1) == Some(&'/')) {
                out.push(blank(chars[i]));
                i += 1;
            }
            out.push_str("  ");
            i += 2;
        } else if chars[i] == 'r' && matches!(chars.get(i + 1), Some('"') | Some('#')) {
            let hashes = chars[i + 1..].iter().take_while(|&&c| c == '#').count();
            if chars.get(i + 1 + hashes) != Some(&'"') {
                out.push('r');
                i += 1;
                continue;
            }
            let mut end = i + 2 + hashes;
            while !(chars[end] == '"' && chars[end + 1..].iter().take(hashes).all(|&c| c == '#')) {
                end += 1;
            }
            end += 1 + hashes;
            out.extend(chars[i..end].iter().map(|&c| blank(c)));
            i = end;
        } else if chars[i] == '"' {
            out.push(' ');
            i += 1;
            while chars[i] != '"' {
                i += if chars[i] == '\\' { 2 } else { 1 };
            }
            out.push(' ');
            i += 1;
        } else if chars[i] == '\'' && chars.get(i + 2) == Some(&'\'') {
            out.push_str("   ");
            i += 3;
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

fn main_body() -> String {
    let source = std::fs::read_to_string(concat!(env!("CARGO_MANIFEST_DIR"), "/src/main.rs"))
        .expect("read src/main.rs");
    let code = code_only(&source);
    let start = code.find("fn main()").expect("fn main") + "fn main()".len();
    code[start..].to_string()
}

fn words<'a>(code: &'a str) -> impl Iterator<Item = &'a str> {
    code.split(|c: char| !(c.is_alphanumeric() || c == '_'))
        .filter(|w| !w.is_empty())
}

#[test]
fn main_has_no_semicolons() {
    assert_eq!(main_body().matches(';').count(), 0);
}

#[test]
fn main_has_no_let_or_return() {
    let body = main_body();
    let banned: Vec<_> = words(&body)
        .filter(|w| matches!(*w, "let" | "return"))
        .collect();
    assert!(banned.is_empty(), "found {banned:?}");
}

#[test]
fn main_is_one_empty_for_loop() {
    let body = main_body();
    assert_eq!(words(&body).filter(|w| *w == "for").count(), 1);
    let squashed: String = body.split_whitespace().collect();
    assert!(
        squashed.starts_with("{for_in"),
        "main must open with the for"
    );
    assert!(squashed.ends_with("){}}"), "the for body must be empty");
}

#[test]
fn the_scanner_itself_notices_violations() {
    let cleaned = code_only("fn main() { let x = \";\"; // ; here\n a(); /* ; */ r#\";\"# }");
    assert_eq!(cleaned.matches(';').count(), 2);
    assert!(words(&cleaned).any(|w| w == "let"));
}
