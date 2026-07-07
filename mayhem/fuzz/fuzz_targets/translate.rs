#![no_main]
//! In-memory libFuzzer harness for the Wu compiler.
//!
//! Mirrors `run()` from src/main.rs (lex -> parse -> type-check/visit -> codegen) but feeds an
//! in-memory `&str` instead of a file, and never writes the emitted `.lua`. This gives Mayhem a
//! properly SanitizerCoverage-instrumented libFuzzer target (the old file-input `wu @@` binary had
//! ASan but no sancov, so dynamic analysis produced no edges and failed).

use libfuzzer_sys::fuzz_target;

#[path = "../wu_shim.rs"]
mod wu;

use wu::compiler::*;
use wu::lexer::*;
use wu::parser::*;
use wu::source::*;
use wu::visitor::*;

/// Compile a Wu source string, mirroring `run()` in src/main.rs. Returns the generated Lua on
/// success, or `None` if lexing/parsing/visiting fails (an ordinary compile error, not a crash).
fn compile(content: &str) -> Option<String> {
    let source = Source::from(
        "fuzz.wu",
        content.lines().map(|x| x.into()).collect::<Vec<String>>(),
    );
    let lexer = Lexer::default(content.chars().collect(), &source);

    let mut tokens = Vec::new();
    for token_result in lexer {
        if let Ok(token) = token_result {
            tokens.push(token)
        } else {
            return None;
        }
    }

    let mut parser = Parser::new(tokens, &source);

    match parser.parse() {
        Ok(ref ast) => {
            let mut symtab = SymTab::new();

            let splat_any = Type::new(TypeNode::Any, TypeMode::Splat(None));

            symtab.assign_str(
                "print",
                Type::function(vec![splat_any.clone()], Type::from(TypeNode::Nil), false),
            );
            symtab.assign_str(
                "ipairs",
                Type::function(vec![splat_any.clone()], splat_any.clone(), false),
            );
            symtab.assign_str(
                "pairs",
                Type::function(vec![splat_any.clone()], splat_any, false),
            );

            let mut visitor = Visitor::from_symtab(ast, &source, symtab, String::new());

            match visitor.visit() {
                Ok(_) => (),
                _ => return None,
            }

            let mut generator =
                Generator::new(&source, &visitor.method_calls, &visitor.import_map);

            Some(generator.generate(&ast))
        }

        _ => None,
    }
}

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = compile(s);
    }
});
