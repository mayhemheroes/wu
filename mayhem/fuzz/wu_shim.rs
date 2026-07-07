//! crate::wu — a subset of src/wu/mod.rs for the libFuzzer harness.
//!
//! The compiler pipeline modules are re-used verbatim from ../../src/wu via `#[path]`.
//! They are mounted at `crate::wu` because lexer/matcher.rs hardcodes `$crate::wu::lexer::...`.
//! The upstream `handler` module (git2/dirs/toml/fs_extra, only used by the `wu` CLI
//! subcommands) is intentionally omitted — the lex/parse/visit/generate pipeline never uses it.

#[macro_use]
#[path = "../../src/wu/error.rs"]
pub mod error;
#[path = "../../src/wu/source.rs"]
pub mod source;
#[path = "../../src/wu/lexer/mod.rs"]
pub mod lexer;
#[path = "../../src/wu/parser/mod.rs"]
pub mod parser;
#[path = "../../src/wu/visitor/mod.rs"]
pub mod visitor;
#[path = "../../src/wu/compiler/mod.rs"]
pub mod compiler;
